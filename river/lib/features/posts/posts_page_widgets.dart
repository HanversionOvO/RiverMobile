part of 'posts_page.dart';

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
  const _TopicCard({
    required this.topic,
    required this.showHotIcon,
    required this.onTap,
    required this.onAuthorTap,
  });

  final RiverSideTopicSummary topic;
  final bool showHotIcon;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onAuthorTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (topic.isPinned)
                    Icon(
                      Icons.push_pin_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  if (topic.isPinned && (showHotIcon || topic.isHot))
                    const SizedBox(width: 6),
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
