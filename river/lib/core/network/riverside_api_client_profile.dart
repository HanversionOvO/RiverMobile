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
    final usernameFromApi = (user['username'] ?? resolvedUsername)
        .toString()
        .trim();
    final name = (user['name'] ?? '').toString().trim();
    final displayName = name.isEmpty ? usernameFromApi : name;
    final avatarTemplate = (user['avatar_template'] ?? '').toString();
    final title = (user['title'] ?? '').toString().trim();

    final account = UserAccount(
      provider: AccountProvider.riverSide,
      userId: _asInt(user['id']),
      username: usernameFromApi,
      displayName: displayName.isEmpty ? usernameFromApi : displayName,
      avatarUrl: _normalizeAvatarUrl(avatarTemplate),
      title: title,
    );

    return RiverSideProfileOverview(
      account: account,
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
      topicCount: _asInt(user['topic_count']) ?? 0,
      postCount: _asInt(user['post_count']) ?? 0,
      likesGiven: _asInt(user['likes_given']) ?? 0,
      likesReceived: _asInt(user['likes_received']) ?? 0,
      followersCount: _asInt(user['total_followers']) ?? 0,
      followingCount: _asInt(user['total_following']) ?? 0,
    );
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
    final pathCandidates = switch (kind) {
      RiverSideProfileActivityKind.all => <String>['/u/$encoded/activity.json'],
      RiverSideProfileActivityKind.topics => <String>[
        '/u/$encoded/activity/topics.json',
      ],
      RiverSideProfileActivityKind.replies => <String>[
        '/u/$encoded/activity/replies.json',
        '/u/$encoded/activity/replies',
      ],
      RiverSideProfileActivityKind.likesGiven => <String>[
        '/u/$encoded/activity/likes-given.json',
        '/u/$encoded/activity/likes-given',
      ],
    };

    RiverSideApiException? lastError;
    for (final path in pathCandidates) {
      final uri = Uri.parse('$riverSideBaseUrl$path');
      final response = await http.get(
        uri,
        headers: _buildJsonHeaders(cookieHeader: cookieHeader),
      );
      if (response.statusCode == 404) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode != 200) {
        lastError = RiverSideApiException(
          'Failed to fetch profile activity, HTTP ${response.statusCode}',
        );
        continue;
      }

      final decoded = _decodeJsonObject(
        response,
        fallbackMessage: 'Invalid profile activity response format',
      );
      return _parseProfileActivities(decoded);
    }

    throw lastError ??
        const RiverSideApiException('Failed to fetch profile activity.');
  }

  List<RiverSideProfileActivityItem> _parseProfileActivities(
    Map<String, dynamic> decoded,
  ) {
    final usersById = _extractUsersById(
      decoded['users'] ?? _toStringMap(decoded['topic_list'])['users'],
    );
    final categoriesById = _extractProfileCategoryNames(decoded);

    final fromTopics = _parseProfileActivitiesFromTopicList(
      decoded,
      usersById: usersById,
      categoriesById: categoriesById,
    );
    final fromActions = _parseProfileActivitiesFromUserActions(
      decoded,
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

  List<RiverSideProfileActivityItem> _parseProfileActivitiesFromTopicList(
    Map<String, dynamic> decoded, {
    required Map<int, Map<String, dynamic>> usersById,
    required Map<int, String> categoriesById,
  }) {
    final topicList = _toStringMap(decoded['topic_list']);
    final topicsRaw = topicList['topics'];
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

      final title = _sanitizeExcerpt((topic['title'] ?? '').toString());
      final excerpt = _sanitizeExcerpt((topic['excerpt'] ?? '').toString());
      final categoryId = _asInt(topic['category_id']);
      final categoryName = categoriesById[categoryId] ?? '未分类';
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
              ? (username.isEmpty ? '未知用户' : username)
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
      final topicId = _asInt(action['topic_id']) ?? _asInt(action['id']);
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
        (action['title'] ?? action['topic_title'] ?? action['slug'] ?? '')
            .toString(),
      );
      final excerpt = _sanitizeExcerpt(
        (action['excerpt'] ?? action['raw'] ?? action['cooked'] ?? '')
            .toString(),
      );
      final categoryName = (action['category_name'] ?? '').toString().trim();

      items.add(
        RiverSideProfileActivityItem(
          topicId: topicId,
          postNumber: _asInt(action['post_number']),
          title: title.isEmpty ? '帖子 #$topicId' : title,
          excerpt: excerpt,
          categoryName: categoryName.isEmpty
              ? (categoriesById[categoryId] ?? '未分类')
              : categoryName,
          authorUsername: username,
          authorDisplayName: displayName.isEmpty
              ? (username.isEmpty ? '未知用户' : username)
              : displayName,
          authorAvatarUrl: _normalizeAvatarUrl(
            (action['avatar_template'] ?? user?['avatar_template'] ?? '')
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
