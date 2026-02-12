part of 'riverside_api_client.dart';

extension RiverSideApiClientChatMethods on RiverSideApiClient {
  Future<RiverSideChatChannelItem> createOrOpenDirectMessageChannel({
    required String targetUsername,
    required String cookieHeader,
  }) async {
    final cookie = cookieHeader.trim();
    final target = targetUsername.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (target.isEmpty) {
      throw const RiverSideApiException('Target username is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final endpoints = <Uri>[
      Uri.parse('$riverSideBaseUrl/chat/api/direct-message-channels.json'),
      Uri.parse('$riverSideBaseUrl/chat/api/direct-message-channels'),
    ];

    final requests = <Future<http.Response>>[];
    for (final uri in endpoints) {
      requests.add(
        http.post(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=UTF-8',
            'Cookie': cookie,
            'X-CSRF-Token': csrf,
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': riverSideBaseUrl,
            'Referer': riverSideBaseUrl,
          },
          body: jsonEncode(<String, dynamic>{
            'target_usernames': <String>[target],
          }),
        ),
      );
      requests.add(
        http.post(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': cookie,
            'X-CSRF-Token': csrf,
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': riverSideBaseUrl,
            'Referer': riverSideBaseUrl,
          },
          body: <String, String>{'target_usernames': target},
        ),
      );
    }

    RiverSideApiException? lastError;
    for (final request in requests) {
      final response = await request;
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to start direct message, HTTP ${response.statusCode}',
        );
        continue;
      }
      if (response.statusCode == 422 || response.statusCode == 400) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(
          message.isEmpty ? 'Unable to start private message.' : message,
        );
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw RiverSideApiException(
          'Failed to start direct message, HTTP ${response.statusCode}',
        );
      }

      final decodedAny = jsonDecode(utf8.decode(response.bodyBytes));
      final decoded = _toStringMap(decodedAny);
      final channelRaw = _toStringMap(decoded['channel']).isNotEmpty
          ? _toStringMap(decoded['channel'])
          : _toStringMap(decoded['chat_channel']).isNotEmpty
          ? _toStringMap(decoded['chat_channel'])
          : _toStringMap(decoded['direct_message_channel']).isNotEmpty
          ? _toStringMap(decoded['direct_message_channel'])
          : decoded;

      final parsed = RiverSideApiClientChatParsingMethods(
        this,
      )._parseChatChannel(channelRaw, directHint: true);
      if (parsed != null) {
        return parsed;
      }

      final channels = await fetchMyChatChannels(cookieHeader: cookie);
      final directChannels = channels.where((item) => item.isDirectMessage);
      for (final item in directChannels) {
        final name = item.name.toLowerCase();
        if (name == target.toLowerCase() ||
            name.contains(target.toLowerCase())) {
          return item;
        }
      }
      if (directChannels.isNotEmpty) {
        return directChannels.first;
      }
      throw const RiverSideApiException(
        'Direct message channel created but cannot be resolved.',
      );
    }

    throw lastError ??
        const RiverSideApiException('Unable to start private message.');
  }

  Future<List<RiverSideChatChannelItem>> fetchMyChatChannels({
    String? cookieHeader,
  }) async {
    final cookie = cookieHeader?.trim() ?? '';
    if (cookie.isEmpty) {
      return const <RiverSideChatChannelItem>[];
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/chat/api/me/channels'),
      headers: <String, String>{
        ..._buildJsonHeaders(cookieHeader: cookie),
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': riverSideBaseUrl,
      },
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load chat channels, HTTP ${response.statusCode}',
      );
    }

    final decodedAny = jsonDecode(utf8.decode(response.bodyBytes));
    final channelMaps = <Map<String, dynamic>>[];
    final directHints = <bool?>[];
    int? currentUserId;
    String currentUsername = '';

    String firstNonEmptyLocal(List<dynamic> candidates) {
      for (final candidate in candidates) {
        final text = '$candidate'.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
      return '';
    }

    void addChannels(dynamic raw, {bool? directHint}) {
      if (raw is List) {
        for (final item in raw) {
          final map = _toStringMap(item);
          if (map.isEmpty) {
            continue;
          }
          channelMaps.add(map);
          directHints.add(directHint);
        }
      }
    }

    if (decodedAny is List) {
      addChannels(decodedAny);
    } else if (decodedAny is Map) {
      final decoded = _toStringMap(decodedAny);
      final currentUser = _toStringMap(decoded['current_user']);
      final me = _toStringMap(decoded['me']);
      currentUserId =
          _asInt(currentUser['id']) ??
          _asInt(me['id']) ??
          _asInt(decoded['current_user_id']) ??
          _asInt(decoded['user_id']);
      currentUsername = firstNonEmptyLocal(<dynamic>[
        currentUser['username'],
        me['username'],
        decoded['current_username'],
      ]).trim();
      addChannels(decoded['channels']);
      addChannels(decoded['chat_channels']);
      addChannels(decoded['my_channels']);

      final channelList = _toStringMap(decoded['channel_list']);
      addChannels(channelList['channels']);

      addChannels(decoded['public_channels'], directHint: false);
      addChannels(decoded['direct_message_channels'], directHint: true);
    }

    final byId = <int, RiverSideChatChannelItem>{};
    for (var i = 0; i < channelMaps.length; i++) {
      final parsed = RiverSideApiClientChatParsingMethods(this)
          ._parseChatChannel(
            channelMaps[i],
            directHint: directHints[i],
            currentUserId: currentUserId,
            currentUsername: currentUsername,
          );
      if (parsed == null) {
        continue;
      }
      byId[parsed.id] = parsed;
    }

    final channels = byId.values.toList(growable: false)
      ..sort((a, b) {
        final ta = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    return channels;
  }

  Future<RiverSideChatMessagePage> fetchChatChannelMessages({
    required int channelId,
    required String cookieHeader,
    bool fetchFromLastRead = true,
    int pageSize = 50,
    int? targetMessageId,
    String? direction,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (channelId <= 0) {
      throw const RiverSideApiException('Invalid chat channel id.');
    }

    final params = <String, String>{};
    if (fetchFromLastRead && targetMessageId == null) {
      params['fetch_from_last_read'] = 'true';
    }
    if (pageSize > 0) {
      params['page_size'] = '$pageSize';
    }
    if (targetMessageId != null && targetMessageId > 0) {
      params['target_message_id'] = '$targetMessageId';
    }
    final directionValue = (direction ?? '').trim().toLowerCase();
    if (directionValue == 'past' || directionValue == 'future') {
      params['direction'] = directionValue;
    }

    final basePath = '/chat/api/channels/$channelId/messages';
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl$basePath').replace(queryParameters: params),
      Uri.parse(
        '$riverSideBaseUrl$basePath.json',
      ).replace(queryParameters: params),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.get(
        uri,
        headers: <String, String>{
          ..._buildJsonHeaders(cookieHeader: cookie),
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
      );

      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }

      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to load chat messages, HTTP ${response.statusCode}',
        );
        continue;
      }

      if (response.statusCode != 200) {
        throw RiverSideApiException(
          'Failed to load chat messages, HTTP ${response.statusCode}',
        );
      }

      final decoded = _decodeJsonObject(
        response,
        fallbackMessage: 'Invalid chat messages response format',
      );
      return RiverSideApiClientChatParsingMethods(
        this,
      )._parseChatMessagePage(decoded, channelId: channelId);
    }

    throw lastError ??
        const RiverSideApiException('Failed to load chat messages.');
  }

  Future<RiverSideChatMessageItem> sendChatChannelMessage({
    required int channelId,
    required String cookieHeader,
    required String message,
    int? inReplyToMessageId,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (channelId <= 0) {
      throw const RiverSideApiException('Invalid chat channel id.');
    }
    final text = message.trim();
    if (text.isEmpty) {
      throw const RiverSideApiException('Message is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final requestBody = <String, dynamic>{'message': text};
    if (inReplyToMessageId != null && inReplyToMessageId > 0) {
      requestBody['in_reply_to_id'] = inReplyToMessageId;
    }

    final responseCandidates = <Future<http.Response>>[
      http.post(
        Uri.parse('$riverSideBaseUrl/chat/api/channels/$channelId/messages'),
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
        body: jsonEncode(requestBody),
      ),
      http.post(
        Uri.parse('$riverSideBaseUrl/chat/$channelId.json'),
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
        body: <String, String>{
          'message': text,
          if (inReplyToMessageId != null && inReplyToMessageId > 0)
            'in_reply_to_id': '$inReplyToMessageId',
        },
      ),
    ];

    RiverSideApiException? lastError;
    for (final futureResponse in responseCandidates) {
      final response = await futureResponse;
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 404 ||
          response.statusCode == 405 ||
          response.statusCode == 415) {
        lastError = RiverSideApiException(
          'Failed to send message, HTTP ${response.statusCode}',
        );
        continue;
      }
      if (response.statusCode == 422) {
        final messageText = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(
          messageText.isEmpty ? 'Failed to send message.' : messageText,
        );
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw RiverSideApiException(
          'Failed to send message, HTTP ${response.statusCode}',
        );
      }

      final decodedAny = jsonDecode(utf8.decode(response.bodyBytes));
      final payload = _toStringMap(decodedAny);
      final messageRaw = _toStringMap(payload['chat_message']);
      final source = messageRaw.isNotEmpty
          ? messageRaw
          : _toStringMap(payload['message']).isNotEmpty
          ? _toStringMap(payload['message'])
          : payload;
      final parsed = _parseChatMessage(
        source,
        channelId: channelId,
        usersById: const <int, Map<String, dynamic>>{},
      );
      if (parsed != null) {
        return parsed;
      }

      final fallback = await fetchChatChannelMessages(
        channelId: channelId,
        cookieHeader: cookie,
        fetchFromLastRead: false,
        pageSize: 50,
      );
      if (fallback.messages.isNotEmpty) {
        return fallback.messages.last;
      }
      throw const RiverSideApiException(
        'Message sent but response is invalid.',
      );
    }

    throw lastError ?? const RiverSideApiException('Failed to send message.');
  }

  Future<void> deleteChatChannelMessage({
    required int channelId,
    required int messageId,
    required String cookieHeader,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (channelId <= 0 || messageId <= 0) {
      throw const RiverSideApiException('Invalid chat message id.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final candidates = <Uri>[
      Uri.parse(
        '$riverSideBaseUrl/chat/api/channels/$channelId/messages/$messageId',
      ),
      Uri.parse(
        '$riverSideBaseUrl/chat/api/channels/$channelId/messages/$messageId.json',
      ),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.delete(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
      );

      if (response.statusCode == 403) {
        final message = _extractErrorMessageFromResponse(response);
        if (message.toLowerCase().contains('login')) {
          throw const RiverSideApiException(
            'Login session expired. Please sign in again.',
          );
        }
        throw RiverSideApiException(
          message.isEmpty ? 'No permission to delete this message.' : message,
        );
      }

      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to delete message, HTTP ${response.statusCode}',
        );
        continue;
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(
          message.isEmpty
              ? 'Failed to delete message, HTTP ${response.statusCode}'
              : message,
        );
      }
      return;
    }

    throw lastError ?? const RiverSideApiException('Failed to delete message.');
  }

  Future<void> deleteDirectMessageChannel({
    required int channelId,
    required String cookieHeader,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (channelId <= 0) {
      throw const RiverSideApiException('Invalid chat channel id.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);

    Future<http.Response> sendDelete(Uri uri) {
      return http.delete(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
      );
    }

    Future<http.Response> sendPost(Uri uri) {
      return http.post(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
      );
    }

    RiverSideApiException? lastError;

    final postCandidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/chat/api/channels/$channelId/leave'),
      Uri.parse('$riverSideBaseUrl/chat/api/channels/$channelId/leave.json'),
    ];
    for (final uri in postCandidates) {
      final response = await sendPost(uri);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      if (response.statusCode == 403) {
        final message = _extractErrorMessageFromResponse(response);
        if (message.toLowerCase().contains('login')) {
          throw const RiverSideApiException(
            'Login session expired. Please sign in again.',
          );
        }
        throw RiverSideApiException(
          message.isEmpty
              ? 'No permission to delete this direct message.'
              : message,
        );
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to delete direct message, HTTP ${response.statusCode}',
        );
        continue;
      }
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to delete direct message, HTTP ${response.statusCode}'
            : message,
      );
    }

    final deleteCandidates = <Uri>[
      Uri.parse(
        '$riverSideBaseUrl/chat/api/channels/$channelId/memberships/me',
      ),
      Uri.parse(
        '$riverSideBaseUrl/chat/api/channels/$channelId/memberships/me.json',
      ),
      Uri.parse('$riverSideBaseUrl/chat/api/channels/$channelId'),
      Uri.parse('$riverSideBaseUrl/chat/api/channels/$channelId.json'),
    ];
    for (final uri in deleteCandidates) {
      final response = await sendDelete(uri);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      if (response.statusCode == 403) {
        final message = _extractErrorMessageFromResponse(response);
        if (message.toLowerCase().contains('login')) {
          throw const RiverSideApiException(
            'Login session expired. Please sign in again.',
          );
        }
        throw RiverSideApiException(
          message.isEmpty
              ? 'No permission to delete this direct message.'
              : message,
        );
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to delete direct message, HTTP ${response.statusCode}',
        );
        continue;
      }
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to delete direct message, HTTP ${response.statusCode}'
            : message,
      );
    }

    throw lastError ??
        const RiverSideApiException('Failed to delete direct message.');
  }

  Future<void> reactToChatChannelMessage({
    required int channelId,
    required int messageId,
    required String cookieHeader,
    required String emoji,
    required String reactAction,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (channelId <= 0 || messageId <= 0) {
      throw const RiverSideApiException('Invalid chat message id.');
    }
    final action = reactAction.trim().toLowerCase();
    if (action != 'add' && action != 'remove') {
      throw const RiverSideApiException('Invalid reaction action.');
    }
    final normalizedEmoji = RiverSideApiClientChatParsingMethods(
      this,
    )._normalizeChatReactionEmoji(emoji);
    if (normalizedEmoji.isEmpty) {
      throw const RiverSideApiException('Emoji is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/chat/$channelId/react/$messageId.json'),
      Uri.parse('$riverSideBaseUrl/chat/$channelId/react/$messageId'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.put(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Cookie': cookie,
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': riverSideBaseUrl,
          'Referer': '$riverSideBaseUrl/chat/channel/$channelId',
        },
        body: <String, String>{
          'emoji': normalizedEmoji,
          'react_action': action,
        },
      );

      if (response.statusCode == 403) {
        final message = _extractErrorMessageFromResponse(response);
        if (message.toLowerCase().contains('login')) {
          throw const RiverSideApiException(
            'Login session expired. Please sign in again.',
          );
        }
        throw RiverSideApiException(
          message.isEmpty ? 'No permission to react to this message.' : message,
        );
      }

      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Failed to react, HTTP ${response.statusCode}',
        );
        continue;
      }

      if (response.statusCode != 200) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(
          message.isEmpty
              ? 'Failed to react, HTTP ${response.statusCode}'
              : message,
        );
      }
      return;
    }

    throw lastError ?? const RiverSideApiException('Failed to react.');
  }
}
