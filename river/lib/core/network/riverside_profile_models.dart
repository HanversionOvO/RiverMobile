import 'package:flutter/foundation.dart';
import 'package:river/core/account/account_models.dart';

enum RiverSideProfileActivityKind { all, topics, replies, likesGiven }

extension RiverSideProfileActivityKindExtension
    on RiverSideProfileActivityKind {
  String get label {
    switch (this) {
      case RiverSideProfileActivityKind.all:
        return '全部';
      case RiverSideProfileActivityKind.topics:
        return '主题';
      case RiverSideProfileActivityKind.replies:
        return '回复';
      case RiverSideProfileActivityKind.likesGiven:
        return '点赞';
    }
  }
}

@immutable
class RiverSideProfileOverview {
  const RiverSideProfileOverview({
    required this.account,
    required this.isProfileHidden,
    required this.bio,
    required this.location,
    required this.website,
    required this.createdAt,
    required this.lastSeenAt,
    required this.lastPostedAt,
    required this.trustLevel,
    required this.badgeCount,
    required this.profileViewCount,
    required this.topicCount,
    required this.postCount,
    required this.likesGiven,
    required this.likesReceived,
    required this.followersCount,
    required this.followingCount,
    this.isFollowing = false,
    this.canFollow = true,
    this.canSendPrivateMessage = true,
  });

  final UserAccount account;
  final bool isProfileHidden;
  final String bio;
  final String location;
  final String website;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? lastPostedAt;

  final int trustLevel;
  final int badgeCount;
  final int profileViewCount;
  final int topicCount;
  final int postCount;
  final int likesGiven;
  final int likesReceived;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool canFollow;
  final bool canSendPrivateMessage;
}

@immutable
class RiverSideProfileActivityItem {
  const RiverSideProfileActivityItem({
    required this.topicId,
    required this.postNumber,
    required this.title,
    required this.excerpt,
    required this.categoryName,
    required this.authorUsername,
    required this.authorDisplayName,
    required this.authorAvatarUrl,
    required this.replyCount,
    required this.viewCount,
    required this.createdAt,
    required this.actionType,
  });

  final int topicId;
  final int? postNumber;
  final String title;
  final String excerpt;
  final String categoryName;
  final String authorUsername;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final int replyCount;
  final int viewCount;
  final DateTime? createdAt;
  final int? actionType;
}

@immutable
class RiverSideProfileBadge {
  const RiverSideProfileBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.imageUrl,
    required this.grantCount,
    required this.badgeTypeName,
  });

  final int id;
  final String name;
  final String description;
  final String icon;
  final String imageUrl;
  final int grantCount;
  final String badgeTypeName;
}

@immutable
class RiverSideProfileFollowUser {
  const RiverSideProfileFollowUser({
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
