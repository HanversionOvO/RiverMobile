import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';

enum _FloatingActionMode { hidden, backToTop, refresh }

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  static const double _loadMoreTriggerOffset = 280;
  static const double _showActionButtonOffset = 420;
  static const double _actionSwitchDelta = 24;
  static const int _maxScanPagePerLoad = 4;

  final ScrollController _scrollController = ScrollController();

  RiverSideTopicFeed _selectedFeed = RiverSideTopicFeed.latestCreated;
  List<RiverSideTopicSummary> _topics = const <RiverSideTopicSummary>[];
  List<RiverSideCategoryOption> _categories = const <RiverSideCategoryOption>[];
  bool _loadingCategories = false;
  bool _loadingFirstPage = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _error;
  int _requestSerial = 0;
  double _lastScrollOffset = 0;
  _FloatingActionMode _floatingActionMode = _FloatingActionMode.hidden;
  String? _lastActiveUsername;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadFirstPage(clearExisting: true);
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    final last = _lastActiveUsername;
    if (current == last) {
      return;
    }

    _lastActiveUsername = current;
    _loadCategories();
    _loadFirstPage(clearExisting: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    if (offset >= maxExtent - _loadMoreTriggerOffset) {
      _loadMore();
    }

    var nextMode = _floatingActionMode;
    if (offset < _showActionButtonOffset) {
      nextMode = _FloatingActionMode.hidden;
    } else {
      final delta = offset - _lastScrollOffset;
      if (delta <= -_actionSwitchDelta) {
        nextMode = _FloatingActionMode.refresh;
      } else if (delta >= _actionSwitchDelta ||
          _floatingActionMode == _FloatingActionMode.hidden) {
        nextMode = _FloatingActionMode.backToTop;
      }
    }

    if (nextMode != _floatingActionMode) {
      setState(() {
        _floatingActionMode = nextMode;
      });
    }

    _lastScrollOffset = offset;
  }

  String? _activeCookieHeader() {
    final activeUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    if (activeUsername == null || activeUsername.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(
      activeUsername,
    );
  }

  Future<void> _loadCategories() async {
    if (_loadingCategories) {
      return;
    }

    setState(() {
      _loadingCategories = true;
    });

    try {
      final categories = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .fetchCategories(cookieHeader: _activeCookieHeader());
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
      _refreshSelectedCategoryName();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingCategories = false;
      });
    }
  }

  Future<void> _ensureCategoriesLoaded() async {
    if (_categories.isNotEmpty || _loadingCategories) {
      return;
    }
    await _loadCategories();
  }

  void _refreshSelectedCategoryName() {
    final selectedId = _selectedCategoryId;
    if (selectedId == null) {
      return;
    }

    for (final category in _categories) {
      if (category.id == selectedId) {
        final displayName = _displayCategoryName(category);
        if (_selectedCategoryName != displayName && mounted) {
          setState(() {
            _selectedCategoryName = displayName;
          });
        }
        return;
      }
    }
  }

  String _displayCategoryName(RiverSideCategoryOption category) {
    final parentId = category.parentCategoryId;
    if (parentId == null) {
      return category.name;
    }

    for (final item in _categories) {
      if (item.id == parentId) {
        return '${item.name} / ${category.name}';
      }
    }
    return category.name;
  }

  Future<void> _loadFirstPage({required bool clearExisting}) async {
    final serial = ++_requestSerial;
    setState(() {
      _loadingFirstPage = true;
      _loadingMore = false;
      _error = null;
      _hasMore = true;
      _currentPage = 0;
      if (clearExisting) {
        _topics = const <RiverSideTopicSummary>[];
      }
    });

    try {
      var pageNumber = 0;
      var page = await widget.dependencies.accountStore.riverSideApiClient
          .fetchTopicPage(
            feed: _selectedFeed,
            page: pageNumber,
            cookieHeader: _activeCookieHeader(),
            categoryId: _selectedCategoryId,
          );

      // Category filter may have no match in early pages; scan ahead.
      var scanned = 0;
      while (_selectedCategoryId != null &&
          page.topics.isEmpty &&
          page.hasMore &&
          scanned < _maxScanPagePerLoad) {
        scanned++;
        pageNumber++;
        page = await widget.dependencies.accountStore.riverSideApiClient
            .fetchTopicPage(
              feed: _selectedFeed,
              page: pageNumber,
              cookieHeader: _activeCookieHeader(),
              categoryId: _selectedCategoryId,
            );
      }

      if (!mounted || serial != _requestSerial) {
        return;
      }

      setState(() {
        _topics = page.topics;
        _hasMore = page.hasMore;
        _currentPage = pageNumber;
        _loadingFirstPage = false;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingFirstPage = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingFirstPage = false;
        _error =
            '\u8d34\u5b50\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingFirstPage || _loadingMore || !_hasMore) {
      return;
    }

    final serial = _requestSerial;
    setState(() {
      _loadingMore = true;
    });

    try {
      var nextPage = _currentPage + 1;
      var scanned = 0;
      var hasMore = true;
      final merged = <RiverSideTopicSummary>[];
      final existingIds = _topics.map((topic) => topic.id).toSet();

      while (hasMore && scanned < _maxScanPagePerLoad) {
        scanned++;
        final page = await widget.dependencies.accountStore.riverSideApiClient
            .fetchTopicPage(
              feed: _selectedFeed,
              page: nextPage,
              cookieHeader: _activeCookieHeader(),
              categoryId: _selectedCategoryId,
            );

        for (final topic in page.topics) {
          if (existingIds.contains(topic.id)) {
            continue;
          }
          existingIds.add(topic.id);
          merged.add(topic);
        }

        hasMore = page.hasMore;
        if (merged.isNotEmpty || !hasMore) {
          break;
        }
        nextPage++;
      }

      if (!mounted || serial != _requestSerial) {
        return;
      }

      setState(() {
        _topics = <RiverSideTopicSummary>[..._topics, ...merged];
        _currentPage = nextPage;
        _hasMore = hasMore;
        _loadingMore = false;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u52a0\u8f7d\u66f4\u591a\u5931\u8d25')),
      );
    }
  }

  Future<void> _onRefresh() async {
    await _loadFirstPage(clearExisting: false);
  }

  Future<void> _onFloatingActionPressed() async {
    if (_floatingActionMode == _FloatingActionMode.backToTop) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    if (_floatingActionMode == _FloatingActionMode.refresh) {
      await _onRefresh();
    }
  }

  Future<void> _onCategoryButtonPressed() async {
    if (_selectedCategoryId != null) {
      setState(() {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
      });
      _loadFirstPage(clearExisting: true);
      return;
    }

    await _ensureCategoriesLoaded();
    if (!mounted) {
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u6682\u65e0\u53ef\u7528\u7c7b\u522b')),
      );
      return;
    }

    final selected = await showModalBottomSheet<RiverSideCategoryOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _CategoryPickerSheet(
          groups: _buildCategoryGroups(),
          selectedCategoryId: _selectedCategoryId,
          onSelected: (category) => Navigator.of(sheetContext).pop(category),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedCategoryId = selected.id;
      _selectedCategoryName = _displayCategoryName(selected);
      _floatingActionMode = _FloatingActionMode.hidden;
    });
    _lastScrollOffset = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage(clearExisting: true);
  }

  List<_CategoryGroup> _buildCategoryGroups() {
    final byId = <int, RiverSideCategoryOption>{
      for (final item in _categories) item.id: item,
    };

    final childrenByParent = <int, List<RiverSideCategoryOption>>{};
    for (final item in _categories) {
      final parentId = item.parentCategoryId;
      if (parentId == null || !byId.containsKey(parentId)) {
        continue;
      }
      childrenByParent.putIfAbsent(parentId, () => <RiverSideCategoryOption>[]);
      childrenByParent[parentId]!.add(item);
    }

    for (final entry in childrenByParent.entries) {
      entry.value.sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) {
          return byPosition;
        }
        return a.id.compareTo(b.id);
      });
    }

    final groups = <_CategoryGroup>[];
    final handledParentIds = <int>{};
    for (final item in _categories) {
      if (item.parentCategoryId != null || handledParentIds.contains(item.id)) {
        continue;
      }
      handledParentIds.add(item.id);
      groups.add(
        _CategoryGroup(
          parent: item,
          children:
              childrenByParent[item.id] ?? const <RiverSideCategoryOption>[],
        ),
      );
    }

    for (final item in _categories) {
      if (item.parentCategoryId != null &&
          byId.containsKey(item.parentCategoryId)) {
        continue;
      }
      if (handledParentIds.contains(item.id)) {
        continue;
      }
      handledParentIds.add(item.id);
      groups.add(
        _CategoryGroup(
          parent: item,
          children: const <RiverSideCategoryOption>[],
        ),
      );
    }

    return groups;
  }

  void _onFeedChanged(RiverSideTopicFeed nextFeed) {
    if (nextFeed == _selectedFeed) {
      return;
    }

    setState(() {
      _selectedFeed = nextFeed;
      _floatingActionMode = _FloatingActionMode.hidden;
    });
    _lastScrollOffset = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage(clearExisting: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<RiverSideTopicFeed>(
                    segments: RiverSideTopicFeed.values
                        .map(
                          (feed) => ButtonSegment<RiverSideTopicFeed>(
                            value: feed,
                            label: Text(feed.label),
                          ),
                        )
                        .toList(),
                    selected: <RiverSideTopicFeed>{_selectedFeed},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      _onFeedChanged(selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildCategoryButton(),
            ],
          ),
        ),
        Expanded(child: _buildBodyWithActionButton()),
      ],
    );
  }

  Widget _buildCategoryButton() {
    if (_selectedCategoryId == null) {
      return OutlinedButton(
        onPressed: _onCategoryButtonPressed,
        child: const Text('\u5e16\u5b50\u7c7b\u522b'),
      );
    }

    return FilledButton.tonal(
      onPressed: _onCategoryButtonPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_selectedCategoryName ?? '\u5df2\u9009\u7c7b\u522b'),
          const SizedBox(width: 6),
          const Icon(Icons.close, size: 16),
        ],
      ),
    );
  }

  Widget _buildBodyWithActionButton() {
    return Stack(
      children: [
        Positioned.fill(child: _buildBody()),
        Positioned(
          right: 16,
          bottom: 20,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: _floatingActionMode == _FloatingActionMode.hidden ? 0 : 1,
            child: _floatingActionMode == _FloatingActionMode.hidden
                ? const SizedBox.shrink()
                : FloatingActionButton.small(
                    onPressed: _onFloatingActionPressed,
                    child: Icon(
                      _floatingActionMode == _FloatingActionMode.backToTop
                          ? Icons.vertical_align_top
                          : Icons.refresh,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loadingFirstPage && _topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadFirstPage(clearExisting: false),
                child: const Text('\u91cd\u8bd5'),
              ),
            ],
          ),
        ),
      );
    }

    if (_topics.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('\u6682\u65e0\u5e16\u5b50')),
          ],
        ),
      );
    }

    final showHotIcon = _selectedFeed == RiverSideTopicFeed.hot;
    final itemCount = _topics.length + 1;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= _topics.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (!_hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '\u6ca1\u6709\u66f4\u591a\u4e86',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            return const SizedBox(height: 32);
          }

          final topic = _topics[index];
          return _TopicCard(topic: topic, showHotIcon: showHotIcon);
        },
      ),
    );
  }
}

class _CategoryGroup {
  const _CategoryGroup({required this.parent, required this.children});

  final RiverSideCategoryOption parent;
  final List<RiverSideCategoryOption> children;
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.groups,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<_CategoryGroup> groups;
  final int? selectedCategoryId;
  final ValueChanged<RiverSideCategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _CategoryGroupCard(
            group: group,
            selectedCategoryId: selectedCategoryId,
            onSelected: onSelected,
          );
        },
      ),
    );
  }
}

class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({
    required this.group,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final _CategoryGroup group;
  final int? selectedCategoryId;
  final ValueChanged<RiverSideCategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final parent = group.parent;
    final children = group.children;
    final parentSelected = selectedCategoryId == parent.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: Text(parent.name),
              subtitle: parent.description.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        parent.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              trailing: Icon(
                parentSelected ? Icons.check_circle : Icons.chevron_right,
                color: parentSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onTap: () => onSelected(parent),
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final child in children)
                    FilterChip(
                      selected: selectedCategoryId == child.id,
                      label: Text(child.name),
                      onSelected: (_) => onSelected(child),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.showHotIcon});

  final RiverSideTopicSummary topic;
  final bool showHotIcon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: topic.authorAvatarUrl.isEmpty
                      ? null
                      : NetworkImage(topic.authorAvatarUrl),
                  child: topic.authorAvatarUrl.isEmpty
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    topic.authorDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                ),
                if (showHotIcon || topic.isHot)
                  const Icon(
                    Icons.local_fire_department_outlined,
                    color: Colors.deepOrange,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              topic.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (topic.excerpt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                topic.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: subtitleColor),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: _CategoryPill(
                    label: topic.categoryName,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(width: 10),
                _MetaInfo(
                  icon: Icons.schedule_outlined,
                  text: _formatDateTime(topic.createdAt),
                  color: subtitleColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaInfo(
                  icon: Icons.chat_bubble_outline,
                  text: topic.replyCount.toString(),
                  color: subtitleColor,
                ),
                _MetaInfo(
                  icon: Icons.visibility_outlined,
                  text: topic.viewCount.toString(),
                  color: subtitleColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final local = value.toLocal();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
