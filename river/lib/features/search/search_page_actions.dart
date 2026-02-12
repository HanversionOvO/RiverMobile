part of 'search_page.dart';

extension _SearchPageActions on _SearchPageState {
  void _onKeywordFocusChanged() {
    _mutateState(() {
      _keywordFocused = _keywordFocusNode.hasFocus;
    });
    if (_keywordFocused) {
      _scheduleSuggestionQuery(immediate: true);
    } else {
      _suggestionDebounce?.cancel();
    }
  }

  void _onKeywordInputChanged(String _) {
    _mutateState(() {});
    _scheduleSuggestionQuery();
  }

  void _scheduleSuggestionQuery({bool immediate = false}) {
    _suggestionDebounce?.cancel();
    final query = _keywordController.text.trim();
    if (query.isEmpty) {
      _clearSuggestionState();
      return;
    }
    if (!_keywordFocused && !immediate) {
      return;
    }
    if (immediate) {
      unawaited(_fetchSuggestions(query));
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_fetchSuggestions(query));
    });
  }

  void _clearSuggestionState() {
    _suggestionSerial++;
    _mutateState(() {
      _loadingSuggestions = false;
      _keywordSuggestions = const <String>[];
      _postSuggestions = const <RiverSidePostSearchItem>[];
      _userSuggestions = const <RiverSideUserSearchItem>[];
    });
  }

  List<String> _buildKeywordSuggestions(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final startsWith = <String>[];
    final contains = <String>[];
    for (final keyword in _recentSearches) {
      final item = keyword.trim();
      if (item.isEmpty) {
        continue;
      }
      final lower = item.toLowerCase();
      if (lower == normalized) {
        startsWith.insert(0, item);
        continue;
      }
      if (lower.startsWith(normalized)) {
        startsWith.add(item);
      } else if (lower.contains(normalized)) {
        contains.add(item);
      }
    }
    return <String>[...startsWith, ...contains].take(6).toList(growable: false);
  }

  bool _isSuggestionStale({required int serial, required String query}) {
    if (!mounted || serial != _suggestionSerial) {
      return true;
    }
    return _keywordController.text.trim() != query;
  }

  Future<void> _fetchSuggestions(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _clearSuggestionState();
      return;
    }
    final serial = ++_suggestionSerial;
    final keywordSuggestions = _buildKeywordSuggestions(normalized);
    _mutateState(() {
      _loadingSuggestions = true;
      _keywordSuggestions = keywordSuggestions;
    });
    try {
      final cookieHeader = _activeCookieHeader();
      final apiClient = widget.dependencies.accountStore.riverSideApiClient;
      List<RiverSidePostSearchItem> postSuggestions =
          const <RiverSidePostSearchItem>[];
      List<RiverSideUserSearchItem> userSuggestions =
          const <RiverSideUserSearchItem>[];
      switch (_searchMode) {
        case _SearchMode.posts:
          final page = await apiClient.searchPosts(
            query: normalized,
            page: 1,
            cookieHeader: cookieHeader,
          );
          postSuggestions = page.items.take(6).toList(growable: false);
          break;
        case _SearchMode.users:
          final users = await apiClient.searchUsers(
            term: normalized,
            limit: 8,
            cookieHeader: cookieHeader,
          );
          userSuggestions = users.take(8).toList(growable: false);
          break;
      }
      if (_isSuggestionStale(serial: serial, query: normalized)) {
        return;
      }
      _mutateState(() {
        _loadingSuggestions = false;
        _keywordSuggestions = keywordSuggestions;
        _postSuggestions = postSuggestions;
        _userSuggestions = userSuggestions;
      });
    } catch (_) {
      if (_isSuggestionStale(serial: serial, query: normalized)) {
        return;
      }
      _mutateState(() {
        _loadingSuggestions = false;
        _keywordSuggestions = keywordSuggestions;
        _postSuggestions = const <RiverSidePostSearchItem>[];
        _userSuggestions = const <RiverSideUserSearchItem>[];
      });
    }
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    final previous = _lastActiveUsername;
    if (current == previous) {
      return;
    }
    _lastActiveUsername = current;
    _loadRecentSearches();
    if (_activeQuery.isNotEmpty) {
      _runSearch(reset: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final shouldShowBackToTop =
        _scrollController.offset >= _SearchPageState._showBackToTopOffset;
    if (_showBackToTop.value != shouldShowBackToTop) {
      _showBackToTop.value = shouldShowBackToTop;
    }

    if (_searchMode != _SearchMode.posts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - _SearchPageState._loadMoreTriggerOffset) {
      _loadMorePosts();
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  Future<void> _loadRecentSearches() async {
    if (_loadingRecentSearches) {
      return;
    }

    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _mutateState(() {
        _recentSearches = const <String>[];
        _loadingRecentSearches = false;
      });
      return;
    }

    _mutateState(() {
      _loadingRecentSearches = true;
    });

    try {
      final recent = await widget.dependencies.accountStore.riverSideApiClient
          .fetchRecentSearches(cookieHeader: cookieHeader);
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _recentSearches = recent;
      });
      if (_keywordFocused && _keywordController.text.trim().isNotEmpty) {
        _scheduleSuggestionQuery(immediate: true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Keep UI resilient: recent-search endpoint can fail independently.
    } finally {
      _mutateState(() {
        _loadingRecentSearches = false;
      });
    }
  }

  Future<void> _clearRecentSearches() async {
    if (_clearingRecentSearches) {
      return;
    }

    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _showSnackBar(_SearchPageState._labelNeedLogin);
      return;
    }

    _mutateState(() {
      _clearingRecentSearches = true;
    });

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .clearRecentSearches(cookieHeader: cookieHeader);
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _recentSearches = const <String>[];
      });
      _showSnackBar(_SearchPageState._labelClearRecentSuccess);
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_SearchPageState._labelSearchFailed);
    } finally {
      _mutateState(() {
        _clearingRecentSearches = false;
      });
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _keywordController.text.trim();
    if (query.isEmpty) {
      _suggestionDebounce?.cancel();
      _mutateState(() {
        _activeQuery = '';
        _error = null;
        _loading = false;
        _loadingMorePosts = false;
        _hasMorePostPages = false;
        _currentPostPage = 0;
        _postItems = const <RiverSidePostSearchItem>[];
        _userItems = const <RiverSideUserSearchItem>[];
        _showBackToTop.value = false;
      });
      _clearSuggestionState();
      await _loadRecentSearches();
      return;
    }

    if (!reset && (_searchMode != _SearchMode.posts || !_hasMorePostPages)) {
      return;
    }

    final targetQuery = reset ? query : _activeQuery;
    if (targetQuery.isEmpty) {
      return;
    }

    final nextPage = reset ? 1 : (_currentPostPage + 1);
    _keywordFocusNode.unfocus();
    _suggestionDebounce?.cancel();
    _clearSuggestionState();
    final serial = ++_requestSerial;
    _mutateState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _activeQuery = targetQuery;
      } else {
        _loadingMorePosts = true;
      }
    });
    if (reset) {
      _showBackToTop.value = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    try {
      final apiClient = widget.dependencies.accountStore.riverSideApiClient;
      final cookieHeader = _activeCookieHeader();

      switch (_searchMode) {
        case _SearchMode.posts:
          final page = await apiClient.searchPosts(
            query: targetQuery,
            page: nextPage,
            cookieHeader: cookieHeader,
          );
          if (!mounted || serial != _requestSerial) {
            return;
          }
          final merged = reset
              ? page.items
              : <RiverSidePostSearchItem>[
                  ..._postItems,
                  ...page.items.where(
                    (item) => !_postItems.any(
                      (current) => current.topicId == item.topicId,
                    ),
                  ),
                ];
          _mutateState(() {
            _postItems = merged;
            _userItems = const <RiverSideUserSearchItem>[];
            _currentPostPage = page.page;
            _hasMorePostPages = page.hasMore;
            if (reset) {
              _resultAnimationEpoch++;
            }
          });
          break;
        case _SearchMode.users:
          final users = await apiClient.searchUsers(
            term: targetQuery,
            limit: _SearchPageState._userSearchLimit,
            cookieHeader: cookieHeader,
          );
          if (!mounted || serial != _requestSerial) {
            return;
          }
          _mutateState(() {
            _userItems = users;
            _postItems = const <RiverSidePostSearchItem>[];
            _currentPostPage = 0;
            _hasMorePostPages = false;
            if (reset) {
              _resultAnimationEpoch++;
            }
          });
          break;
      }
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _error = _SearchPageState._labelSearchFailed;
      });
    } finally {
      if (mounted && serial == _requestSerial) {
        _mutateState(() {
          _loading = false;
          _loadingMorePosts = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loading || _loadingMorePosts || !_hasMorePostPages) {
      return;
    }
    await _runSearch(reset: false);
  }

  void _onModeChanged(_SearchMode mode) {
    if (mode == _searchMode) {
      return;
    }
    _mutateState(() {
      _searchMode = mode;
      _error = null;
      _requestSerial++;
      _loading = false;
      _loadingMorePosts = false;
      _postItems = const <RiverSidePostSearchItem>[];
      _userItems = const <RiverSideUserSearchItem>[];
      _currentPostPage = 0;
      _hasMorePostPages = false;
      _showBackToTop.value = false;
      _loadingSuggestions = false;
      _keywordSuggestions = const <String>[];
      _postSuggestions = const <RiverSidePostSearchItem>[];
      _userSuggestions = const <RiverSideUserSearchItem>[];
    });
    if (_keywordController.text.trim().isNotEmpty) {
      if (_keywordFocused) {
        _scheduleSuggestionQuery(immediate: true);
      } else {
        _runSearch(reset: true);
      }
    }
  }

  Future<void> _openTopicDetail(int topicId) async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topicId,
        ),
      ),
    );
  }

  Future<void> _openUserProfile(RiverSideUserSearchItem user) async {
    final account = UserAccount(
      provider: AccountProvider.riverSide,
      userId: user.id <= 0 ? null : user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => RiverSideProfilePage(
          dependencies: widget.dependencies,
          account: account,
          cookieHeader: _activeCookieHeader(),
        ),
      ),
    );
  }

  void _applyRecentSearch(String keyword) {
    final text = keyword.trim();
    if (text.isEmpty) {
      return;
    }
    _keywordController.text = text;
    _keywordController.selection = TextSelection.collapsed(offset: text.length);
    _runSearch(reset: true);
  }

  void _applySuggestionKeyword(String keyword) {
    final text = keyword.trim();
    if (text.isEmpty) {
      return;
    }
    _keywordController.text = text;
    _keywordController.selection = TextSelection.collapsed(offset: text.length);
    _runSearch(reset: true);
  }

  Future<void> _onRefresh() async {
    if (_activeQuery.isEmpty) {
      await _loadRecentSearches();
      return;
    }
    await _runSearch(reset: true);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
