part of 'riverside_api_client.dart';

extension RiverSideApiClientChatParsingMethods on RiverSideApiClient {
  RiverSideChatChannelItem? _parseChatChannel(
    Map<String, dynamic> channel, {
    bool? directHint,
    int? currentUserId,
    String? currentUsername,
  }) {
    final nestedChannel = _toStringMap(channel['channel']);
    final source = nestedChannel.isEmpty ? channel : nestedChannel;
    final chatable = _toStringMap(source['chatable']);
    final meta = _toStringMap(source['meta']);
    final lastMessage = _toStringMap(source['last_message']);
    final chatableLastMessage = _toStringMap(chatable['last_message']);
    final metaLastMessage = _toStringMap(meta['last_message']);
    final membership = _toStringMap(source['membership']);
    final usersRaw =
        source['users'] ??
        source['members'] ??
        source['participants'] ??
        source['chatable_users'] ??
        source['direct_message_users'] ??
        chatable['users'];

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

    final resolvedCurrentUserId =
        currentUserId ??
        _asInt(source['current_user_id']) ??
        _asInt(source['acting_user_id']) ??
        _asInt(membership['user_id']) ??
        _asInt(_toStringMap(membership['user'])['id']);
    final resolvedCurrentUsername = (currentUsername ?? '')
        .trim()
        .toLowerCase();

    final users = <Map<String, dynamic>>[];
    if (usersRaw is List) {
      for (final rawUser in usersRaw) {
        final map = _toStringMap(rawUser);
        if (map.isNotEmpty) {
          users.add(map);
        }
      }
    }

    bool isCurrentUser(Map<String, dynamic> user) {
      final directUser = user;
      final nestedUser = _toStringMap(directUser['user']);
      final id =
          _asInt(directUser['id']) ??
          _asInt(directUser['user_id']) ??
          _asInt(nestedUser['id']);
      if (resolvedCurrentUserId != null &&
          id != null &&
          resolvedCurrentUserId == id) {
        return true;
      }

      final username = _firstNonEmpty(<dynamic>[
        directUser['username'],
        nestedUser['username'],
      ]).trim().toLowerCase();
      return resolvedCurrentUsername.isNotEmpty &&
          username.isNotEmpty &&
          resolvedCurrentUsername == username;
    }

    final peerUsers = isDirectMessage
        ? users.where((user) => !isCurrentUser(user)).toList(growable: false)
        : users;
    final displayUsers = peerUsers.isNotEmpty ? peerUsers : users;

    String buildUserDisplayName(Map<String, dynamic> user) {
      return _sanitizeExcerpt(
        _firstNonEmpty(<dynamic>[
          user['name'],
          user['display_name'],
          user['username'],
        ]),
      );
    }

    String buildNamesFromUsers(List<Map<String, dynamic>> users) {
      final names = <String>[];
      for (final user in users) {
        final name = buildUserDisplayName(user);
        if (name.isNotEmpty && !names.contains(name)) {
          names.add(name);
        }
      }
      if (names.isEmpty) {
        return '';
      }
      if (names.length <= 2) {
        return names.join('、');
      }
      return '${names.take(2).join('、')} 等${names.length}人';
    }

    bool isFallbackChannelName(String value) {
      final lower = value.trim().toLowerCase();
      if (lower.isEmpty) {
        return true;
      }
      if (lower == 'channel' || lower == 'direct message') {
        return true;
      }
      return RegExp(r'^(channel|频道|私信)\s*#?\d+$').hasMatch(lower);
    }

    var name = _firstNonEmpty(<dynamic>[
      source['title'],
      source['name'],
      source['display_name'],
      source['chat_channel_title'],
      source['chatable_title'],
      source['usernames'],
      chatable['title'],
      chatable['name'],
    ]);
    if (isDirectMessage) {
      final usersName = buildNamesFromUsers(displayUsers);
      if (usersName.isNotEmpty && isFallbackChannelName(name)) {
        name = usersName;
      }
    }
    if (name.trim().isEmpty || isFallbackChannelName(name)) {
      name = isDirectMessage ? '私信 #$id' : '频道 #$id';
    }

    final description = _firstNonEmpty(<dynamic>[
      source['description'],
      chatable['description'],
    ]);

    final lastMessageText = _firstNonEmpty(<dynamic>[
      lastMessage['excerpt'],
      lastMessage['message'],
      lastMessage['cooked'],
      chatableLastMessage['excerpt'],
      chatableLastMessage['message'],
      chatableLastMessage['cooked'],
      metaLastMessage['excerpt'],
      metaLastMessage['message'],
      metaLastMessage['cooked'],
      source['last_message_excerpt'],
      source['last_message'],
      source['last_message_text'],
      source['last_message_summary'],
      source['latest_message'],
      source['latest_post_excerpt'],
    ]);

    final avatarFromUsers = displayUsers.isEmpty
        ? ''
        : _firstNonEmpty(<dynamic>[
            displayUsers.first['avatar_template'],
            displayUsers.first['user_avatar_template'],
            _toStringMap(displayUsers.first['user'])['avatar_template'],
            _toStringMap(displayUsers.first['user'])['user_avatar_template'],
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
                lastMessage['updated_at'] ??
                chatableLastMessage['created_at'] ??
                chatableLastMessage['updated_at'] ??
                metaLastMessage['created_at'] ??
                metaLastMessage['updated_at'] ??
                source['last_message_sent_at'] ??
                source['updated_at'] ??
                '')
            .toString(),
      ),
      isDirectMessage: isDirectMessage,
      avatarUrl: _normalizeAvatarUrl(
        _firstNonEmpty(<dynamic>[
          source['avatar_template'],
          source['user_avatar_template'],
          chatable['avatar_template'],
          avatarFromUsers,
        ]),
      ),
      canDeleteSelf:
          _asBool(source['can_delete_self']) ||
          _asBool(meta['can_delete_self']),
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
    final preferredRaw = _firstNonEmpty(<dynamic>[
      message['message'],
      message['raw'],
      message['excerpt'],
    ]);
    final rawSeed = preferredRaw.trim().isNotEmpty
        ? preferredRaw
        : _cookHtmlToMarkdown(cooked);
    final raw = _resolveUploadMarkdown(
      rawMarkdown: rawSeed,
      cookedHtml: cooked,
      uploadsRaw: message['uploads'],
    );

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
      createdAt: DateTime.tryParse(
        _firstNonEmpty(<dynamic>[
          message['created_at'],
          message['createdAt'],
          message['sent_at'],
          message['updated_at'],
        ]),
      ),
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
      return value.substring(1, value.length - 1).trim();
    }
    return value;
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
