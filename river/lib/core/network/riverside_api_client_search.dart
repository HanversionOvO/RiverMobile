part of 'riverside_api_client.dart';

extension RiverSideApiClientSearchMethods on RiverSideApiClient {
  Future<RiverSidePostSearchPage> searchPosts({
    required String query,
    int page = 1,
    String? cookieHeader,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return RiverSidePostSearchPage(
        items: const <RiverSidePostSearchItem>[],
        page: page,
        hasMore: false,
      );
    }

    final pageNumber = page < 0 ? 0 : page;
    final firstPass = await _searchPostsSinglePage(
      keyword: keyword,
      page: pageNumber,
      cookieHeader: cookieHeader,
    );
    if (firstPass.items.isNotEmpty || pageNumber != 1) {
      return firstPass;
    }

    // Some deployments use page=0 as first page in practice.
    final fallbackPage0 = await _searchPostsSinglePage(
      keyword: keyword,
      page: 0,
      cookieHeader: cookieHeader,
    );
    return fallbackPage0.items.isEmpty ? firstPass : fallbackPage0;
  }

  Future<RiverSidePostSearchPage> _searchPostsSinglePage({
    required String keyword,
    required int page,
    String? cookieHeader,
  }) async {
    final uri = Uri.parse(
      '$riverSideBaseUrl/search.json?q=${Uri.encodeQueryComponent(keyword)}&page=$page',
    );
    final response = await http.get(
      uri,
      headers: <String, String>{
        ..._buildJsonHeaders(cookieHeader: cookieHeader),
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': riverSideBaseUrl,
      },
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to search posts, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid post search response format',
    );
    final grouped = _toStringMap(decoded['grouped_search_result']);
    final hasMore =
        _asBool(grouped['more_full_page_results']) ||
        _asBool(grouped['more_posts']);

    final usersById = _extractUsersById(decoded['users']);
    final categoriesById = _extractCategoryNamesFromSearchPayload(decoded);

    final topicById = <int, Map<String, dynamic>>{};
    final topicsRaw = decoded['topics'];
    if (topicsRaw is List) {
      for (final rawTopic in topicsRaw) {
        final topic = _toStringMap(rawTopic);
        final topicId = _asInt(topic['id']) ?? 0;
        if (topicId > 0) {
          topicById[topicId] = topic;
        }
      }
    }

    final posts = <Map<String, dynamic>>[];
    final postById = <int, Map<String, dynamic>>{};
    final primaryPostByTopicId = <int, Map<String, dynamic>>{};
    final postsRaw = decoded['posts'];
    if (postsRaw is List) {
      for (final rawPost in postsRaw) {
        final post = _toStringMap(rawPost);
        final postId = _asInt(post['id']) ?? 0;
        final topicId = _asInt(post['topic_id']) ?? 0;
        if (postId <= 0 || topicId <= 0) {
          continue;
        }
        posts.add(post);
        postById[postId] = post;
        primaryPostByTopicId.putIfAbsent(topicId, () => post);
      }
    }

    final orderedTopicIds = <int>[];
    final addedTopicIds = <int>{};
    void addTopicId(int topicId) {
      if (topicId <= 0 || addedTopicIds.contains(topicId)) {
        return;
      }
      addedTopicIds.add(topicId);
      orderedTopicIds.add(topicId);
    }

    final groupedPostIds = _asIntList(grouped['post_ids']);
    for (final postId in groupedPostIds) {
      final post = postById[postId];
      if (post == null) {
        continue;
      }
      addTopicId(_asInt(post['topic_id']) ?? 0);
    }

    for (final post in posts) {
      addTopicId(_asInt(post['topic_id']) ?? 0);
    }

    for (final topicId in topicById.keys) {
      addTopicId(topicId);
    }

    final items = <RiverSidePostSearchItem>[];
    for (final topicId in orderedTopicIds) {
      final topic = topicById[topicId] ?? const <String, dynamic>{};
      final post = primaryPostByTopicId[topicId];

      final user = _resolveSearchUser(
        post: post,
        topic: topic,
        usersById: usersById,
      );
      final username = (post?['username'] ?? user?['username'] ?? '')
          .toString()
          .trim();
      final displayName =
          (post?['display_username'] ??
                  post?['name'] ??
                  user?['name'] ??
                  user?['username'] ??
                  '')
              .toString()
              .trim();

      final rawTitle =
          (topic['title'] ??
                  topic['fancy_title'] ??
                  post?['topic_title'] ??
                  post?['topic_fancy_title'] ??
                  post?['title'] ??
                  '')
              .toString();
      final sanitizedTitle = _sanitizeExcerpt(rawTitle);
      final title = sanitizedTitle.isEmpty ? 'Topic #$topicId' : sanitizedTitle;

      final rawExcerpt =
          (post?['blurb'] ??
                  post?['excerpt'] ??
                  post?['cooked'] ??
                  post?['raw'] ??
                  topic['blurb'] ??
                  topic['excerpt'] ??
                  '')
              .toString();
      final excerpt = _sanitizeExcerpt(rawExcerpt);

      final categoryId =
          _asInt(topic['category_id']) ?? _asInt(post?['category_id']);
      final categoryName = _buildCategoryName(
        categoryId: categoryId,
        categoriesById: categoriesById,
      );

      final replyCount =
          _asInt(topic['reply_count']) ??
          _asInt(post?['reply_count']) ??
          ((_asInt(topic['posts_count']) ?? 1) - 1).clamp(0, 1 << 30);
      final viewCount = _asInt(topic['views']) ?? _asInt(post?['views']) ?? 0;
      final createdAt = DateTime.tryParse(
        (topic['last_posted_at'] ??
                post?['created_at'] ??
                topic['created_at'] ??
                '')
            .toString(),
      );

      items.add(
        RiverSidePostSearchItem(
          topicId: topicId,
          title: title,
          excerpt: excerpt,
          authorUsername: username,
          authorDisplayName: displayName.isEmpty
              ? (username.isEmpty ? 'Anonymous User' : username)
              : displayName,
          authorAvatarUrl: _normalizeAvatarUrl(
            (post?['avatar_template'] ?? user?['avatar_template'] ?? '')
                .toString(),
          ),
          categoryName: categoryName,
          replyCount: replyCount,
          viewCount: viewCount,
          createdAt: createdAt,
        ),
      );
    }

    return RiverSidePostSearchPage(items: items, page: page, hasMore: hasMore);
  }

  Map<String, dynamic>? _resolveSearchUser({
    required Map<String, dynamic>? post,
    required Map<String, dynamic> topic,
    required Map<int, Map<String, dynamic>> usersById,
  }) {
    final postUserId = _asInt(post?['user_id']);
    if (postUserId != null && usersById.containsKey(postUserId)) {
      return usersById[postUserId];
    }

    final topicPosterUserId = _findPrimaryPosterUserId(topic['poster_users']);
    if (topicPosterUserId != null && usersById.containsKey(topicPosterUserId)) {
      return usersById[topicPosterUserId];
    }

    return null;
  }

  String _buildCategoryName({
    required int? categoryId,
    required Map<int, String> categoriesById,
  }) {
    if (categoryId == null) {
      return 'Uncategorized';
    }
    return categoriesById[categoryId] ?? 'Category #$categoryId';
  }

  Future<List<String>> fetchRecentSearches({String? cookieHeader}) async {
    final cookie = cookieHeader?.trim() ?? '';
    if (cookie.isEmpty) {
      return const <String>[];
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/u/recent-searches.json'),
      headers: <String, String>{
        ..._buildJsonHeaders(cookieHeader: cookie),
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': riverSideBaseUrl,
      },
    );

    if (response.statusCode == 403) {
      return const <String>[];
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load recent searches, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid recent searches response format',
    );
    final recentRaw = decoded['recent_searches'];
    if (recentRaw is! List) {
      return const <String>[];
    }

    final result = <String>[];
    for (final item in recentRaw) {
      final keyword = '$item'.trim();
      if (keyword.isEmpty) {
        continue;
      }
      if (!result.contains(keyword)) {
        result.add(keyword);
      }
    }
    return result;
  }

  Future<void> clearRecentSearches({required String cookieHeader}) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final response = await http.delete(
      Uri.parse('$riverSideBaseUrl/u/recent-searches'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/',
      },
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to clear recent searches, HTTP ${response.statusCode}'
            : message,
      );
    }
  }

  Future<List<RiverSideUserSearchItem>> searchUsers({
    required String term,
    int limit = 20,
    String? cookieHeader,
  }) async {
    final keyword = term.trim();
    if (keyword.isEmpty) {
      return const <RiverSideUserSearchItem>[];
    }
    final resolvedLimit = limit <= 0 ? 20 : limit;
    final uri = Uri.parse(
      '$riverSideBaseUrl/u/search/users.json?term=${Uri.encodeQueryComponent(keyword)}&limit=$resolvedLimit',
    );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to search users, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid user search response format',
    );
    final usersRaw = decoded['users'];
    if (usersRaw is! List) {
      return const <RiverSideUserSearchItem>[];
    }

    final result = <RiverSideUserSearchItem>[];
    for (final raw in usersRaw) {
      final user = _toStringMap(raw);
      final username = (user['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        continue;
      }
      final displayName = (user['name'] ?? '').toString().trim();
      result.add(
        RiverSideUserSearchItem(
          id: _asInt(user['id']) ?? 0,
          username: username,
          displayName: displayName.isEmpty ? username : displayName,
          avatarUrl: _normalizeAvatarUrl(
            (user['avatar_template'] ?? '').toString(),
          ),
        ),
      );
    }
    return result;
  }

  Future<List<RiverSideCategorySearchItem>> searchCategories({
    required String query,
    int limit = 20,
    String? cookieHeader,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const <RiverSideCategorySearchItem>[];
    }
    final resolvedLimit = limit <= 0 ? 20 : limit;
    final uri = Uri.parse(
      '$riverSideBaseUrl/tags/filter/search.json?limit=$resolvedLimit&q=${Uri.encodeQueryComponent(keyword)}',
    );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to search categories, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid category search response format',
    );
    final resultsRaw = decoded['results'];
    if (resultsRaw is! List) {
      return const <RiverSideCategorySearchItem>[];
    }

    final result = <RiverSideCategorySearchItem>[];
    for (final raw in resultsRaw) {
      if (raw is String) {
        final name = raw.trim();
        if (name.isEmpty) {
          continue;
        }
        result.add(RiverSideCategorySearchItem(id: name, name: name));
        continue;
      }
      final map = _toStringMap(raw);
      if (map.isEmpty) {
        continue;
      }
      final id = (map['id'] ?? map['value'] ?? map['slug'] ?? '')
          .toString()
          .trim();
      final name = (map['name'] ?? map['text'] ?? map['value'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) {
        continue;
      }
      result.add(
        RiverSideCategorySearchItem(
          id: id.isEmpty ? name : id,
          name: name,
          description: (map['description'] ?? '').toString().trim(),
        ),
      );
    }
    return result;
  }

  Map<int, String> _extractCategoryNamesFromSearchPayload(
    Map<String, dynamic> decoded,
  ) {
    final categoriesRaw = decoded['categories'];
    if (categoriesRaw is! List) {
      return const <int, String>{};
    }
    final byId = <int, Map<String, dynamic>>{};
    for (final raw in categoriesRaw) {
      final map = _toStringMap(raw);
      final id = _asInt(map['id']);
      if (id != null) {
        byId[id] = map;
      }
    }
    final result = <int, String>{};
    for (final entry in byId.entries) {
      final id = entry.key;
      final name = (entry.value['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }
      final parentId = _asInt(entry.value['parent_category_id']);
      if (parentId == null || !byId.containsKey(parentId)) {
        result[id] = name;
      } else {
        final parentName = (byId[parentId]!['name'] ?? '').toString().trim();
        result[id] = parentName.isEmpty ? name : '$parentName / $name';
      }
    }
    return result;
  }
}
