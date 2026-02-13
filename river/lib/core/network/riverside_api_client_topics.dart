part of 'riverside_api_client.dart';

extension RiverSideApiClientTopicMethods on RiverSideApiClient {
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
      categoryNamesById =
          _categoryNameCacheByCookieKey[_categoryCacheKey(
            cookieHeader: cookieHeader,
            userApiKey: userApiKey,
            userApiClientId: userApiClientId,
          )] ??
          const <int, String>{};
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
          isPinned:
              _asBool(topic['pinned']) || _asBool(topic['pinned_globally']),
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
    final validReactions = _asStringSet(decoded['valid_reactions']);

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
      validReactions: validReactions,
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

  Future<RiverSideTopicPostDetail> fetchTopicPostByNumber({
    required int topicId,
    required int postNumber,
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/posts/by_number/$topicId/$postNumber.json'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load quoted post, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid quoted post response format',
    );
    final parsed =
        _parseTopicPost(decoded, topicId: topicId) ??
        _parseTopicPost(decoded['post'], topicId: topicId);
    if (parsed == null) {
      throw const RiverSideApiException('Quoted post payload is invalid');
    }
    return parsed;
  }

  Future<RiverSideAiTopicSummary> fetchTopicAiSummary({
    required int topicId,
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/discourse-ai/summarization/t/$topicId.json'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load AI summary, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid AI summary response format',
    );
    final summaryMap = _toStringMap(decoded['ai_topic_summary']);
    if (summaryMap.isEmpty) {
      throw const RiverSideApiException('AI summary payload is missing');
    }

    final summarizedText = (summaryMap['summarized_text'] ?? '')
        .toString()
        .trim();
    if (summarizedText.isEmpty) {
      throw const RiverSideApiException('AI summary content is empty');
    }

    return RiverSideAiTopicSummary(
      summarizedText: summarizedText,
      algorithm: (summaryMap['algorithm'] ?? '').toString().trim(),
      outdated: _asBool(summaryMap['outdated']),
      canRegenerate: _asBool(summaryMap['can_regenerate']),
      newPostsSinceSummary: _asInt(summaryMap['new_posts_since_summary']) ?? 0,
      updatedAt: DateTime.tryParse((summaryMap['updated_at'] ?? '').toString()),
    );
  }
}
