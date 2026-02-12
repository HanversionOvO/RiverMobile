import 'package:flutter/foundation.dart';

@immutable
class RiverSideNotificationItem {
  const RiverSideNotificationItem({
    required this.id,
    required this.type,
    required this.read,
    required this.highPriority,
    required this.createdAt,
    required this.topicId,
    required this.postNumber,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.username,
    required this.actionText,
    required this.badgeName,
    required this.count,
    required this.avatarUrl,
  });

  final int id;
  final int type;
  final bool read;
  final bool highPriority;
  final DateTime? createdAt;
  final int? topicId;
  final int? postNumber;
  final String slug;
  final String title;
  final String excerpt;
  final String username;
  final String actionText;
  final String badgeName;
  final int count;
  final String avatarUrl;
}

@immutable
class RiverSideNotificationPage {
  const RiverSideNotificationPage({
    required this.items,
    required this.totalRows,
    required this.seenNotificationId,
    required this.loadMorePath,
  });

  final List<RiverSideNotificationItem> items;
  final int? totalRows;
  final int? seenNotificationId;
  final String loadMorePath;

  bool get hasMore => loadMorePath.trim().isNotEmpty;
}

@immutable
class RiverSideChatChannelItem {
  const RiverSideChatChannelItem({
    required this.id,
    required this.name,
    required this.description,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.isDirectMessage,
    required this.avatarUrl,
    required this.canDeleteSelf,
  });

  final int id;
  final String name;
  final String description;
  final int unreadCount;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool isDirectMessage;
  final String avatarUrl;
  final bool canDeleteSelf;
}

@immutable
class RiverSideChatReactionUser {
  const RiverSideChatReactionUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final int? id;
  final String username;
  final String displayName;
  final String avatarUrl;
}

@immutable
class RiverSideChatMessageReaction {
  const RiverSideChatMessageReaction({
    required this.emoji,
    required this.count,
    required this.reacted,
    required this.users,
  });

  final String emoji;
  final int count;
  final bool reacted;
  final List<RiverSideChatReactionUser> users;
}

@immutable
class RiverSideChatMessageReplyRef {
  const RiverSideChatMessageReplyRef({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.excerpt,
    required this.cooked,
  });

  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String excerpt;
  final String cooked;
}

@immutable
class RiverSideChatMessageItem {
  const RiverSideChatMessageItem({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.raw,
    required this.cooked,
    required this.createdAt,
    required this.deleted,
    required this.uploadUrls,
    required this.inReplyTo,
    required this.reactions,
  });

  final int id;
  final int channelId;
  final int? userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String raw;
  final String cooked;
  final DateTime? createdAt;
  final bool deleted;
  final List<String> uploadUrls;
  final RiverSideChatMessageReplyRef? inReplyTo;
  final List<RiverSideChatMessageReaction> reactions;
}

@immutable
class RiverSideChatMessagePage {
  const RiverSideChatMessagePage({
    required this.messages,
    required this.canLoadMorePast,
    required this.canLoadMoreFuture,
  });

  final List<RiverSideChatMessageItem> messages;
  final bool canLoadMorePast;
  final bool canLoadMoreFuture;
}
