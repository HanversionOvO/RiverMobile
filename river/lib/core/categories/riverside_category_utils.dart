import 'package:river/core/network/riverside_topic_models.dart';

class RiverSideCategoryGroup {
  const RiverSideCategoryGroup({required this.parent, required this.children});

  final RiverSideCategoryOption parent;
  final List<RiverSideCategoryOption> children;
}

String displayRiverSideCategoryName({
  required RiverSideCategoryOption category,
  required List<RiverSideCategoryOption> allCategories,
}) {
  final parentId = category.parentCategoryId;
  if (parentId == null) {
    return category.name;
  }

  for (final item in allCategories) {
    if (item.id == parentId) {
      return '${item.name} / ${category.name}';
    }
  }
  return category.name;
}

List<RiverSideCategoryGroup> buildRiverSideCategoryGroups(
  List<RiverSideCategoryOption> categories,
) {
  final byId = <int, RiverSideCategoryOption>{
    for (final item in categories) item.id: item,
  };

  final childrenByParent = <int, List<RiverSideCategoryOption>>{};
  for (final item in categories) {
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

  final groups = <RiverSideCategoryGroup>[];
  final handledParentIds = <int>{};

  for (final item in categories) {
    if (item.parentCategoryId != null || handledParentIds.contains(item.id)) {
      continue;
    }
    handledParentIds.add(item.id);
    groups.add(
      RiverSideCategoryGroup(
        parent: item,
        children:
            childrenByParent[item.id] ?? const <RiverSideCategoryOption>[],
      ),
    );
  }

  for (final item in categories) {
    if (item.parentCategoryId != null &&
        byId.containsKey(item.parentCategoryId)) {
      continue;
    }
    if (handledParentIds.contains(item.id)) {
      continue;
    }
    handledParentIds.add(item.id);
    groups.add(
      RiverSideCategoryGroup(
        parent: item,
        children: const <RiverSideCategoryOption>[],
      ),
    );
  }

  return groups;
}

RiverSideCategoryOption? findRiverSideCategoryById({
  required int? id,
  required List<RiverSideCategoryOption> categories,
}) {
  if (id == null) {
    return null;
  }
  for (final item in categories) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}
