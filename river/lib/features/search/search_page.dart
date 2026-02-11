import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_search_models.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

part 'search_page_view.dart';
part 'search_page_actions.dart';

const String postsSearchHeroTag = 'posts-search-entry-hero';

enum _SearchMode { posts, users }

extension on _SearchMode {
  String get label {
    switch (this) {
      case _SearchMode.posts:
        return '帖子';
      case _SearchMode.users:
        return '用户';
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

  static const String _labelSearch = '搜索';
  static const String _labelSearchHint = '输入关键词';
  static const String _labelRetry = '重试';
  static const String _labelNoUsers = '未找到相关用户';
  static const String _labelNoPosts = '未找到相关帖子';
  static const String _labelNoMore = '没有更多结果了';
  static const String _labelRecentSearches = '最近搜索';
  static const String _labelNoRecentSearches = '暂无最近搜索';
  static const String _labelClearRecent = '清空最近搜索';
  static const String _labelNeedKeyword = '请输入关键词开始搜索';
  static const String _labelSearchFailed = '搜索失败，请稍后重试';
  static const String _labelClearRecentSuccess = '已清空最近搜索';
  static const String _labelNeedLogin = '请先登录 RiverSide 账号';

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

  void _mutateState(VoidCallback action) {
    if (!mounted) {
      return;
    }
    setState(action);
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage(context);
  }
}
