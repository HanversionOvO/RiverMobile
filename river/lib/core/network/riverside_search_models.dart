import 'package:flutter/foundation.dart';

@immutable
class RiverSidePostSearchPage {
  const RiverSidePostSearchPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<RiverSidePostSearchItem> items;
  final int page;
  final bool hasMore;
}

@immutable
class RiverSidePostSearchItem {
  const RiverSidePostSearchItem({
    required this.topicId,
    required this.title,
    required this.excerpt,
    required this.authorUsername,
    required this.authorDisplayName,
    required this.authorAvatarUrl,
    required this.categoryName,
    required this.replyCount,
    required this.viewCount,
    required this.createdAt,
  });

  final int topicId;
  final String title;
  final String excerpt;
  final String authorUsername;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final String categoryName;
  final int replyCount;
  final int viewCount;
  final DateTime? createdAt;
}

@immutable
class RiverSideUserSearchItem {
  const RiverSideUserSearchItem({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
}

@immutable
class RiverSideCategorySearchItem {
  const RiverSideCategorySearchItem({
    required this.id,
    required this.name,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
}
