import 'dart:async';
import 'dart:ui'; // 用于 ImageFilter

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

// -----------------------------------------------------------------------------
// 控制器 (保持兼容)
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

  /// 滚动当前激活的 Tab 到顶部并刷新
  Future<void> scrollToTopAndRefresh() async {
    await _state?._scrollToTopAndRefresh();
  }
}

// -----------------------------------------------------------------------------
// 主页面
// -----------------------------------------------------------------------------
class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.dependencies, this.controller});

  final AppDependencies dependencies;
  final PostsPageController? controller;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> with TickerProviderStateMixin {
  // 数据源
  List<RiverSideCategoryOption> _categories = [];
  bool _loadingCategories = false;

  // 筛选状态 (全局共享)
  int? _selectedBoardId;
  String? _selectedBoardName;

  // Tab 控制
  late TabController _tabController;
  final List<RiverSideTopicFeed> _feeds = RiverSideTopicFeed.values;

  // 用于通过 Key 通知子 Tab 刷新的机制
  int _filterVersion = 0;

  // 引用子组件以控制滚动
  final Map<int, GlobalKey<_TopicListTabState>> _tabKeys = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _tabController = TabController(length: _feeds.length, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (_loadingCategories) return;
    try {
      final categories = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .fetchCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Failed to load boards: $e');
    }
  }

  Future<void> _scrollToTopAndRefresh() async {
    final key = _tabKeys[_tabController.index];
    key?.currentState?.scrollToTopAndRefresh();
  }

  void _onBoardFilterPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _RiverSideBoardPicker(
        categories: _categories,
        selectedId: _selectedBoardId,
        onSelected: (category) {
          Navigator.pop(context);
          if (_selectedBoardId == category?.id) return;
          setState(() {
            _selectedBoardId = category?.id;
            _selectedBoardName = category?.name;
            _filterVersion++; // 触发子 Tab 重建/刷新
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              // 1. 移除 Title，节省顶部空间
              title: null,
              toolbarHeight: 0, // 隐藏标准 Toolbar 区域
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
              // 自定义 Bottom 区域作为主要导航栏
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52), // 稍微增加高度以容纳 padding
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.2,
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // TabBar
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

                      // 垂直分割线
                      Container(
                        width: 1,
                        height: 20,
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.5,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                      // 2. 板块筛选按钮 (Hero 源)
                      _buildBoardFilterButton(theme),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
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
              filterVersion: _filterVersion,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBoardFilterButton(ThemeData theme) {
    final hasSelection = _selectedBoardId != null;
    final label = _selectedBoardName ?? '全部板块';

    return Hero(
      tag: 'board_picker_hero', // Hero 标签
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
// 单个 Tab 的帖子列表
// -----------------------------------------------------------------------------
class _TopicListTab extends StatefulWidget {
  const _TopicListTab({
    super.key,
    required this.dependencies,
    required this.feed,
    this.boardId,
    required this.filterVersion,
  });

  final AppDependencies dependencies;
  final RiverSideTopicFeed feed;
  final int? boardId;
  final int filterVersion;

  @override
  State<_TopicListTab> createState() => _TopicListTabState();
}

class _TopicListTabState extends State<_TopicListTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  List<RiverSideTopicSummary> _topics = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;
  int _requestSerial = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
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
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 200 && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadFirstPage();
  }

  Future<void> scrollToTopAndRefresh() {
    return _scrollToTopAndRefresh();
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
        _error = e is RiverSideApiException ? e.message : '加载失败';
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

  void _openDetail(int id) {
    Navigator.of(context).push(
      riverPageRoute(
        builder: (_) =>
            TopicDetailPage(dependencies: widget.dependencies, topicId: id),
      ),
    );
  }

  void _openAuthor(RiverSideTopicSummary topic) {
    // 生成 Hero Tag
    final heroTag = 'avatar_${topic.id}_${topic.authorUsername}';

    showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: topic.authorUsername,
      heroTagAvatar: heroTag, // 传递 Tag，确保 riverside_profile_sheet.dart 已更新支持此参数
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
              child: const Text('重试'),
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
            const Text('暂无帖子', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _loadFirstPage, child: const Text('刷新')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      edgeOffset: 0,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
                        '没有更多了',
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
            isHotFeed: widget.feed == RiverSideTopicFeed.hot,
            onTap: () => _openDetail(topic.id),
            onAuthorTap: () => _openAuthor(topic),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 美化后的板块选择器
// -----------------------------------------------------------------------------
class _RiverSideBoardPicker extends StatelessWidget {
  const _RiverSideBoardPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<RiverSideCategoryOption> categories;
  final int? selectedId;
  final ValueChanged<RiverSideCategoryOption?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = buildRiverSideCategoryGroups(categories);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Header (标题区域)
        Hero(
          tag: 'board_picker_hero',
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '选择板块',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 列表内容
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              // 2. 优化后的“全部板块”按钮
              InkWell(
                onTap: () => onSelected(null),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    boxShadow: [
                      if (selectedId == null)
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '全部板块',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (selectedId == null)
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. 板块分组列表
              ...groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BoardGroupCard(
                    group: group,
                    selectedId: selectedId,
                    onSelected: onSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardGroupCard extends StatelessWidget {
  const _BoardGroupCard({
    required this.group,
    required this.selectedId,
    required this.onSelected,
  });

  final RiverSideCategoryGroup group;
  final int? selectedId;
  final ValueChanged<RiverSideCategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent = group.parent;
    final isParentSelected = selectedId == parent.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 父板块
        InkWell(
          onTap: () => onSelected(parent),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isParentSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    parent.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isParentSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isParentSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),

        // 子板块 (Chips)
        if (group.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.children.map((child) {
                final isSelected = selectedId == child.id;
                return FilterChip(
                  selected: isSelected,
                  label: Text(child.name),
                  onSelected: (_) => onSelected(child),
                  side: BorderSide.none,
                  showCheckmark: false, // 已移除对号
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  shape: const StadiumBorder(),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 帖子卡片
// -----------------------------------------------------------------------------
class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.isHotFeed,
    required this.onTap,
    required this.onAuthorTap,
  });

  final RiverSideTopicSummary topic;
  final bool isHotFeed;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPinned = topic.isPinned;
    final isHot = topic.isHot || isHotFeed;

    // 为头像生成唯一的 Hero Tag
    final avatarHeroTag = 'avatar_${topic.id}_${topic.authorUsername}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部信息栏
                Row(
                  children: [
                    GestureDetector(
                      onTap: onAuthorTap,
                      child: Hero(
                        tag: avatarHeroTag,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundImage: topic.authorAvatarUrl.isNotEmpty
                              ? NetworkImage(topic.authorAvatarUrl)
                              : null,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: topic.authorAvatarUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: topic.authorDisplayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: _formatTimeRelative(topic.createdAt),
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPinned)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '置顶',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isHot)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '热门',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // 标题
                Text(
                  topic.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // 摘要
                if (topic.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    topic.excerpt.replaceAll('\n', ' '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // 底部数据栏
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        topic.categoryName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
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

  String _formatTimeRelative(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
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
