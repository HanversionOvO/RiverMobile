part of 'riverside_api_client.dart';

extension RiverSideApiClientChatParsingMethods on RiverSideApiClient {
  RiverSideChatChannelItem? _parseChatChannel(
    Map<String, dynamic> channel, {
    bool? directHint,
  }) {
    final nestedChannel = _toStringMap(channel['channel']);
    final source = nestedChannel.isEmpty ? channel : nestedChannel;
    final chatable = _toStringMap(source['chatable']);
    final lastMessage = _toStringMap(source['last_message']);
    final membership = _toStringMap(source['membership']);

    final id =
        _asInt(source['id']) ??
        _asInt(source['channel_id']) ??
        _asInt(source['chat_channel_id']);
    if (id == null || id <= 0) {
      return null;
    }

    final isDirectMessage =
        directHint ??
        _asBool(source['direct_message']) ||
            _asBool(source['is_direct_message']) ||
            _asBool(source['dm_channel']) ||
            _asBool(chatable['direct_message']) ||
            _firstNonEmpty(<dynamic>[
              source['chatable_type'],
              source['type'],
              chatable['type'],
            ]).toLowerCase().contains('direct');

    final name = _firstNonEmpty(<dynamic>[
      source['title'],
      source['name'],
      source['display_name'],
      chatable['title'],
      chatable['name'],
      'Channel #$id',
    ]);

    final description = _firstNonEmpty(<dynamic>[
      source['description'],
      chatable['description'],
    ]);

    final lastMessageText = _firstNonEmpty(<dynamic>[
      lastMessage['excerpt'],
      lastMessage['message'],
      source['last_message_excerpt'],
      source['last_message'],
    ]);

    final unreadCount =
        _asInt(source['unread_count']) ??
        _asInt(membership['unread_count']) ??
        _asInt(source['unread_mentions']) ??
        0;

    return RiverSideChatChannelItem(
      id: id,
      name: _sanitizeExcerpt(name),
      description: _sanitizeExcerpt(description),
      unreadCount: unreadCount,
      lastMessage: _sanitizeExcerpt(lastMessageText),
      lastMessageAt: DateTime.tryParse(
        (source['last_message_at'] ??
                lastMessage['created_at'] ??
                source['updated_at'] ??
                '')
            .toString(),
      ),
      isDirectMessage: isDirectMessage,
      avatarUrl: _normalizeAvatarUrl(
        _firstNonEmpty(<dynamic>[
          source['avatar_template'],
          chatable['avatar_template'],
        ]),
      ),
    );
  }

  RiverSideChatMessagePage _parseChatMessagePage(
    Map<String, dynamic> decoded, {
    required int channelId,
  }) {
    final usersById = _extractUsersById(decoded['users']);
    final chatView = _toStringMap(decoded['chat_view']);
    final meta = _toStringMap(decoded['meta']);
    final messagesRaw =
        decoded['messages'] ??
        decoded['chat_messages'] ??
        chatView['messages'] ??
        chatView['chat_messages'];

    final parsed = <RiverSideChatMessageItem>[];
    if (messagesRaw is List) {
      for (final raw in messagesRaw) {
        final source = _toStringMap(raw);
        final nested = _toStringMap(source['chat_message']);
        final item = _parseChatMessage(
          nested.isEmpty ? source : nested,
          channelId: channelId,
          usersById: usersById,
        );
        if (item == null) {
          continue;
        }
        parsed.add(item);
      }
    }

    parsed.sort((a, b) {
      final byTime = (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
        b.createdAt?.millisecondsSinceEpoch ?? 0,
      );
      if (byTime != 0) {
        return byTime;
      }
      return a.id.compareTo(b.id);
    });

    return RiverSideChatMessagePage(
      messages: parsed,
      canLoadMorePast:
          _asBool(decoded['can_load_more_past']) ||
          _asBool(chatView['can_load_more_past']) ||
          _asBool(meta['can_load_more_past']),
      canLoadMoreFuture:
          _asBool(decoded['can_load_more_future']) ||
          _asBool(chatView['can_load_more_future']) ||
          _asBool(meta['can_load_more_future']),
    );
  }

  RiverSideChatMessageItem? _parseChatMessage(
    Map<String, dynamic> message, {
    required int channelId,
    required Map<int, Map<String, dynamic>> usersById,
  }) {
    if (message.isEmpty) {
      return null;
    }

    final id =
        _asInt(message['id']) ??
        _asInt(message['message_id']) ??
        _asInt(message['chat_message_id']);
    if (id == null || id <= 0) {
      return null;
    }

    final userId =
        _asInt(message['user_id']) ??
        _asInt(_toStringMap(message['user'])['id']);
    final nestedUser = _toStringMap(message['user']);
    final userById = userId == null
        ? const <String, dynamic>{}
        : (usersById[userId] ?? const <String, dynamic>{});
    final username = _sanitizeExcerpt(
      _firstNonEmpty(<dynamic>[
        message['username'],
        nestedUser['username'],
        userById['username'],
      ]),
    );
    final displayName = _sanitizeExcerpt(
      _firstNonEmpty(<dynamic>[
        message['name'],
        message['display_username'],
        nestedUser['name'],
        nestedUser['display_name'],
        userById['name'],
        username,
      ]),
    );
    final avatarUrl = _normalizeAvatarUrl(
      _firstNonEmpty(<dynamic>[
        message['avatar_template'],
        nestedUser['avatar_template'],
        userById['avatar_template'],
      ]),
    );

    final cooked = (message['cooked'] ?? '').toString();
    final raw = _firstNonEmpty(<dynamic>[
      message['message'],
      message['raw'],
      message['excerpt'],
      _sanitizeExcerpt(cooked),
    ]);

    final uploadUrls = <String>[];
    final uploadsRaw = message['uploads'];
    if (uploadsRaw is List) {
      for (final rawUpload in uploadsRaw) {
        final upload = _toStringMap(rawUpload);
        final url = _normalizeUploadUrl(
          _firstNonEmpty(<dynamic>[upload['url'], upload['short_url']]),
        );
        if (url.isNotEmpty && !uploadUrls.contains(url)) {
          uploadUrls.add(url);
        }
      }
    }

    final normalizedChannelId =
        _asInt(message['chat_channel_id']) ??
        _asInt(message['channel_id']) ??
        channelId;
    final inReplyTo = _parseChatMessageReplyRef(message['in_reply_to']);
    final reactions = _parseChatMessageReactions(message['reactions']);

    return RiverSideChatMessageItem(
      id: id,
      channelId: normalizedChannelId,
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      raw: raw,
      cooked: cooked,
      createdAt: DateTime.tryParse((message['created_at'] ?? '').toString()),
      deleted: _asBool(message['deleted']) || message['deleted_at'] != null,
      uploadUrls: uploadUrls,
      inReplyTo: inReplyTo,
      reactions: reactions,
    );
  }

  RiverSideChatMessageReplyRef? _parseChatMessageReplyRef(dynamic rawReply) {
    final reply = _toStringMap(rawReply);
    if (reply.isEmpty) {
      return null;
    }
    final id = _asInt(reply['id']);
    if (id == null || id <= 0) {
      return null;
    }

    final nestedUser = _toStringMap(reply['user']);
    final username = _sanitizeExcerpt(
      (nestedUser['username'] ?? '').toString(),
    );
    final displayName = _sanitizeExcerpt(
      _firstNonEmpty(<dynamic>[
        nestedUser['name'],
        nestedUser['display_name'],
        username,
      ]),
    );
    final excerpt = _sanitizeExcerpt(
      _firstNonEmpty(<dynamic>[reply['excerpt'], reply['cooked']]),
    );

    return RiverSideChatMessageReplyRef(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: _normalizeAvatarUrl(
        (nestedUser['avatar_template'] ?? '').toString(),
      ),
      excerpt: excerpt,
      cooked: (reply['cooked'] ?? '').toString(),
    );
  }

  List<RiverSideChatMessageReaction> _parseChatMessageReactions(
    dynamic rawReactions,
  ) {
    if (rawReactions is! List) {
      return const <RiverSideChatMessageReaction>[];
    }

    final parsed = <RiverSideChatMessageReaction>[];
    for (final rawReaction in rawReactions) {
      final reaction = _toStringMap(rawReaction);
      final emoji = _sanitizeExcerpt((reaction['emoji'] ?? '').toString());
      if (emoji.isEmpty) {
        continue;
      }

      final users = <RiverSideChatReactionUser>[];
      final usersRaw = reaction['users'];
      if (usersRaw is List) {
        for (final rawUser in usersRaw) {
          final user = _toStringMap(rawUser);
          if (user.isEmpty) {
            continue;
          }
          final username = _sanitizeExcerpt(
            (user['username'] ?? '').toString(),
          );
          final displayName = _sanitizeExcerpt(
            _firstNonEmpty(<dynamic>[user['name'], username]),
          );
          users.add(
            RiverSideChatReactionUser(
              id: _asInt(user['id']),
              username: username,
              displayName: displayName,
              avatarUrl: _normalizeAvatarUrl(
                (user['avatar_template'] ?? '').toString(),
              ),
            ),
          );
        }
      }

      parsed.add(
        RiverSideChatMessageReaction(
          emoji: emoji,
          count: _asInt(reaction['count']) ?? users.length,
          reacted: _asBool(reaction['reacted']),
          users: users,
        ),
      );
    }

    parsed.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      return a.emoji.compareTo(b.emoji);
    });
    return parsed;
  }

  String _normalizeChatReactionEmoji(String emoji) {
    final value = emoji.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith(':') && value.endsWith(':') && value.length > 2) {
      return value;
    }
    return ':$value:';
  }

  String _firstNonEmpty(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final text = '$candidate'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }
}
