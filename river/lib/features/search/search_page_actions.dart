part of 'search_page.dart';

extension _SearchPageActions on _SearchPageState {
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
    if (_searchMode != _SearchMode.posts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - _SearchPageState._loadMoreTriggerOffset) {
      _loadMorePosts();
    }
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
      _mutateState(() {
        _activeQuery = '';
        _error = null;
        _loading = false;
        _loadingMorePosts = false;
        _hasMorePostPages = false;
        _currentPostPage = 0;
        _postItems = const <RiverSidePostSearchItem>[];
        _userItems = const <RiverSideUserSearchItem>[];
      });
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
    });
    if (_keywordController.text.trim().isNotEmpty) {
      _runSearch(reset: true);
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

