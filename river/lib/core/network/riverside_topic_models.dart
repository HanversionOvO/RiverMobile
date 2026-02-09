import 'package:river/core/constants.dart';

enum RiverSideTopicFeed { latestCreated, latestReplied, hot }

extension RiverSideTopicFeedExtension on RiverSideTopicFeed {
  String get label {
    switch (this) {
      case RiverSideTopicFeed.latestCreated:
        return '\u6700\u65b0\u53d1\u8868';
      case RiverSideTopicFeed.latestReplied:
        return '\u6700\u65b0\u56de\u590d';
      case RiverSideTopicFeed.hot:
        return '\u70ed\u95e8';
    }
  }

  Uri uri({int page = 0}) {
    switch (this) {
      case RiverSideTopicFeed.latestCreated:
        return Uri.parse(
          '$riverSideBaseUrl/latest.json?no_definitions=true&order=created&page=$page',
        );
      case RiverSideTopicFeed.latestReplied:
        return Uri.parse(
          '$riverSideBaseUrl/latest.json?no_definitions=true&page=$page',
        );
      case RiverSideTopicFeed.hot:
        return Uri.parse('$riverSideBaseUrl/hot.json?page=$page');
    }
  }
}

class RiverSideTopicSummary {
  const RiverSideTopicSummary({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.categoryId,
    required this.categoryName,
    required this.replyCount,
    required this.viewCount,
    required this.createdAt,
    required this.authorDisplayName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.isHot,
  });

  final int id;
  final String title;
  final String excerpt;
  final int? categoryId;
  final String categoryName;
  final int replyCount;
  final int viewCount;
  final DateTime? createdAt;
  final String authorDisplayName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool isHot;
}

class RiverSideCategoryOption {
  const RiverSideCategoryOption({
    required this.id,
    required this.name,
    required this.position,
    required this.parentCategoryId,
    required this.description,
  });

  final int id;
  final String name;
  final int position;
  final int? parentCategoryId;
  final String description;
}

class RiverSideTopicPage {
  const RiverSideTopicPage({
    required this.topics,
    required this.hasMore,
    required this.page,
  });

  final List<RiverSideTopicSummary> topics;
  final bool hasMore;
  final int page;
}
