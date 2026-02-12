import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/categories/riverside_category_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
import 'package:river/features/search/search_page.dart';
import 'package:river/core/widgets/riverside_category_picker_sheet.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
class PostsPageController {
  _PostsPageState? _state;

  void _attach(_PostsPageState state) {
    _state = state;
  }

  void _detach(_PostsPageState state) {
    if (_state == state) {
      _state = null;
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    await _state?._scrollToTopAndRefresh();
  }
}

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.dependencies, this.controller});

  final AppDependencies dependencies;
  final PostsPageController? controller;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> with TickerProviderStateMixin {
  static const String _latestTopicChannel = '/latest';

  List<RiverSideCategoryOption> _categories = [];
  bool _loadingCategories = false;

  int? _selectedBoardId;
  String? _selectedBoardName;

  late TabController _tabController;
  final List<RiverSideTopicFeed> _feeds = RiverSideTopicFeed.values;

  int _filterVersion = 0;

  final Map<int, GlobalKey<_TopicListTabState>> _tabKeys = {};
  String? _lastActiveUsername;
  RiverSideMessageBusPoller? _messageBusPoller;
  bool _hasRealtimeTopicUpdate = false;
  double _headerScrollFactor = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _tabController = TabController(length: _feeds.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCategories();
    _restartRealtimePolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderWithCurrentTab();
    });
  }

  @override
  void dispose() {
    _messageBusPoller?.stop();
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    widget.controller?._detach(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) {
      return;
    }
    _lastActiveUsername = current;
    _messageBusPoller?.stop();
    _messageBusPoller = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _hasRealtimeTopicUpdate = false;
      _filterVersion++;
    });
    _loadCategories();
    unawaited(_scrollToTopAndRefresh());
    _restartRealtimePolling();
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  void _restartRealtimePolling() {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }

    final poller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookie,
      channelLastIds: RiverSideMessageBusPoller.buildInitialChannels(
        const <String>[_latestTopicChannel],
      ),
      onEvents: (events) {
        if (!mounted || events.isEmpty) {
          return;
        }
        final hasLatestEvent = events.any(
          (event) => event.channel == _latestTopicChannel,
        );
        if (!hasLatestEvent || _hasRealtimeTopicUpdate) {
          return;
        }
        setState(() {
          _hasRealtimeTopicUpdate = true;
        });
      },
    );
    _messageBusPoller = poller;
    poller.start();
  }

  Future<void> _consumeRealtimeTopicUpdate() async {
    if (_hasRealtimeTopicUpdate && mounted) {
      setState(() {
        _hasRealtimeTopicUpdate = false;
      });
    }
    await _scrollToTopAndRefresh();
  }

  void _dismissRealtimeTopicUpdateHint() {
    if (!_hasRealtimeTopicUpdate || !mounted) {
      return;
    }
    setState(() {
      _hasRealtimeTopicUpdate = false;
    });
  }

  Future<List<RiverSideCategoryOption>> _loadCategories({
    bool forceRefresh = false,
  }) async {
    if (_loadingCategories) return _categories;
    _loadingCategories = true;
    try {
      final cookie = _activeCookieHeader();
      final activeUsername =
          widget.dependencies.accountStore.activeRiverSideUsername;
      var categories = await RiverSideCategoryStore.instance.load(
        apiClient: widget.dependencies.accountStore.riverSideApiClient,
        username: activeUsername,
        cookieHeader: cookie,
        forceRefresh: forceRefresh,
      );
      if (!forceRefresh &&
          cookie != null &&
          cookie.trim().isNotEmpty &&
          categories.isEmpty) {
        categories = await RiverSideCategoryStore.instance.load(
          apiClient: widget.dependencies.accountStore.riverSideApiClient,
          username: activeUsername,
          cookieHeader: cookie,
          forceRefresh: true,
        );
      }
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_selectedBoardId != null) {
            final selected = findRiverSideCategoryById(
              id: _selectedBoardId,
              categories: _categories,
            );
            _selectedBoardName = selected == null
                ? null
                : displayRiverSideCategoryName(
                    category: selected,
                    allCategories: _categories,
                  );
          }
        });
      }
      return categories;
    } catch (e) {
      debugPrint('Failed to load boards: $e');
      return _categories;
    } finally {
      _loadingCategories = false;
    }
  }

  Future<void> _scrollToTopAndRefresh() async {
    final key = _tabKeys[_tabController.index];
    key?.currentState?.scrollToTopAndRefresh();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _syncHeaderWithCurrentTab();
  }

  void _syncHeaderWithCurrentTab() {
    final key = _tabKeys[_tabController.index];
    final offset = key?.currentState?.currentScrollOffset ?? 0;
    _onActiveTabScrollOffsetChanged(offset);
  }

  void _onActiveTabScrollOffsetChanged(double offset) {
    final next = (offset / 96).clamp(0.0, 1.0);
    if ((_headerScrollFactor - next).abs() < 0.01 || !mounted) {
      return;
    }
    setState(() {
      _headerScrollFactor = next;
    });
  }

  void _onBoardFilterPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => RiverSideCategoryPickerSheet(
        initialCategories: _categories,
        selectedCategoryId: _selectedBoardId,
        allowSelectAll: true,
        onRefreshCategories: ({bool forceRefresh = false}) {
          return _loadCategories(forceRefresh: forceRefresh);
        },
        onSelected: (category) {
          Navigator.pop(context);
          if (_selectedBoardId == category?.id) return;
          setState(() {
            _selectedBoardId = category?.id;
            _selectedBoardName = category == null
                ? null
                : displayRiverSideCategoryName(
                    category: category,
                    allCategories: _categories,
                  );
            _filterVersion++;
          });
        },
      ),
    );
  }

  Map<int, String> _buildCategoryNameMap() {
    if (_categories.isEmpty) {
      return const <int, String>{};
    }
    return <int, String>{
      for (final category in _categories)
        category.id: displayRiverSideCategoryName(
          category: category,
          allCategories: _categories,
        ),
    };
  }

  Future<void> _openSearchPage() async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => SearchPage(dependencies: widget.dependencies),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final easedHeaderFactor = Curves.easeOutCubic.transform(
      _headerScrollFactor,
    );
    final categoryNameMap = _buildCategoryNameMap();
    final topHintOffset =
        MediaQuery.paddingOf(context).top +
        lerpDouble(72, 66, easedHeaderFactor)!;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopHeader(theme, easedHeaderFactor),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _feeds.asMap().entries.map((entry) {
                    final index = entry.key;
                    final feed = entry.value;

                    _tabKeys[index] ??= GlobalKey<_TopicListTabState>();

                    return _TopicListTab(
                      key: _tabKeys[index],
                      dependencies: widget.dependencies,
                      feed: feed,
                      boardId: _selectedBoardId,
                      categoryNameMap: categoryNameMap,
                      filterVersion: _filterVersion,
                      onScrollOffsetChanged: (offset) {
                        if (_tabController.index != index) {
                          return;
                        }
                        _onActiveTabScrollOffsetChanged(offset);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            top: topHintOffset,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: !_hasRealtimeTopicUpdate,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  offset: _hasRealtimeTopicUpdate
                      ? Offset.zero
                      : const Offset(0, -0.3),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _hasRealtimeTopicUpdate ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      scale: _hasRealtimeTopicUpdate ? 1 : 0.97,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Material(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.transparent,
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.shadow.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: _consumeRealtimeTopicUpdate,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          8,
                                          8,
                                          8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.fiber_new_rounded,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                '有新帖子，点击刷新',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '关闭',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _dismissRealtimeTopicUpdateHint,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(ThemeData theme, double t) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapse = t.clamp(0.0, 1.0);
    const titleSize = 21.0;
    final subtitleVisibility = (1.0 - collapse).clamp(0.0, 1.0);
    final borderAlpha = lerpDouble(0.18, 0.26, collapse)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(
              alpha: lerpDouble(0.90, 0.96, t)!,
            ),
            theme.colorScheme.surfaceContainerLowest.withValues(
              alpha: lerpDouble(0.82, 0.92, t)!,
            ),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: borderAlpha,
            ),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: lerpDouble(7, 11, t)!,
            sigmaY: lerpDouble(7, 11, t)!,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topInset + lerpDouble(9, 8, collapse)!,
              bottom: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 64),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '帖子',
                                  textAlign: TextAlign.left,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    fontSize: titleSize,
                                  ),
                                ),
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    heightFactor: subtitleVisibility,
                                    child: Opacity(
                                      opacity: subtitleVisibility,
                                      child: Text(
                                        _feeds[_tabController.index].label,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            onPressed: _openSearchPage,
                            tooltip: '搜索',
                            icon: Hero(
                              tag: postsSearchHeroTag,
                              child: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorColor: theme.colorScheme.primary,
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor:
                                theme.colorScheme.onSurfaceVariant,
                            indicatorSize: TabBarIndicatorSize.label,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            labelPadding: const EdgeInsets.only(right: 24),
                            tabs: _feeds
                                .map((feed) => Tab(text: feed.label))
                                .toList(),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        _buildBoardFilterButton(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardFilterButton(ThemeData theme) {
    final hasSelection = _selectedBoardId != null;
    final label = _selectedBoardName ?? '\u5168\u90e8\u677f\u5757';

    return Hero(
      tag: 'board_picker_hero',
      flightShuttleBuilder:
          (flightContext, animation, direction, fromContext, toContext) {
            return Material(color: Colors.transparent, child: toContext.widget);
          },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBoardFilterPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: hasSelection
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: hasSelection
                  ? Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasSelection
                      ? Icons.dashboard_rounded
                      : Icons.dashboard_customize_outlined,
                  size: 16,
                  color: hasSelection
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSelection
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: hasSelection
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
class _TopicListTab extends StatefulWidget {
  const _TopicListTab({
    super.key,
    required this.dependencies,
    required this.feed,
    this.boardId,
    required this.categoryNameMap,
    required this.filterVersion,
    this.onScrollOffsetChanged,
  });

  final AppDependencies dependencies;
  final RiverSideTopicFeed feed;
  final int? boardId;
  final Map<int, String> categoryNameMap;
  final int filterVersion;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<_TopicListTab> createState() => _TopicListTabState();
}

class _TopicListTabState extends State<_TopicListTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showBackToTopNotifier = ValueNotifier<bool>(false);
  List<RiverSideTopicSummary> _topics = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;
  int _requestSerial = 0;

  @override
  bool get wantKeepAlive => true;

  double get currentScrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onScrollOffsetChanged?.call(currentScrollOffset);
    });
  }

  @override
  void didUpdateWidget(covariant _TopicListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId ||
        oldWidget.filterVersion != widget.filterVersion) {
      _scrollToTopAndRefresh();
    }
  }

  @override
  void dispose() {
    _showBackToTopNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    widget.onScrollOffsetChanged?.call(currentScroll);
    final shouldShowBackToTop = currentScroll >= 420;
    if (_showBackToTopNotifier.value != shouldShowBackToTop) {
      _showBackToTopNotifier.value = shouldShowBackToTop;
    }
    if (currentScroll >= maxScroll - 200 && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  String _displayCategoryName(RiverSideTopicSummary topic) {
    final categoryId = topic.categoryId;
    if (categoryId != null) {
      final mapped = widget.categoryNameMap[categoryId];
      if (mapped != null && mapped.trim().isNotEmpty) {
        return mapped;
      }
    }
    return topic.categoryName;
  }

  Future<void> _scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    widget.onScrollOffsetChanged?.call(0);
    _showBackToTopNotifier.value = false;
    await _loadFirstPage();
  }

  Future<void> scrollToTopAndRefresh() {
    return _scrollToTopAndRefresh();
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

  Future<void> _loadFirstPage() async {
    final serial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final topics = await _fetchTopics(page: 0);
      if (!mounted || serial != _requestSerial) return;

      setState(() {
        _topics = topics;
        _isLoading = false;
        _hasMore = topics.isNotEmpty;
        _page = 0;
      });
    } catch (e) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _isLoading = false;
        _error = e is RiverSideApiException
            ? e.message
            : '\u52a0\u8f7d\u5931\u8d25';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    final serial = _requestSerial;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final newTopics = await _fetchTopics(page: nextPage);
      if (!mounted || serial != _requestSerial) return;

      setState(() {
        if (newTopics.isEmpty) {
          _hasMore = false;
        } else {
          final existingIds = _topics.map((e) => e.id).toSet();
          _topics.addAll(newTopics.where((e) => !existingIds.contains(e.id)));
          _page = nextPage;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<List<RiverSideTopicSummary>> _fetchTopics({required int page}) {
    final cookie = widget.dependencies.accountStore.riverSideCookieHeaderFor(
      widget.dependencies.accountStore.activeRiverSideUsername ?? '',
    );
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchTopicSummaries(
          feed: widget.feed,
          categoryId: widget.boardId,
          page: page,
          cookieHeader: cookie,
        );
  }

  void _openDetail(RiverSideTopicSummary topic) {
    final avatarHeroTag = _buildAuthorAvatarHeroTag(topic);
    final nameHeroTag = _buildAuthorNameHeroTag(topic);
    final titleHeroTag = 'title_${topic.id}';
    Navigator.of(context).push(
      riverPageRoute(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topic.id,
          preview: TopicDetailPreview(
            title: topic.title,
            authorDisplayName: topic.authorDisplayName,
            authorUsername: topic.authorUsername,
            authorAvatarUrl: topic.authorAvatarUrl,
            titleHeroTag: titleHeroTag,
            authorAvatarHeroTag: avatarHeroTag,
            authorNameHeroTag: nameHeroTag,
          ),
        ),
      ),
    );
  }

  void _openAuthor(RiverSideTopicSummary topic) {
    final avatarHeroTag = _buildAuthorAvatarHeroTag(topic);
    final nameHeroTag = _buildAuthorNameHeroTag(topic);

    showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: topic.authorUsername,
      displayName: topic.authorDisplayName,
      avatarUrl: topic.authorAvatarUrl,
      heroTagAvatar: avatarHeroTag,
      heroTagName: nameHeroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadFirstPage,
              child: const Text('\u91cd\u8bd5'),
            ),
          ],
        ),
      );
    }

    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              '\u6682\u65e0\u5e16\u5b50',
              style: TextStyle(color: Colors.grey),
            ),
            TextButton(
              onPressed: _loadFirstPage,
              child: const Text('\u5237\u65b0'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadFirstPage,
          edgeOffset: 0,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _topics.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == _topics.length) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: _isLoadingMore
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '\u6ca1\u6709\u66f4\u591a\u4e86',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                  ),
                );
              }
              final topic = _topics[index];
              return _TopicCard(
                topic: topic,
                displayCategoryName: _displayCategoryName(topic),
                isHotFeed: widget.feed == RiverSideTopicFeed.hot,
                onTap: () => _openDetail(topic),
                onAuthorTap: () => _openAuthor(topic),
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showBackToTopNotifier,
            builder: (context, visible, _) {
              return IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: visible ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    scale: visible ? 1 : 0.82,
                    child: FloatingActionButton.small(
                      heroTag: 'posts_back_to_top_${widget.feed.name}',
                      onPressed: visible ? _scrollToTop : null,
                      elevation: 2,
                      child: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
String _buildAuthorAvatarHeroTag(RiverSideTopicSummary topic) {
  return 'author_avatar_${topic.id}_${topic.authorUsername}';
}

String _buildAuthorNameHeroTag(RiverSideTopicSummary topic) {
  return 'author_name_${topic.id}_${topic.authorUsername}';
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    super.key, // 鎺ㄨ崘鍔犱笂 super.key
    required this.topic,
    required this.displayCategoryName,
    required this.isHotFeed,
    required this.onTap,
    required this.onAuthorTap,
  });

  final RiverSideTopicSummary topic;
  final String displayCategoryName;
  final bool isHotFeed;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPinned = topic.isPinned;
    final isHot = topic.isHot || isHotFeed;

    // 1. 瀹氫箟 Hero Tags (蹇呴』涓庣敤鎴疯祫鏂?Sheet 淇濇寔涓€鑷?
    final avatarHeroTag = _buildAuthorAvatarHeroTag(topic);
    final nameHeroTag = _buildAuthorNameHeroTag(topic);
    final titleHeroTag = 'title_${topic.id}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // 优化阴影：更柔和、扩散更平滑
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // 纭繚姘存尝绾逛笉婧㈠嚭鍦嗚
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withOpacity(0.08),
          highlightColor: theme.colorScheme.primary.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 椤堕儴淇℃伅鏍?---
                Row(
                  children: [
                    GestureDetector(
                      onTap: onAuthorTap,
                      child: Hero(
                        tag: avatarHeroTag,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundImage: topic.authorAvatarUrl.isNotEmpty
                              ? NetworkImage(topic.authorAvatarUrl)
                              : null,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: topic.authorAvatarUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: nameHeroTag,
                            child: Material(
                              color: Colors.transparent,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: topic.authorDisplayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimeRelative(topic.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 鏍囩鍖哄煙
                    if (isPinned)
                      _buildTag(
                        theme,
                        '置顶',
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primary,
                      ),
                    if (isPinned && isHot) const SizedBox(width: 6),
                    if (isHot)
                      _buildTag(
                        theme,
                        '热门',
                        Colors.orange.shade50,
                        Colors.orange.shade800,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // --- 标题 (Hero 源) ---
                Hero(
                  tag: titleHeroTag,
                  flightShuttleBuilder:
                      (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) {
                        return DefaultTextStyle.merge(
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ) ??
                              const TextStyle(),
                          child: (toHeroContext.widget as Hero).child,
                        );
                      },
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      topic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                if (topic.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    topic.excerpt.replaceAll('\n', ' '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // --- 搴曢儴鏁版嵁鏍?---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        displayCategoryName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _IconText(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: '${topic.replyCount}',
                    ),
                    const SizedBox(width: 16),
                    _IconText(
                      icon: Icons.remove_red_eye_outlined,
                      text: '${topic.viewCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 辅助方法：构建标签
  Widget _buildTag(ThemeData theme, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatTimeRelative(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '\u521a\u521a';
    if (diff.inMinutes < 60) return '${diff.inMinutes}\u5206\u949f\u524d';
    if (diff.inHours < 24) return '${diff.inHours}\u5c0f\u65f6\u524d';
    if (diff.inDays < 7) return '${diff.inDays}\u5929\u524d';
    return '${time.month}/${time.day}';
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
