import 'dart:convert';

import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_topic_models.dart';

class RiverSideApiClient {
  final Map<String, Map<int, String>> _categoryNameCacheByCookieKey =
      <String, Map<int, String>>{};
  final Map<String, Map<int, RiverSideCategoryOption>>
  _categoryOptionCacheByCookieKey =
      <String, Map<int, RiverSideCategoryOption>>{};

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

  Future<List<RiverSideTopicSummary>> fetchTopicSummaries({
    required RiverSideTopicFeed feed,
    int page = 0,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
    int? categoryId,
  }) async {
    final result = await fetchTopicPage(
      feed: feed,
      page: page,
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
      categoryId: categoryId,
    );
    return result.topics;
  }

  Future<RiverSideTopicPage> fetchTopicPage({
    required RiverSideTopicFeed feed,
    int page = 0,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
    int? categoryId,
  }) async {
    final uri = await _buildTopicUri(
      feed: feed,
      page: page,
      categoryId: categoryId,
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );

    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load topics, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid topic response format',
    );

    final topicList = _toStringMap(decoded['topic_list']);
    final topicsRaw = topicList['topics'];
    if (topicsRaw is! List) {
      return RiverSideTopicPage(
        topics: const <RiverSideTopicSummary>[],
        hasMore: false,
        page: page,
      );
    }

    final usersById = _extractUsersById(decoded['users']);
    var categoryNamesById = _extractCategoryNamesFromTopicPayload(decoded);
    if (categoryNamesById.isEmpty) {
      categoryNamesById = await _loadCategoryNameMap(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      );
    }

    final result = <RiverSideTopicSummary>[];
    for (final rawTopic in topicsRaw) {
      final topic = _toStringMap(rawTopic);
      if (topic.isEmpty) {
        continue;
      }

      final topicId = _asInt(topic['id']) ?? 0;
      final title = (topic['title'] ?? '').toString().trim();
      if (topicId == 0 || title.isEmpty) {
        continue;
      }

      final topicCategoryId = _asInt(topic['category_id']);
      final categoryName = topicCategoryId == null
          ? '\u672a\u5206\u7c7b'
          : (categoryNamesById[topicCategoryId] ??
                '\u5206\u7c7b#$topicCategoryId');

      final authorUserId = _findPrimaryPosterUserId(topic['posters']);
      final user = authorUserId == null ? null : usersById[authorUserId];

      final username =
          (user?['username'] ?? topic['last_poster_username'] ?? '')
              .toString()
              .trim();
      final displayName = (user?['name'] ?? '').toString().trim();
      final authorName = displayName.isEmpty
          ? (username.isEmpty ? '\u533f\u540d\u7528\u6237' : username)
          : displayName;
      final avatarTemplate = (user?['avatar_template'] ?? '').toString();

      result.add(
        RiverSideTopicSummary(
          id: topicId,
          title: title,
          excerpt: _sanitizeExcerpt((topic['excerpt'] ?? '').toString()),
          categoryId: topicCategoryId,
          categoryName: categoryName,
          replyCount: _asInt(topic['reply_count']) ?? 0,
          viewCount: _asInt(topic['views']) ?? 0,
          createdAt: DateTime.tryParse((topic['created_at'] ?? '').toString()),
          authorDisplayName: authorName,
          authorUsername: username,
          authorAvatarUrl: _normalizeAvatarUrl(avatarTemplate),
          isHot: feed == RiverSideTopicFeed.hot || _asBool(topic['is_hot']),
        ),
      );
    }

    final moreTopicsUrl = (topicList['more_topics_url'] ?? '')
        .toString()
        .trim();
    final perPage = _asInt(topicList['per_page']) ?? 0;
    final hasMore =
        moreTopicsUrl.isNotEmpty ||
        (perPage > 0 ? result.length >= perPage : result.isNotEmpty);

    return RiverSideTopicPage(topics: result, hasMore: hasMore, page: page);
  }

  Future<RiverSideTopicDetail> fetchTopicDetail({
    required int topicId,
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/t/topic/$topicId.json?include_raw=true'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load topic detail, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid topic detail response format',
    );

    final topicIdFromApi = _asInt(decoded['id']) ?? topicId;
    final title = (decoded['title'] ?? '').toString().trim();
    final viewCount = _asInt(decoded['views']) ?? 0;
    final replyCount = _asInt(decoded['reply_count']) ?? 0;
    final likeCount = _asInt(decoded['like_count']) ?? 0;
    final createdAt = DateTime.tryParse(
      (decoded['created_at'] ?? '').toString(),
    );

    final postStream = _toStringMap(decoded['post_stream']);
    final postsRaw = postStream['posts'];
    if (postsRaw is! List) {
      throw const RiverSideApiException('Topic post stream is missing');
    }

    final streamPostIds = _asIntList(postStream['stream']);
    final loadedPostIds = <int>{};
    RiverSideTopicPostDetail? mainPost;
    final comments = <RiverSideTopicPostDetail>[];

    for (final rawPost in postsRaw) {
      final parsed = _parseTopicPost(rawPost, topicId: topicIdFromApi);
      if (parsed == null) {
        continue;
      }
      loadedPostIds.add(parsed.id);
      if (parsed.postNumber == 1) {
        mainPost = parsed;
      } else {
        comments.add(parsed);
      }
    }

    comments.sort((a, b) => a.postNumber.compareTo(b.postNumber));
    if (mainPost == null) {
      throw const RiverSideApiException('Main post is missing');
    }

    return RiverSideTopicDetail(
      topicId: topicIdFromApi,
      title: title,
      viewCount: viewCount,
      replyCount: replyCount,
      likeCount: likeCount,
      createdAt: createdAt,
      mainPost: mainPost,
      comments: comments,
      streamPostIds: streamPostIds,
      loadedPostIds: loadedPostIds,
    );
  }

  Future<List<RiverSideTopicPostDetail>> fetchTopicPostsByIds({
    required int topicId,
    required List<int> postIds,
    String? cookieHeader,
  }) async {
    if (postIds.isEmpty) {
      return const <RiverSideTopicPostDetail>[];
    }

    final encodedKey = Uri.encodeQueryComponent('post_ids[]');
    final query = postIds
        .map((id) => '$encodedKey=${Uri.encodeQueryComponent('$id')}')
        .join('&');
    final uri = Uri.parse(
      '$riverSideBaseUrl/t/$topicId/posts.json?$query&include_raw=true',
    );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load topic posts, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid topic posts response format',
    );
    final postStream = _toStringMap(decoded['post_stream']);
    final postsRaw = postStream['posts'];
    if (postsRaw is! List) {
      return const <RiverSideTopicPostDetail>[];
    }

    final posts = <RiverSideTopicPostDetail>[];
    for (final rawPost in postsRaw) {
      final parsed = _parseTopicPost(rawPost, topicId: topicId);
      if (parsed != null) {
        posts.add(parsed);
      }
    }
    posts.sort((a, b) => a.postNumber.compareTo(b.postNumber));
    return posts;
  }

  Future<List<RiverSideCategoryOption>> fetchCategories({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/categories.json'),
      headers: _buildJsonHeaders(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load categories, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid categories response format',
    );

    final categoryList = _toStringMap(decoded['category_list']);
    final categoriesRaw = categoryList['categories'];
    if (categoriesRaw is! List) {
      return const <RiverSideCategoryOption>[];
    }

    final rawById = <int, Map<String, dynamic>>{};
    for (final raw in categoriesRaw) {
      final map = _toStringMap(raw);
      final id = _asInt(map['id']);
      if (id != null) {
        rawById[id] = map;
      }
    }

    final missingSubCategoryIds = <int>{};
    for (final raw in rawById.values) {
      for (final subId in _asIntList(raw['subcategory_ids'])) {
        if (!rawById.containsKey(subId)) {
          missingSubCategoryIds.add(subId);
        }
      }
    }

    for (final subId in missingSubCategoryIds) {
      final detail = await _fetchCategoryDetail(
        categoryId: subId,
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      );
      if (detail != null) {
        rawById[subId] = detail;
      }
    }

    final optionById = <int, RiverSideCategoryOption>{};
    for (final raw in rawById.values) {
      final option = _parseCategoryOption(raw);
      if (option != null) {
        optionById[option.id] = option;
      }
    }

    final topLevel =
        optionById.values
            .where((option) => option.parentCategoryId == null)
            .toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            if (byPosition != 0) {
              return byPosition;
            }
            return a.id.compareTo(b.id);
          });

    final ordered = <RiverSideCategoryOption>[];
    for (final parent in topLevel) {
      ordered.add(parent);
      final children =
          optionById.values
              .where((option) => option.parentCategoryId == parent.id)
              .toList()
            ..sort((a, b) {
              final byPosition = a.position.compareTo(b.position);
              if (byPosition != 0) {
                return byPosition;
              }
              return a.id.compareTo(b.id);
            });
      ordered.addAll(children);
    }

    final already = ordered.map((item) => item.id).toSet();
    final orphans =
        optionById.values.where((item) => !already.contains(item.id)).toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            if (byPosition != 0) {
              return byPosition;
            }
            return a.id.compareTo(b.id);
          });
    ordered.addAll(orphans);

    final cacheKey = _categoryCacheKey(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    _categoryOptionCacheByCookieKey[cacheKey] = <int, RiverSideCategoryOption>{
      for (final item in ordered) item.id: item,
    };
    _categoryNameCacheByCookieKey[cacheKey] = _buildCategoryNameMap(ordered);
    return ordered;
  }

  Future<Map<int, RiverSideCategoryOption>> _loadCategoryOptionMap({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cache =
        _categoryOptionCacheByCookieKey[_categoryCacheKey(
          cookieHeader: cookieHeader,
          userApiKey: userApiKey,
          userApiClientId: userApiClientId,
        )];
    if (cache != null && cache.isNotEmpty) {
      return cache;
    }

    final options = await fetchCategories(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    return <int, RiverSideCategoryOption>{
      for (final item in options) item.id: item,
    };
  }

  Future<Map<int, String>> _loadCategoryNameMap({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cache =
        _categoryNameCacheByCookieKey[_categoryCacheKey(
          cookieHeader: cookieHeader,
          userApiKey: userApiKey,
          userApiClientId: userApiClientId,
        )];
    if (cache != null && cache.isNotEmpty) {
      return cache;
    }

    final options = await fetchCategories(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    return _buildCategoryNameMap(options);
  }

  Map<int, String> _buildCategoryNameMap(
    List<RiverSideCategoryOption> options,
  ) {
    final byId = <int, RiverSideCategoryOption>{
      for (final item in options) item.id: item,
    };
    final names = <int, String>{};
    for (final option in options) {
      final parentId = option.parentCategoryId;
      if (parentId == null) {
        names[option.id] = option.name;
        continue;
      }

      final parent = byId[parentId];
      names[option.id] = parent == null
          ? option.name
          : '${parent.name} / ${option.name}';
    }
    return names;
  }

  Future<Map<String, dynamic>?> _fetchCategoryDetail({
    required int categoryId,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$riverSideBaseUrl/c/$categoryId/show.json'),
        headers: _buildJsonHeaders(
          cookieHeader: cookieHeader,
          userApiKey: userApiKey,
          userApiClientId: userApiClientId,
        ),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = _decodeJsonObject(
        response,
        fallbackMessage: 'Invalid category detail response format',
      );
      final raw = _toStringMap(decoded['category']);
      return raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  RiverSideCategoryOption? _parseCategoryOption(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']);
    final name = (raw['name'] ?? '').toString().trim();
    if (id == null || name.isEmpty) {
      return null;
    }

    return RiverSideCategoryOption(
      id: id,
      name: name,
      position: _asInt(raw['position']) ?? 9999,
      parentCategoryId: _asInt(raw['parent_category_id']),
      description: (raw['description_text'] ?? '').toString().trim(),
    );
  }

  Future<Uri> _buildTopicUri({
    required RiverSideTopicFeed feed,
    required int page,
    required int? categoryId,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    if (categoryId == null) {
      return feed.uri(page: page);
    }

    final optionsById = await _loadCategoryOptionMap(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    final option = optionsById[categoryId];
    final categoryPath = option == null
        ? '/c/$categoryId'
        : option.parentCategoryId == null
        ? '/c/${option.id}'
        : '/c/${option.parentCategoryId}/${option.id}';

    switch (feed) {
      case RiverSideTopicFeed.latestCreated:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/latest.json?filter=latest&order=created&page=$page',
        );
      case RiverSideTopicFeed.latestReplied:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/latest.json?filter=latest&page=$page',
        );
      case RiverSideTopicFeed.hot:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/hot.json?page=$page',
        );
    }
  }

  RiverSideTopicPostDetail? _parseTopicPost(
    dynamic rawPost, {
    required int topicId,
  }) {
    final post = _toStringMap(rawPost);
    if (post.isEmpty) {
      return null;
    }

    final id = _asInt(post['id']);
    final postNumber = _asInt(post['post_number']);
    if (id == null || postNumber == null) {
      return null;
    }

    final username = (post['username'] ?? '').toString().trim();
    final displayUsername = (post['display_username'] ?? '').toString().trim();
    final name = (post['name'] ?? '').toString().trim();
    final displayName = displayUsername.isNotEmpty
        ? displayUsername
        : (name.isNotEmpty ? name : (username.isEmpty ? '匿名用户' : username));
    final avatarTemplate = (post['avatar_template'] ?? '').toString();
    final authorTitle = (post['user_title'] ?? post['primary_group_name'] ?? '')
        .toString()
        .trim();
    final createdAt = DateTime.tryParse((post['created_at'] ?? '').toString());
    final version = _asInt(post['version']) ?? 1;
    final editCount = version > 1 ? version - 1 : 0;
    final rawMarkdown = (post['raw'] ?? '').toString().trim();
    final cooked = (post['cooked'] ?? '').toString();

    final onlineValue = post['online'];
    final isOnline = onlineValue is bool
        ? onlineValue
        : (onlineValue is String ? onlineValue.toLowerCase() == 'true' : null);

    return RiverSideTopicPostDetail(
      id: id,
      topicId: topicId,
      postNumber: postNumber,
      authorUsername: username,
      authorDisplayName: displayName,
      authorAvatarUrl: _normalizeAvatarUrl(avatarTemplate),
      authorTitle: authorTitle,
      isOnline: isOnline,
      contentMarkdown: rawMarkdown.isNotEmpty
          ? rawMarkdown
          : _cookHtmlToMarkdown(cooked),
      createdAt: createdAt,
      editCount: editCount,
      likeCount: _extractLikeCount(post['actions_summary']),
    );
  }

  String _normalizeAvatarUrl(String template) {
    if (template.isEmpty) {
      return '';
    }

    final path = template.replaceAll('{size}', '120');
    if (path.startsWith('https://') || path.startsWith('http://')) {
      return path;
    }
    if (path.startsWith('//')) {
      return 'https:$path';
    }
    if (path.startsWith('/')) {
      return '$riverSideBaseUrl$path';
    }
    return '$riverSideBaseUrl/$path';
  }

  Map<String, String> _buildJsonHeaders({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};
    final cookie = cookieHeader?.trim();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    final key = userApiKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers['User-Api-Key'] = key;
    }
    final clientId = userApiClientId?.trim();
    if (clientId != null && clientId.isNotEmpty) {
      headers['User-Api-Client-Id'] = clientId;
    }
    return headers;
  }

  String _categoryCacheKey({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) {
    final cookie = cookieHeader?.trim();
    final key = userApiKey?.trim();
    final clientId = userApiClientId?.trim();
    if (cookie == null || cookie.isEmpty) {
      if (key == null || key.isEmpty) {
        return 'guest';
      }
      return 'ua:$key/$clientId';
    }
    return cookie;
  }

  Map<String, dynamic> _decodeJsonObject(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw RiverSideApiException(fallbackMessage);
    }
    return decoded;
  }

  Map<int, Map<String, dynamic>> _extractUsersById(dynamic usersRaw) {
    if (usersRaw is! List) {
      return const <int, Map<String, dynamic>>{};
    }

    final result = <int, Map<String, dynamic>>{};
    for (final rawUser in usersRaw) {
      final user = _toStringMap(rawUser);
      final id = _asInt(user['id']);
      if (id != null) {
        result[id] = user;
      }
    }
    return result;
  }

  Map<int, String> _extractCategoryNamesFromTopicPayload(
    Map<String, dynamic> decoded,
  ) {
    final topicList = _toStringMap(decoded['topic_list']);
    final categoriesRaw = topicList['categories'];
    if (categoriesRaw is! List) {
      return const <int, String>{};
    }

    final categoryById = <int, Map<String, dynamic>>{};
    for (final raw in categoriesRaw) {
      final category = _toStringMap(raw);
      final id = _asInt(category['id']);
      if (id == null) {
        continue;
      }
      categoryById[id] = category;
    }

    if (categoryById.isEmpty) {
      return const <int, String>{};
    }

    final names = <int, String>{};
    for (final entry in categoryById.entries) {
      final id = entry.key;
      final category = entry.value;
      final name = (category['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }

      final parentId = _asInt(category['parent_category_id']);
      if (parentId == null || !categoryById.containsKey(parentId)) {
        names[id] = name;
        continue;
      }

      final parentName = (categoryById[parentId]!['name'] ?? '')
          .toString()
          .trim();
      names[id] = parentName.isEmpty ? name : '$parentName / $name';
    }

    return names;
  }

  int? _findPrimaryPosterUserId(dynamic postersRaw) {
    if (postersRaw is List) {
      for (final rawPoster in postersRaw) {
        final poster = _toStringMap(rawPoster);
        final description = (poster['description'] ?? '').toString();
        if (description.contains('Original Poster') ||
            description.contains('\u539f\u59cb')) {
          return _asInt(poster['user_id']);
        }
      }

      for (final rawPoster in postersRaw) {
        final poster = _toStringMap(rawPoster);
        final id = _asInt(poster['user_id']);
        if (id != null) {
          return id;
        }
      }
    }

    if (postersRaw is Map) {
      return _asInt(postersRaw['user_id']);
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  List<int> _asIntList(dynamic value) {
    if (value is! List) {
      return const <int>[];
    }
    final result = <int>[];
    for (final item in value) {
      final number = _asInt(item);
      if (number != null) {
        result.add(number);
      }
    }
    return result;
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, dynamic> _toStringMap(dynamic value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }
    return value.map((key, item) => MapEntry('$key', item));
  }

  String _sanitizeExcerpt(String source) {
    if (source.isEmpty) {
      return '';
    }

    return source
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&hellip;', '...')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _cookHtmlToMarkdown(String source) {
    if (source.isEmpty) {
      return '';
    }

    final markdown = html2md.convert(source).trim();
    if (markdown.isEmpty) {
      return _sanitizeCookedAsPlainText(source);
    }

    return markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  String _sanitizeCookedAsPlainText(String source) {
    if (source.isEmpty) {
      return '';
    }

    return source
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&hellip;', '...')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  int _extractLikeCount(dynamic actionsSummaryRaw) {
    if (actionsSummaryRaw is! List) {
      return 0;
    }

    for (final rawAction in actionsSummaryRaw) {
      final action = _toStringMap(rawAction);
      final id = _asInt(action['id']);
      if (id == 2) {
        return _asInt(action['count']) ?? 0;
      }
    }

    return 0;
  }
}

class RiverSideApiException implements Exception {
  const RiverSideApiException(this.message);

  final String message;
}
