import 'package:flutter/material.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/network/riverside_topic_models.dart';

class RiverSideCategoryPickerSheet extends StatelessWidget {
  const RiverSideCategoryPickerSheet({
    super.key,
    required this.groups,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<RiverSideCategoryGroup> groups;
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

  final RiverSideCategoryGroup group;
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
