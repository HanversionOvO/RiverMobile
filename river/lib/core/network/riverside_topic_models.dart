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
    required this.isPinned,
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
  final bool isPinned;
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

class RiverSideTopicPostDetail {
  const RiverSideTopicPostDetail({
    required this.id,
    required this.topicId,
    required this.postNumber,
    required this.authorUserId,
    required this.authorUsername,
    required this.authorDisplayName,
    required this.authorAvatarUrl,
    required this.authorTitle,
    required this.isOnline,
    required this.contentMarkdown,
    required this.createdAt,
    required this.editCount,
    required this.likeCount,
    this.reactions = const <RiverSidePostReaction>[],
    this.currentUserReaction,
    this.reactionUsersCount = 0,
  });

  final int id;
  final int topicId;
  final int postNumber;
  final int? authorUserId;
  final String authorUsername;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final String authorTitle;
  final bool? isOnline;
  final String contentMarkdown;
  final DateTime? createdAt;
  final int editCount;
  final int likeCount;
  final List<RiverSidePostReaction> reactions;
  final RiverSideCurrentUserReaction? currentUserReaction;
  final int reactionUsersCount;

  RiverSideTopicPostDetail copyWith({
    int? id,
    int? topicId,
    int? postNumber,
    int? authorUserId,
    bool clearAuthorUserId = false,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    String? authorTitle,
    bool? isOnline,
    String? contentMarkdown,
    DateTime? createdAt,
    int? editCount,
    int? likeCount,
    List<RiverSidePostReaction>? reactions,
    RiverSideCurrentUserReaction? currentUserReaction,
    bool clearCurrentUserReaction = false,
    int? reactionUsersCount,
  }) {
    return RiverSideTopicPostDetail(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      postNumber: postNumber ?? this.postNumber,
      authorUserId: clearAuthorUserId
          ? null
          : (authorUserId ?? this.authorUserId),
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorTitle: authorTitle ?? this.authorTitle,
      isOnline: isOnline ?? this.isOnline,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      createdAt: createdAt ?? this.createdAt,
      editCount: editCount ?? this.editCount,
      likeCount: likeCount ?? this.likeCount,
      reactions: reactions ?? this.reactions,
      currentUserReaction: clearCurrentUserReaction
          ? null
          : (currentUserReaction ?? this.currentUserReaction),
      reactionUsersCount: reactionUsersCount ?? this.reactionUsersCount,
    );
  }
}

class RiverSideTopicDetail {
  const RiverSideTopicDetail({
    required this.topicId,
    required this.title,
    required this.viewCount,
    required this.replyCount,
    required this.likeCount,
    required this.createdAt,
    required this.mainPost,
    required this.comments,
    required this.streamPostIds,
    required this.loadedPostIds,
    this.validReactions = const <String>{},
  });

  final int topicId;
  final String title;
  final int viewCount;
  final int replyCount;
  final int likeCount;
  final DateTime? createdAt;
  final RiverSideTopicPostDetail mainPost;
  final List<RiverSideTopicPostDetail> comments;
  final List<int> streamPostIds;
  final Set<int> loadedPostIds;
  final Set<String> validReactions;

  RiverSideTopicDetail copyWith({
    int? topicId,
    String? title,
    int? viewCount,
    int? replyCount,
    int? likeCount,
    DateTime? createdAt,
    RiverSideTopicPostDetail? mainPost,
    List<RiverSideTopicPostDetail>? comments,
    List<int>? streamPostIds,
    Set<int>? loadedPostIds,
    Set<String>? validReactions,
  }) {
    return RiverSideTopicDetail(
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      viewCount: viewCount ?? this.viewCount,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      mainPost: mainPost ?? this.mainPost,
      comments: comments ?? this.comments,
      streamPostIds: streamPostIds ?? this.streamPostIds,
      loadedPostIds: loadedPostIds ?? this.loadedPostIds,
      validReactions: validReactions ?? this.validReactions,
    );
  }
}

class RiverSidePostReaction {
  const RiverSidePostReaction({
    required this.id,
    required this.type,
    required this.count,
  });

  final String id;
  final String type;
  final int count;
}

class RiverSideCurrentUserReaction {
  const RiverSideCurrentUserReaction({
    required this.id,
    required this.type,
    required this.canUndo,
  });

  final String id;
  final String type;
  final bool canUndo;
}

class RiverSidePostReactionUsersGroup {
  const RiverSidePostReactionUsersGroup({
    required this.id,
    required this.count,
    required this.users,
  });

  final String id;
  final int count;
  final List<RiverSideReactionUser> users;
}

class RiverSideReactionUser {
  const RiverSideReactionUser({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.canUndo,
    required this.createdAt,
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final bool canUndo;
  final DateTime? createdAt;
}

class RiverSidePostReactionState {
  const RiverSidePostReactionState({
    required this.postId,
    required this.reactions,
    required this.currentUserReaction,
    required this.reactionUsersCount,
  });

  final int postId;
  final List<RiverSidePostReaction> reactions;
  final RiverSideCurrentUserReaction? currentUserReaction;
  final int reactionUsersCount;
}
