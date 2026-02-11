part of 'riverside_api_client.dart';

extension RiverSideApiClientPostMethods on RiverSideApiClient {
  Future<RiverSideCreateTopicResult> createTopic({
    required String title,
    required String raw,
    required int categoryId,
    required String cookieHeader,
    String locale = '',
    String archetype = 'regular',
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final topicTitle = title.trim();
    if (topicTitle.isEmpty) {
      throw const RiverSideApiException('Topic title is empty.');
    }
    final markdown = raw.trim();
    if (markdown.isEmpty) {
      throw const RiverSideApiException('Topic content is empty.');
    }
    if (categoryId <= 0) {
      throw const RiverSideApiException('Category id is invalid.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final response = await http.post(
      Uri.parse('$riverSideBaseUrl/posts'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/',
      },
      body: <String, String>{
        'raw': markdown,
        'title': topicTitle,
        'unlist_topic': 'false',
        'category': '$categoryId',
        'is_warning': 'false',
        'archetype': archetype,
        'locale': locale,
        'nested_post': 'true',
      },
      encoding: utf8,
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Failed to create topic.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to create topic, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid create topic response format',
    );
    final parsedPost = _parsePostFromPayload(decoded);
    final topicId =
        _asInt(decoded['topic_id']) ??
        _asInt(_toStringMap(decoded['topic'])['id']) ??
        parsedPost?.topicId ??
        0;
    if (topicId <= 0) {
      throw const RiverSideApiException(
        'Topic created but topic id is missing in response.',
      );
    }

    return RiverSideCreateTopicResult(
      topicId: topicId,
      postId: parsedPost?.id,
      postNumber: parsedPost?.postNumber,
    );
  }

  Future<List<RiverSideTopicPostDetail>> fetchPostReplies({
    required int topicId,
    required int postId,
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/posts/$postId/replies.json'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'No permission to view replies for this post.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load post replies, HTTP ${response.statusCode}',
      );
    }

    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    final repliesRaw = switch (decoded) {
      List<dynamic> list => list,
      Map<String, dynamic> map when map['replies'] is List => map['replies'],
      _ => null,
    };
    if (repliesRaw is! List) {
      throw const RiverSideApiException('Invalid post replies response format');
    }

    final replies = <RiverSideTopicPostDetail>[];
    for (final rawReply in repliesRaw) {
      final replyMap = _toStringMap(rawReply);
      final replyTopicId = _asInt(replyMap['topic_id']) ?? topicId;
      final parsed = _parseTopicPost(rawReply, topicId: replyTopicId);
      if (parsed == null || parsed.id == postId) {
        continue;
      }
      replies.add(parsed);
    }
    replies.sort((a, b) => a.postNumber.compareTo(b.postNumber));
    return replies;
  }

  Future<RiverSideTopicPostDetail> fetchPostById({
    required int postId,
    String? cookieHeader,
  }) async {
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/posts/$postId.json'),
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load post detail, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid post detail response format',
    );
    final parsed = _parsePostFromPayload(decoded);
    if (parsed == null) {
      throw const RiverSideApiException('Post payload is invalid');
    }
    return parsed;
  }

  Future<RiverSideTopicPostDetail> editPost({
    required int postId,
    required int topicId,
    required String raw,
    required String originalRaw,
    required String cookieHeader,
    String editReason = '',
    String locale = '',
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final nextRaw = raw.trim();
    if (nextRaw.isEmpty) {
      throw const RiverSideApiException('Edited content is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final response = await http.put(
      Uri.parse('$riverSideBaseUrl/posts/$postId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/t/topic/$topicId',
      },
      body: <String, String>{
        'post[edit_reason]': editReason,
        'post[raw]': nextRaw,
        'post[topic_id]': '$topicId',
        'post[original_text]': originalRaw,
        'post[locale]': locale,
      },
      encoding: utf8,
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Failed to edit post.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to edit post, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid edit post response format',
    );
    final parsed =
        _parsePostFromPayload(decoded) ??
        await fetchPostById(postId: postId, cookieHeader: cookie);
    return parsed;
  }

  Future<void> deletePost({
    required int postId,
    required int topicId,
    required int postNumber,
    required String cookieHeader,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final response = await http.delete(
      Uri.parse('$riverSideBaseUrl/posts/$postId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/t/topic/$topicId/$postNumber',
      },
      body: <String, String>{'context': '/t/topic/$topicId/$postNumber'},
      encoding: utf8,
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Failed to delete post.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to delete post, HTTP ${response.statusCode}'
            : message,
      );
    }
  }

  Future<RiverSideTopicPostDetail> createTopicReply({
    required int topicId,
    required String raw,
    required String cookieHeader,
    int? replyToPostNumber,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final markdown = raw.trim();
    if (markdown.isEmpty) {
      throw const RiverSideApiException('Reply content is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final body = <String, String>{
      'raw': markdown,
      'topic_id': '$topicId',
      'nested_post': 'true',
    };
    if (replyToPostNumber != null && replyToPostNumber > 0) {
      body['reply_to_post_number'] = '$replyToPostNumber';
    }

    final response = await http.post(
      Uri.parse('$riverSideBaseUrl/posts'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/t/topic/$topicId',
      },
      body: body,
      encoding: utf8,
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Failed to publish reply.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to publish reply, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid publish reply response format',
    );
    final post =
        _parseTopicPost(decoded, topicId: topicId) ??
        _parseTopicPost(decoded['post'], topicId: topicId);
    if (post == null) {
      throw const RiverSideApiException(
        'Reply published but response invalid.',
      );
    }
    return post;
  }

  Future<String> uploadComposerImage({
    required String cookieHeader,
    required String fileName,
    required List<int> bytes,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    if (bytes.isEmpty) {
      throw const RiverSideApiException('Image file is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$riverSideBaseUrl/uploads.json'),
    );
    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Cookie': cookie,
      'X-CSRF-Token': csrf,
      'X-Requested-With': 'XMLHttpRequest',
      'Origin': riverSideBaseUrl,
      'Referer': riverSideBaseUrl,
    });
    request.fields['type'] = 'composer';
    request.fields['synchronous'] = 'true';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Failed to upload image.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to upload image, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid upload image response format',
    );

    final shortUrl = (decoded['short_url'] ?? '').toString().trim();
    if (shortUrl.startsWith('upload://')) {
      return shortUrl;
    }
    if (shortUrl.isNotEmpty) {
      return _normalizeUploadUrl(shortUrl);
    }

    final url = (decoded['url'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      return _normalizeUploadUrl(url);
    }
    throw const RiverSideApiException(
      'Upload succeeded but image url missing.',
    );
  }

  Future<String> fetchSessionCsrfToken({required String cookieHeader}) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final cacheKey = _categoryCacheKey(cookieHeader: cookie);
    final cached = _csrfTokenCacheByCookieKey[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/session/csrf'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Cookie': cookie,
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to fetch csrf token, HTTP ${response.statusCode}',
      );
    }
    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid csrf response format',
    );
    final csrf = (decoded['csrf'] ?? '').toString().trim();
    if (csrf.isEmpty) {
      throw const RiverSideApiException('CSRF token is missing.');
    }
    _csrfTokenCacheByCookieKey[cacheKey] = csrf;
    return csrf;
  }
}
