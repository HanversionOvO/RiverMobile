import 'package:flutter/material.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/network/riverside_topic_models.dart';

typedef RiverSideCategoryLoader =
    Future<List<RiverSideCategoryOption>> Function({bool forceRefresh});

class RiverSideCategoryPickerSheet extends StatefulWidget {
  const RiverSideCategoryPickerSheet({
    super.key,
    required this.initialCategories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.allowSelectAll = false,
    this.onRefreshCategories,
  });

  final List<RiverSideCategoryOption> initialCategories;
  final int? selectedCategoryId;
  final ValueChanged<RiverSideCategoryOption?> onSelected;
  final bool allowSelectAll;
  final RiverSideCategoryLoader? onRefreshCategories;

  @override
  State<RiverSideCategoryPickerSheet> createState() =>
      _RiverSideCategoryPickerSheetState();
}

class _RiverSideCategoryPickerSheetState
    extends State<RiverSideCategoryPickerSheet> {
  late List<RiverSideCategoryOption> _categories;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _categories = List<RiverSideCategoryOption>.from(widget.initialCategories);
  }

  Future<void> _refresh() async {
    final loader = widget.onRefreshCategories;
    if (loader == null || _refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      final categories = await loader(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _categories = List<RiverSideCategoryOption>.from(categories);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('刷新板块失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = buildRiverSideCategoryGroups(_categories);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'board_picker_hero',
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.dashboard_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '选择板块',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.onRefreshCategories != null)
                      IconButton.filledTonal(
                        onPressed: _refreshing ? null : _refresh,
                        tooltip: '刷新板块',
                        icon: _refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (widget.allowSelectAll)
                  InkWell(
                    onTap: () => widget.onSelected(null),
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        boxShadow: [
                          if (widget.selectedCategoryId == null)
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
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
                          if (widget.selectedCategoryId == null)
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                if (widget.allowSelectAll) const SizedBox(height: 20),
                if (groups.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        '暂无可选板块',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BoardGroupCard(
                        group: group,
                        selectedId: widget.selectedCategoryId,
                        onSelected: (category) => widget.onSelected(category),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
                  showCheckmark: false,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.30),
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
