part of 'riverside_api_client.dart';

extension RiverSideApiClientProfileMethods on RiverSideApiClient {
  Future<UserAccount> fetchUserProfile(
    String username, {
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final uri = Uri.parse('$riverSideBaseUrl/u/$username.json');
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'API returned 403. Please make sure RiverSide login session is valid.',
      );
    }

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch profile, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid profile response format',
    );

    final userRaw = decoded['user'];
    final user = _toStringMap(userRaw);
    if (user.isEmpty) {
      throw const RiverSideApiException('User payload is missing');
    }

    final usernameFromApi = (user['username'] ?? username).toString().trim();
    if (usernameFromApi.isEmpty) {
      throw const RiverSideApiException('Username is missing in response');
    }

    final name = (user['name'] ?? '').toString().trim();
    final displayName = name.isEmpty ? usernameFromApi : name;
    final avatarTemplate = (user['avatar_template'] ?? '').toString();
    final title = (user['title'] ?? '').toString();

    return UserAccount(
      provider: AccountProvider.riverSide,
      userId: _asInt(user['id']),
      username: usernameFromApi,
      displayName: displayName,
      avatarUrl: _normalizeAvatarUrl(avatarTemplate),
      title: title,
    );
  }

  Future<UserAccount> fetchCurrentUserByUserApiKey({
    required String userApiKey,
    required String userApiClientId,
  }) async {
    final response = await http.get(
      Uri.parse(riverSideSessionCurrentUrl),
      headers: _buildJsonHeaders(
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch current session, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid current session response format',
    );
    final currentUser = _toStringMap(decoded['current_user']);
    final username = (currentUser['username'] ?? '').toString().trim();
    if (username.isEmpty) {
      throw const RiverSideApiException('Current user was not returned.');
    }

    try {
      return await fetchUserProfile(
        username,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      );
    } catch (_) {
      final name = (currentUser['name'] ?? '').toString().trim();
      final avatarTemplate = (currentUser['avatar_template'] ?? '').toString();
      final title = (currentUser['title'] ?? '').toString().trim();
      return UserAccount(
        provider: AccountProvider.riverSide,
        userId: _asInt(currentUser['id']),
        username: username,
        displayName: name.isEmpty ? username : name,
        avatarUrl: _normalizeAvatarUrl(avatarTemplate),
        title: title,
      );
    }
  }

  Future<UserAccount> fetchCurrentUserByCookie({
    required String cookieHeader,
    String? fallbackLogin,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final response = await http.get(
      Uri.parse(riverSideSessionCurrentUrl),
      headers: _buildJsonHeaders(cookieHeader: cookie),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch current session, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid current session response format',
    );
    final currentUser = _toStringMap(decoded['current_user']);
    var username = (currentUser['username'] ?? '').toString().trim();
    if (username.isEmpty && fallbackLogin != null) {
      username = fallbackLogin.trim();
    }
    if (username.isEmpty) {
      throw const RiverSideApiException('Current user was not returned.');
    }

    try {
      return await fetchUserProfile(username, cookieHeader: cookie);
    } catch (_) {
      final name = (currentUser['name'] ?? '').toString().trim();
      final avatarTemplate = (currentUser['avatar_template'] ?? '').toString();
      final title = (currentUser['title'] ?? '').toString().trim();
      return UserAccount(
        provider: AccountProvider.riverSide,
        userId: _asInt(currentUser['id']),
        username: username,
        displayName: name.isEmpty ? username : name,
        avatarUrl: _normalizeAvatarUrl(avatarTemplate),
        title: title,
      );
    }
  }

  String normalizeAvatarUrl(String template) {
    return _normalizeAvatarUrl(template);
  }

  Future<RiverSideProfileOverview> fetchProfileOverview(
    String username, {
    String? cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }

    final uri = Uri.parse(
      '$riverSideBaseUrl/u/${Uri.encodeComponent(resolvedUsername)}.json',
    );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch profile details, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid profile detail response format',
    );
    final user = _toStringMap(decoded['user']);
    if (user.isEmpty) {
      throw const RiverSideApiException('User payload is missing.');
    }

    final profile = _toStringMap(user['user_profile']);
    final userSummary = _toStringMap(decoded['user_summary']);
    final userStat = _toStringMap(user['user_stat']);
    final usernameFromApi = (user['username'] ?? resolvedUsername)
        .toString()
        .trim();
    final name = (user['name'] ?? '').toString().trim();
    final displayName = name.isEmpty ? usernameFromApi : name;
    final avatarTemplate = (user['avatar_template'] ?? '').toString();
    final title = (user['title'] ?? '').toString().trim();
    bool readOptionalBool(List<String> keys, {required bool fallback}) {
      for (final key in keys) {
        if (user.containsKey(key)) {
          return _asBool(user[key]);
        }
      }
      return fallback;
    }

    final account = UserAccount(
      provider: AccountProvider.riverSide,
      userId: _asInt(user['id']),
      username: usernameFromApi,
      displayName: displayName.isEmpty ? usernameFromApi : displayName,
      avatarUrl: _normalizeAvatarUrl(avatarTemplate),
      title: title,
    );

    int readStat(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final fromSummary = _asInt(userSummary[key]);
        if (fromSummary != null) return fromSummary;
        final fromUserStat = _asInt(userStat[key]);
        if (fromUserStat != null) return fromUserStat;
        final fromUser = _asInt(user[key]);
        if (fromUser != null) return fromUser;
      }
      return fallback;
    }

    return RiverSideProfileOverview(
      account: account,
      isProfileHidden: _asBool(user['profile_hidden']),
      bio: (profile['bio_raw'] ?? user['bio_raw'] ?? '').toString().trim(),
      location: (profile['location'] ?? '').toString().trim(),
      website: (profile['website'] ?? '').toString().trim(),
      createdAt: DateTime.tryParse((user['created_at'] ?? '').toString()),
      lastSeenAt: DateTime.tryParse((user['last_seen_at'] ?? '').toString()),
      lastPostedAt: DateTime.tryParse(
        (user['last_posted_at'] ?? '').toString(),
      ),
      trustLevel: _asInt(user['trust_level']) ?? 0,
      badgeCount: _asInt(user['badge_count']) ?? 0,
      profileViewCount: _asInt(user['profile_view_count']) ?? 0,
      topicCount: readStat(const <String>['topic_count']),
      postCount: readStat(const <String>['post_count', 'posts_count']),
      likesGiven: readStat(const <String>['likes_given', 'num_likes_given']),
      likesReceived: readStat(const <String>[
        'likes_received',
        'num_likes_received',
      ]),
      followersCount: _asInt(user['total_followers']) ?? 0,
      followingCount: _asInt(user['total_following']) ?? 0,
      isFollowing: readOptionalBool(const <String>[
        'is_following',
        'following',
        'followed',
        'is_followed',
      ], fallback: false),
      canFollow: readOptionalBool(const <String>[
        'can_follow_user',
        'can_follow',
        'can_following',
      ], fallback: true),
      canSendPrivateMessage: readOptionalBool(const <String>[
        'can_send_private_message_to_user',
        'can_send_private_messages',
      ], fallback: true),
    );
  }

  Future<bool> isFollowingUser({
    required String currentUsername,
    required String targetUsername,
    required String cookieHeader,
  }) async {
    final actor = currentUsername.trim();
    final target = targetUsername.trim();
    if (actor.isEmpty || target.isEmpty) {
      return false;
    }
    if (actor.toLowerCase() == target.toLowerCase()) {
      return false;
    }

    final following = await fetchProfileFollowUsers(
      actor,
      followers: false,
      cookieHeader: cookieHeader,
    );
    return following.any(
      (item) => item.username.toLowerCase() == target.toLowerCase(),
    );
  }

  Future<void> setFollowState({
    required String targetUsername,
    required bool follow,
    required String cookieHeader,
  }) async {
    final target = targetUsername.trim();
    final cookie = cookieHeader.trim();
    if (target.isEmpty) {
      throw const RiverSideApiException('Target username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(target);
    final endpointCandidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/follow/$encoded.json'),
      Uri.parse('$riverSideBaseUrl/follow/$encoded'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/follow'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/follow.json'),
    ];

    final requestCandidates = <Future<http.Response>>[];
    if (follow) {
      for (final uri in endpointCandidates) {
        requestCandidates.add(
          http.put(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Cookie': cookie,
              'X-CSRF-Token': csrf,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': riverSideBaseUrl,
              'Referer': '$riverSideBaseUrl/u/$encoded',
            },
            body: const <String, String>{},
          ),
        );
        requestCandidates.add(
          http.post(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Cookie': cookie,
              'X-CSRF-Token': csrf,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': riverSideBaseUrl,
              'Referer': '$riverSideBaseUrl/u/$encoded',
            },
            body: const <String, String>{'follow': 'true'},
          ),
        );
      }
    } else {
      for (final uri in endpointCandidates) {
        requestCandidates.add(
          http.delete(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Cookie': cookie,
              'X-CSRF-Token': csrf,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': riverSideBaseUrl,
              'Referer': '$riverSideBaseUrl/u/$encoded',
            },
          ),
        );
        requestCandidates.add(
          http.post(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Cookie': cookie,
              'X-CSRF-Token': csrf,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': riverSideBaseUrl,
              'Referer': '$riverSideBaseUrl/u/$encoded',
            },
            body: const <String, String>{'unfollow': 'true'},
          ),
        );
      }
    }

    RiverSideApiException? lastError;
    for (final request in requestCandidates) {
      final response = await request;
      if (response.statusCode == 403) {
        final message = _extractErrorMessageFromResponse(response).trim();
        if (message.toLowerCase().contains('login')) {
          throw const RiverSideApiException(
            'Login session expired. Please sign in again.',
          );
        }
        throw RiverSideApiException(
          message.isEmpty ? 'No permission.' : message,
        );
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        lastError = RiverSideApiException(
          'Follow action endpoint not available, HTTP ${response.statusCode}',
        );
        continue;
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response).trim();
        throw RiverSideApiException(
          message.isEmpty ? (follow ? '关注失败。' : '取消关注失败。') : message,
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      final message = _extractErrorMessageFromResponse(response).trim();
      lastError = RiverSideApiException(
        message.isEmpty
            ? 'Follow action failed, HTTP ${response.statusCode}'
            : message,
      );
    }

    throw lastError ??
        RiverSideApiException(follow ? '关注失败，请稍后重试。' : '取消关注失败，请稍后重试。');
  }

  Future<List<RiverSideProfileActivityItem>> fetchProfileActivities(
    String username, {
    required RiverSideProfileActivityKind kind,
    String? cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }

    final encoded = Uri.encodeComponent(resolvedUsername);
    final cacheKey = _categoryCacheKey(cookieHeader: cookieHeader);
    var fallbackCategoryNames =
        _categoryNameCacheByCookieKey[cacheKey] ?? const <int, String>{};
    if (fallbackCategoryNames.isEmpty) {
      try {
        await fetchCategories(cookieHeader: cookieHeader);
        fallbackCategoryNames =
            _categoryNameCacheByCookieKey[cacheKey] ?? const <int, String>{};
      } catch (_) {
        // Ignore category warm-up failures and keep parsing resilient.
      }
    }

    final userActionsUri = _buildUserActionsUri(
      username: resolvedUsername,
      kind: kind,
    );
    final uriCandidates = <Uri>[
      if (kind == RiverSideProfileActivityKind.all) userActionsUri,
      ...switch (kind) {
        RiverSideProfileActivityKind.all => <Uri>[
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity.json'),
        ],
        RiverSideProfileActivityKind.topics => <Uri>[
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity/topics.json'),
        ],
        RiverSideProfileActivityKind.replies => <Uri>[
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity/replies.json'),
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity/replies'),
        ],
        RiverSideProfileActivityKind.likesGiven => <Uri>[
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity/likes-given.json'),
          Uri.parse('$riverSideBaseUrl/u/$encoded/activity/likes-given'),
        ],
      },
      if (kind != RiverSideProfileActivityKind.all) userActionsUri,
    ];

    RiverSideApiException? lastError;
    var hasForbidden = false;
    var hasSuccessfulResponse = false;

    for (final uri in uriCandidates) {
      final response = await http.get(
        uri,
        headers: _buildJsonHeaders(cookieHeader: cookieHeader),
      );
      if (response.statusCode == 404) {
        // Hidden profiles may not expose activity endpoints.
        continue;
      }
      if (response.statusCode == 403) {
        hasForbidden = true;
        continue;
      }
      if (response.statusCode != 200) {
        lastError = RiverSideApiException(
          'Failed to fetch profile activity, HTTP ${response.statusCode}',
        );
        continue;
      }

      hasSuccessfulResponse = true;
      final decoded = _parseJsonDynamic(response.bodyBytes);
      final parsed = _parseProfileActivities(
        decoded,
        fallbackCategoryNames: fallbackCategoryNames,
      );
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    if (hasForbidden) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (hasSuccessfulResponse || lastError == null) {
      return const <RiverSideProfileActivityItem>[];
    }
    throw lastError;
  }

  List<RiverSideProfileActivityItem> _parseProfileActivities(
    dynamic decoded, {
    Map<int, String> fallbackCategoryNames = const <int, String>{},
  }) {
    final payload = _normalizeProfileActivityPayload(decoded);
    if (payload.isEmpty) {
      return const <RiverSideProfileActivityItem>[];
    }

    final usersById = _extractUsersById(
      payload['users'] ?? _toStringMap(payload['topic_list'])['users'],
    );
    final categoriesById = <int, String>{
      ...fallbackCategoryNames,
      ..._extractProfileCategoryNames(payload),
    };

    final fromTopics = _parseProfileActivitiesFromTopicList(
      payload,
      usersById: usersById,
      categoriesById: categoriesById,
    );
    final fromActions = _parseProfileActivitiesFromUserActions(
      payload,
      usersById: usersById,
      categoriesById: categoriesById,
    );

    final merged = <RiverSideProfileActivityItem>[
      ...fromTopics,
      ...fromActions,
    ];
    if (merged.isEmpty) {
      return merged;
    }

    final deduped = <String, RiverSideProfileActivityItem>{};
    for (final item in merged) {
      final key =
          '${item.topicId}-${item.postNumber ?? 0}-${item.actionType ?? 0}';
      deduped.putIfAbsent(key, () => item);
    }

    final result = deduped.values.toList(growable: false);
    result.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) {
        return b.topicId.compareTo(a.topicId);
      }
      if (at == null) {
        return 1;
      }
      if (bt == null) {
        return -1;
      }
      return bt.compareTo(at);
    });
    return result;
  }

  Uri _buildUserActionsUri({
    required String username,
    required RiverSideProfileActivityKind kind,
  }) {
    final query = <String, String>{'username': username, 'offset': '0'};
    final filter = switch (kind) {
      RiverSideProfileActivityKind.all => '4,5',
      RiverSideProfileActivityKind.topics => '4',
      RiverSideProfileActivityKind.replies => '5',
      RiverSideProfileActivityKind.likesGiven => '1',
    };
    query['filter'] = filter;
    return Uri.parse(
      '$riverSideBaseUrl/user_actions.json',
    ).replace(queryParameters: query);
  }

  dynamic _parseJsonDynamic(List<int> bytes) {
    final body = utf8.decode(bytes);
    return jsonDecode(body);
  }

  Map<String, dynamic> _normalizeProfileActivityPayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    if (decoded is List) {
      if (decoded.isEmpty) {
        return const <String, dynamic>{};
      }
      return <String, dynamic>{'user_actions': decoded};
    }
    return const <String, dynamic>{};
  }

  List<RiverSideProfileActivityItem> _parseProfileActivitiesFromTopicList(
    Map<String, dynamic> decoded, {
    required Map<int, Map<String, dynamic>> usersById,
    required Map<int, String> categoriesById,
  }) {
    final topicList = _toStringMap(decoded['topic_list']);
    final topicsRaw = topicList['topics'] ?? decoded['topics'];
    if (topicsRaw is! List) {
      return const <RiverSideProfileActivityItem>[];
    }

    final items = <RiverSideProfileActivityItem>[];
    for (final rawTopic in topicsRaw) {
      final topic = _toStringMap(rawTopic);
      final topicId = _asInt(topic['id']) ?? _asInt(topic['topic_id']);
      if (topicId == null || topicId <= 0) {
        continue;
      }

      final title = _sanitizeExcerpt(
        _firstNonEmptyProfile(<dynamic>[
          topic['title'],
          topic['fancy_title'],
          topic['topic_title'],
        ]),
      );
      final excerpt = _sanitizeExcerpt((topic['excerpt'] ?? '').toString());
      final categoryId = _asInt(topic['category_id']);
      final categoryName = categoryId == null
          ? '未分类'
          : (categoriesById[categoryId] ?? '分类 #$categoryId');
      final userId = _findPrimaryPosterUserId(
        topic['posters'] ?? topic['poster_users'],
      );
      final user = userId == null
          ? const <String, dynamic>{}
          : usersById[userId];

      final username =
          (topic['last_poster_username'] ??
                  topic['username'] ??
                  user?['username'] ??
                  '')
              .toString()
              .trim();
      final displayName =
          (topic['last_poster_name'] ??
                  topic['name'] ??
                  user?['name'] ??
                  user?['username'] ??
                  '')
              .toString()
              .trim();

      items.add(
        RiverSideProfileActivityItem(
          topicId: topicId,
          postNumber: null,
          title: title.isEmpty ? '帖子 #$topicId' : title,
          excerpt: excerpt,
          categoryName: categoryName,
          authorUsername: username,
          authorDisplayName: displayName.isEmpty
              ? (username.isEmpty ? 'Unknown user' : username)
              : displayName,
          authorAvatarUrl: _normalizeAvatarUrl(
            (topic['avatar_template'] ?? user?['avatar_template'] ?? '')
                .toString(),
          ),
          replyCount:
              _asInt(topic['reply_count']) ??
              ((_asInt(topic['posts_count']) ?? 1) - 1).clamp(0, 1 << 30),
          viewCount: _asInt(topic['views']) ?? 0,
          createdAt: DateTime.tryParse(
            (topic['bumped_at'] ??
                    topic['last_posted_at'] ??
                    topic['created_at'] ??
                    '')
                .toString(),
          ),
          actionType: null,
        ),
      );
    }
    return items;
  }

  List<RiverSideProfileActivityItem> _parseProfileActivitiesFromUserActions(
    Map<String, dynamic> decoded, {
    required Map<int, Map<String, dynamic>> usersById,
    required Map<int, String> categoriesById,
  }) {
    final actionsRaw = decoded['user_actions'];
    if (actionsRaw is! List) {
      return const <RiverSideProfileActivityItem>[];
    }

    final items = <RiverSideProfileActivityItem>[];
    for (final rawAction in actionsRaw) {
      final action = _toStringMap(rawAction);
      final topicId =
          _asInt(action['topic_id']) ??
          _asInt(action['target_topic_id']) ??
          _asInt(action['id']);
      if (topicId == null || topicId <= 0) {
        continue;
      }

      final actionType = _asInt(action['action_type']);
      final categoryId = _asInt(action['category_id']);
      final userId =
          _asInt(action['user_id']) ?? _asInt(action['acting_user_id']);
      final user = userId == null
          ? const <String, dynamic>{}
          : usersById[userId];

      final username =
          (action['username'] ??
                  action['acting_username'] ??
                  user?['username'] ??
                  '')
              .toString()
              .trim();
      final displayName =
          (action['name'] ??
                  action['acting_name'] ??
                  user?['name'] ??
                  user?['username'] ??
                  '')
              .toString()
              .trim();
      final title = _sanitizeExcerpt(
        _firstNonEmptyProfile(<dynamic>[
          action['title'],
          action['topic_title'],
          action['target_topic_title'],
        ]),
      );
      final excerpt = _sanitizeExcerpt(
        (action['excerpt'] ?? action['raw'] ?? action['cooked'] ?? '')
            .toString(),
      );
      final categoryName = (action['category_name'] ?? '').toString().trim();
      final resolvedCategory = categoryName.isEmpty
          ? (categoryId == null
                ? '未分类'
                : (categoriesById[categoryId] ?? '分类 #$categoryId'))
          : categoryName;

      items.add(
        RiverSideProfileActivityItem(
          topicId: topicId,
          postNumber: _asInt(action['post_number']),
          title: title.isEmpty ? '帖子 #$topicId' : title,
          excerpt: excerpt,
          categoryName: resolvedCategory,
          authorUsername: username,
          authorDisplayName: displayName.isEmpty
              ? (username.isEmpty ? 'Unknown user' : username)
              : displayName,
          authorAvatarUrl: _normalizeAvatarUrl(
            (action['avatar_template'] ??
                    action['acting_avatar_template'] ??
                    user?['avatar_template'] ??
                    '')
                .toString(),
          ),
          replyCount: _asInt(action['reply_count']) ?? 0,
          viewCount: _asInt(action['view_count']) ?? 0,
          createdAt: DateTime.tryParse(
            (action['created_at'] ?? action['updated_at'] ?? '').toString(),
          ),
          actionType: actionType,
        ),
      );
    }
    return items;
  }

  Map<int, String> _extractProfileCategoryNames(Map<String, dynamic> decoded) {
    final categoriesRaw =
        _toStringMap(decoded['topic_list'])['categories'] ??
        decoded['categories'];
    if (categoriesRaw is! List) {
      return const <int, String>{};
    }

    final byId = <int, Map<String, dynamic>>{};
    for (final raw in categoriesRaw) {
      final category = _toStringMap(raw);
      final id = _asInt(category['id']);
      if (id == null) {
        continue;
      }
      byId[id] = category;
    }

    final names = <int, String>{};
    for (final entry in byId.entries) {
      final id = entry.key;
      final category = entry.value;
      final name = (category['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }
      final parentId = _asInt(category['parent_category_id']);
      if (parentId == null || !byId.containsKey(parentId)) {
        names[id] = name;
        continue;
      }
      final parentName = (byId[parentId]!['name'] ?? '').toString().trim();
      names[id] = parentName.isEmpty ? name : '$parentName / $name';
    }
    return names;
  }

  String _firstNonEmptyProfile(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final text = '$candidate'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  Future<List<RiverSideProfileBadge>> fetchProfileBadges(
    String username, {
    String? cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    final uri = Uri.parse(
      '$riverSideBaseUrl/u/${Uri.encodeComponent(resolvedUsername)}/badges.json',
    );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 404) {
      return const <RiverSideProfileBadge>[];
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch badges, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid badges response format',
    );
    final typeNameById = <int, String>{};
    final badgeTypesRaw = decoded['badge_types'];
    if (badgeTypesRaw is List) {
      for (final rawType in badgeTypesRaw) {
        final type = _toStringMap(rawType);
        final id = _asInt(type['id']);
        if (id == null) {
          continue;
        }
        final name = (type['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          typeNameById[id] = name;
        }
      }
    }

    final badgesRaw = decoded['badges'];
    if (badgesRaw is! List) {
      return const <RiverSideProfileBadge>[];
    }
    final badges = <RiverSideProfileBadge>[];
    for (final rawBadge in badgesRaw) {
      final badge = _toStringMap(rawBadge);
      final id = _asInt(badge['id']);
      if (id == null) {
        continue;
      }

      badges.add(
        RiverSideProfileBadge(
          id: id,
          name: (badge['name'] ?? '').toString().trim(),
          description: _sanitizeExcerpt(
            (badge['description'] ?? '').toString(),
          ),
          icon: (badge['icon'] ?? '').toString().trim(),
          imageUrl: _normalizeMaybeRelativeUrl(
            (badge['image_url'] ?? '').toString().trim(),
          ),
          grantCount: _asInt(badge['grant_count']) ?? 0,
          badgeTypeName: typeNameById[_asInt(badge['badge_type_id'])] ?? '',
        ),
      );
    }
    return badges;
  }

  Future<List<RiverSideProfileFollowUser>> fetchProfileFollowUsers(
    String username, {
    required bool followers,
    String? cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    final encoded = Uri.encodeComponent(resolvedUsername);
    final suffix = followers ? 'followers' : 'following';
    final uri = Uri.parse('$riverSideBaseUrl/u/$encoded/follow/$suffix.json');
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 404) {
      return const <RiverSideProfileFollowUser>[];
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch ${followers ? 'followers' : 'following'}, HTTP ${response.statusCode}',
      );
    }

    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    final usersRaw = decoded is List
        ? decoded
        : (decoded is Map ? decoded['users'] : null);
    if (usersRaw is! List) {
      return const <RiverSideProfileFollowUser>[];
    }

    final users = <RiverSideProfileFollowUser>[];
    for (final rawUser in usersRaw) {
      final user = _toStringMap(rawUser);
      final id = _asInt(user['id']);
      if (id == null) {
        continue;
      }
      final username = (user['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        continue;
      }
      final name = (user['name'] ?? '').toString().trim();
      users.add(
        RiverSideProfileFollowUser(
          id: id,
          username: username,
          displayName: name.isEmpty ? username : name,
          avatarUrl: _normalizeAvatarUrl(
            (user['avatar_template'] ?? '').toString(),
          ),
        ),
      );
    }
    return users;
  }

  String _normalizeMaybeRelativeUrl(String source) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('/')) {
      return '$riverSideBaseUrl$raw';
    }
    return '$riverSideBaseUrl/$raw';
  }
}
