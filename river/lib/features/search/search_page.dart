import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_search_models.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';

part 'search_page_view.dart';

const String postsSearchHeroTag = 'posts-search-entry-hero';

enum _SearchMode { posts, users }

extension on _SearchMode {
  String get label {
    switch (this) {
      case _SearchMode.posts:
        return '\u5e16\u5b50';
      case _SearchMode.users:
        return '\u7528\u6237';
    }
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _userSearchLimit = 20;
  static const double _loadMoreTriggerOffset = 260;

  static const String _labelSearch = '\u641c\u7d22';
  static const String _labelSearchHint = '\u8f93\u5165\u5173\u952e\u8bcd';
  static const String _labelRetry = '\u91cd\u8bd5';
  static const String _labelNoUsers =
      '\u672a\u627e\u5230\u76f8\u5173\u7528\u6237';
  static const String _labelNoPosts =
      '\u672a\u627e\u5230\u76f8\u5173\u5e16\u5b50';
  static const String _labelNoMore =
      '\u6ca1\u6709\u66f4\u591a\u7ed3\u679c\u4e86';
  static const String _labelRecentSearches = '\u6700\u8fd1\u641c\u7d22';
  static const String _labelNoRecentSearches =
      '\u6682\u65e0\u6700\u8fd1\u641c\u7d22';
  static const String _labelClearRecent =
      '\u6e05\u7a7a\u6700\u8fd1\u641c\u7d22';
  static const String _labelNeedKeyword =
      '\u8bf7\u8f93\u5165\u5173\u952e\u8bcd\u5f00\u59cb\u641c\u7d22';
  static const String _labelSearchFailed =
      '\u641c\u7d22\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  static const String _labelClearRecentSuccess =
      '\u5df2\u6e05\u7a7a\u6700\u8fd1\u641c\u7d22';
  static const String _labelNeedLogin =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';

  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _keywordFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  _SearchMode _searchMode = _SearchMode.posts;
  List<RiverSidePostSearchItem> _postItems = const <RiverSidePostSearchItem>[];
  List<RiverSideUserSearchItem> _userItems = const <RiverSideUserSearchItem>[];
  List<String> _recentSearches = const <String>[];

  bool _loading = false;
  bool _loadingMorePosts = false;
  bool _hasMorePostPages = false;
  bool _loadingRecentSearches = false;
  bool _clearingRecentSearches = false;
  int _currentPostPage = 0;
  int _requestSerial = 0;
  String _activeQuery = '';
  String? _error;
  String? _lastActiveUsername;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _scrollController.addListener(_onScroll);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _keywordController.dispose();
    _keywordFocusNode.dispose();
    super.dispose();
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
    if (_searchMode != _SearchMode.posts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset) {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _recentSearches = const <String>[];
        _loadingRecentSearches = false;
      });
      return;
    }

    setState(() {
      _loadingRecentSearches = true;
    });

    try {
      final recent = await widget.dependencies.accountStore.riverSideApiClient
          .fetchRecentSearches(cookieHeader: cookieHeader);
      if (!mounted) {
        return;
      }
      setState(() {
        _recentSearches = recent;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Keep UI resilient: recent-search endpoint can fail independently.
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecentSearches = false;
        });
      }
    }
  }

  Future<void> _clearRecentSearches() async {
    if (_clearingRecentSearches) {
      return;
    }

    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _showSnackBar(_labelNeedLogin);
      return;
    }

    setState(() {
      _clearingRecentSearches = true;
    });

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .clearRecentSearches(cookieHeader: cookieHeader);
      if (!mounted) {
        return;
      }
      setState(() {
        _recentSearches = const <String>[];
      });
      _showSnackBar(_labelClearRecentSuccess);
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_labelSearchFailed);
    } finally {
      if (mounted) {
        setState(() {
          _clearingRecentSearches = false;
        });
      }
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _keywordController.text.trim();
    if (query.isEmpty) {
      setState(() {
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
    setState(() {
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
          setState(() {
            _postItems = merged;
            _userItems = const <RiverSideUserSearchItem>[];
            _currentPostPage = page.page;
            _hasMorePostPages = page.hasMore;
          });
          break;
        case _SearchMode.users:
          final users = await apiClient.searchUsers(
            term: targetQuery,
            limit: _userSearchLimit,
            cookieHeader: cookieHeader,
          );
          if (!mounted || serial != _requestSerial) {
            return;
          }
          setState(() {
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
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _error = _labelSearchFailed;
      });
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() {
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
    setState(() {
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
      MaterialPageRoute<void>(
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
      MaterialPageRoute<void>(
        builder: (_) => RiverSideProfilePage(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_labelSearch),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Hero(
                tag: postsSearchHeroTag,
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _keywordController,
              focusNode: _keywordFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _labelSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () => _runSearch(reset: true),
                  tooltip: _labelSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runSearch(reset: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_SearchMode>(
                segments: _SearchMode.values
                    .map(
                      (mode) => ButtonSegment<_SearchMode>(
                        value: mode,
                        label: Text(mode.label),
                      ),
                    )
                    .toList(growable: false),
                selected: <_SearchMode>{_searchMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  _onModeChanged(selection.first);
                },
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
