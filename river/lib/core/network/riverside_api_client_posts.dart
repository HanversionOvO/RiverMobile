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

  Map<String, dynamic> _decodeDraftData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is! String) {
      return const <String, dynamic>{};
    }
    final text = rawData.trim();
    if (text.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  RiverSideComposerDraft _parseComposerDraftFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rawData = (payload['data'] ?? payload['draft'] ?? '').toString();
    final data = _decodeDraftData(rawData);
    final markdown = (data['reply'] ?? '').toString();
    final title = ((payload['title'] ?? data['title']) ?? '').toString().trim();
    final action = (data['action'] ?? '').toString().trim();

    return RiverSideComposerDraft(
      draftKey: (payload['draft_key'] ?? '').toString().trim(),
      sequence:
          _asInt(payload['sequence']) ?? _asInt(payload['draft_sequence']) ?? 0,
      rawData: rawData,
      data: data,
      markdown: markdown,
      title: title,
      action: action,
      topicId: _asInt(payload['topic_id']) ?? _asInt(data['topicId']),
      categoryId: _asInt(payload['category_id']) ?? _asInt(data['categoryId']),
      createdAt: DateTime.tryParse((payload['created_at'] ?? '').toString()),
    );
  }

  Future<RiverSideComposerDraft?> fetchComposerDraft({
    required String draftKey,
    required String cookieHeader,
    int? sequence,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final key = draftKey.trim();
    if (key.isEmpty) {
      throw const RiverSideApiException('Draft key is empty.');
    }

    final uri =
        Uri.parse(
          '$riverSideBaseUrl/drafts/${Uri.encodeComponent(key)}.json',
        ).replace(
          queryParameters: sequence == null
              ? null
              : <String, String>{'sequence': '$sequence'},
        );
    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookie),
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load draft, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid draft response format',
    );
    final rawDraft = (decoded['draft'] ?? '').toString();
    final draftSequence = _asInt(decoded['draft_sequence']) ?? 0;
    final payload = <String, dynamic>{
      'draft_key': key,
      'sequence': draftSequence,
      'data': rawDraft,
      'topic_id': _asInt(decoded['topic_id']),
      'category_id': _asInt(decoded['category_id']),
      'title': decoded['title'],
    };
    return _parseComposerDraftFromPayload(payload);
  }

  Future<int> saveComposerDraft({
    required String draftKey,
    required int sequence,
    required Map<String, dynamic> data,
    required String cookieHeader,
    String owner = 'river_flutter',
    bool forceSave = false,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final key = draftKey.trim();
    if (key.isEmpty) {
      throw const RiverSideApiException('Draft key is empty.');
    }
    final dataRaw = jsonEncode(data);
    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);

    final response = await http.post(
      Uri.parse('$riverSideBaseUrl/drafts.json'),
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
        'draft_key': key,
        'sequence': '$sequence',
        'data': dataRaw,
        'owner': owner,
        'force_save': forceSave ? 'true' : 'false',
      },
      encoding: utf8,
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode == 409) {
      throw const RiverSideApiException('草稿冲突，请重新打开草稿后再试。');
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to save draft, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid save draft response format',
    );
    return _asInt(decoded['draft_sequence']) ?? sequence;
  }

  Future<List<RiverSideComposerDraft>> fetchComposerDrafts({
    required String cookieHeader,
    int offset = 0,
    int limit = 50,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final uri = Uri.parse('$riverSideBaseUrl/drafts.json').replace(
      queryParameters: <String, String>{
        'offset': '${offset < 0 ? 0 : offset}',
        'limit': '${limit <= 0 ? 50 : limit}',
      },
    );

    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookie),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load drafts, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid drafts response format',
    );
    final draftsRaw = decoded['drafts'];
    if (draftsRaw is! List) {
      return const <RiverSideComposerDraft>[];
    }

    final drafts = <RiverSideComposerDraft>[];
    for (final raw in draftsRaw) {
      final payload = _toStringMap(raw);
      if (payload.isEmpty) {
        continue;
      }
      final draft = _parseComposerDraftFromPayload(payload);
      if (draft.draftKey.isEmpty) {
        continue;
      }
      drafts.add(draft);
    }
    return drafts;
  }

  Future<void> deleteComposerDraft({
    required String draftKey,
    required int sequence,
    required String cookieHeader,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final key = draftKey.trim();
    if (key.isEmpty) {
      throw const RiverSideApiException('Draft key is empty.');
    }
    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final response = await http.delete(
      Uri.parse('$riverSideBaseUrl/drafts/${Uri.encodeComponent(key)}.json'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': riverSideBaseUrl,
        'Referer': '$riverSideBaseUrl/',
      },
      body: <String, String>{'draft_key': key, 'sequence': '$sequence'},
      encoding: utf8,
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
            ? 'Failed to delete draft, HTTP ${response.statusCode}'
            : message,
      );
    }
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
