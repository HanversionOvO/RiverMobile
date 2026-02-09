import 'dart:convert';

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

  Future<UserAccount> fetchUserProfile(String username) async {
    final uri = Uri.parse('$riverSideBaseUrl/u/$username.json');
    final response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
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

  String normalizeAvatarUrl(String template) {
    return _normalizeAvatarUrl(template);
  }

  Future<List<RiverSideTopicSummary>> fetchTopicSummaries({
    required RiverSideTopicFeed feed,
    int page = 0,
    String? cookieHeader,
    int? categoryId,
  }) async {
    final result = await fetchTopicPage(
      feed: feed,
      page: page,
      cookieHeader: cookieHeader,
      categoryId: categoryId,
    );
    return result.topics;
  }

  Future<RiverSideTopicPage> fetchTopicPage({
    required RiverSideTopicFeed feed,
    int page = 0,
    String? cookieHeader,
    int? categoryId,
  }) async {
    final uri = await _buildTopicUri(
      feed: feed,
      page: page,
      categoryId: categoryId,
      cookieHeader: cookieHeader,
    );

    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
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
    final categoryNamesById = await _loadCategoryNameMap(
      cookieHeader: cookieHeader,
    );

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

  Future<List<RiverSideCategoryOption>> fetchCategories({
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/categories.json'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
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

    final cacheKey = _categoryCacheKey(cookieHeader);
    _categoryOptionCacheByCookieKey[cacheKey] = <int, RiverSideCategoryOption>{
      for (final item in ordered) item.id: item,
    };
    _categoryNameCacheByCookieKey[cacheKey] = _buildCategoryNameMap(ordered);
    return ordered;
  }

  Future<Map<int, RiverSideCategoryOption>> _loadCategoryOptionMap({
    String? cookieHeader,
  }) async {
    final cache =
        _categoryOptionCacheByCookieKey[_categoryCacheKey(cookieHeader)];
    if (cache != null && cache.isNotEmpty) {
      return cache;
    }

    final options = await fetchCategories(cookieHeader: cookieHeader);
    return <int, RiverSideCategoryOption>{
      for (final item in options) item.id: item,
    };
  }

  Future<Map<int, String>> _loadCategoryNameMap({String? cookieHeader}) async {
    final cache =
        _categoryNameCacheByCookieKey[_categoryCacheKey(cookieHeader)];
    if (cache != null && cache.isNotEmpty) {
      return cache;
    }

    final options = await fetchCategories(cookieHeader: cookieHeader);
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
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$riverSideBaseUrl/c/$categoryId/show.json'),
        headers: _buildJsonHeaders(cookieHeader: cookieHeader),
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
  }) async {
    if (categoryId == null) {
      return feed.uri(page: page);
    }

    final optionsById = await _loadCategoryOptionMap(
      cookieHeader: cookieHeader,
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

  Map<String, String> _buildJsonHeaders({String? cookieHeader}) {
    final headers = <String, String>{'Accept': 'application/json'};
    final cookie = cookieHeader?.trim();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  String _categoryCacheKey(String? cookieHeader) {
    final cookie = cookieHeader?.trim();
    if (cookie == null || cookie.isEmpty) {
      return 'guest';
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
}

class RiverSideApiException implements Exception {
  const RiverSideApiException(this.message);

  final String message;
}
