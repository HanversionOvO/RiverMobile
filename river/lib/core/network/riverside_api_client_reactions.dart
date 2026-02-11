part of 'riverside_api_client.dart';

extension RiverSideApiClientReactionMethods on RiverSideApiClient {
  Future<RiverSidePostReactionState> togglePostReaction({
    required int postId,
    required String reactionId,
    required String cookieHeader,
    String? csrfToken,
  }) async {
    final cookie = cookieHeader.trim();
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }
    final reaction = reactionId.trim();
    if (reaction.isEmpty) {
      throw const RiverSideApiException('Reaction id is empty.');
    }

    final csrf = (csrfToken ?? '').trim().isNotEmpty
        ? csrfToken!.trim()
        : await fetchSessionCsrfToken(cookieHeader: cookie);

    final encodedReaction = Uri.encodeComponent(reaction);
    final response = await http.put(
      Uri.parse(
        '$riverSideBaseUrl/discourse-reactions/posts/$postId/custom-reactions/$encodedReaction/toggle.json',
      ),
      headers: <String, String>{
        'Accept': 'application/json',
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
    if (response.statusCode == 422) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty ? 'Selected reaction is not available.' : message,
      );
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to toggle reaction, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid toggle reaction response format',
    );
    final state = _parsePostReactionStateFromPostPayload(decoded);
    if (state == null) {
      throw const RiverSideApiException(
        'Toggle reaction succeeded but response payload is invalid.',
      );
    }
    return state;
  }

  Future<List<RiverSidePostReactionUsersGroup>> fetchPostReactionUsers({
    required int postId,
    String? reactionId,
    String? cookieHeader,
  }) async {
    final query = <String, String>{};
    final reaction = reactionId?.trim();
    if (reaction != null && reaction.isNotEmpty) {
      query['reaction_value'] = reaction;
    }

    final uri = Uri.parse(
      '$riverSideBaseUrl/discourse-reactions/posts/$postId/reactions-users.json',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: _buildJsonHeaders(cookieHeader: cookieHeader),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'No permission to view reaction users for this post.',
      );
    }
    if (response.statusCode == 404) {
      throw const RiverSideApiException('Post or reaction was not found.');
    }
    if (response.statusCode != 200) {
      final message = _extractErrorMessageFromResponse(response);
      throw RiverSideApiException(
        message.isEmpty
            ? 'Failed to load reaction users, HTTP ${response.statusCode}'
            : message,
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid reaction users response format',
    );

    final rawGroups = decoded['reaction_users'];
    if (rawGroups is! List) {
      return const <RiverSidePostReactionUsersGroup>[];
    }

    final result = <RiverSidePostReactionUsersGroup>[];
    for (final rawGroup in rawGroups) {
      final group = _toStringMap(rawGroup);
      final id = (group['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        continue;
      }
      final users = <RiverSideReactionUser>[];
      final rawUsers = group['users'];
      if (rawUsers is List) {
        for (final rawUser in rawUsers) {
          final user = _toStringMap(rawUser);
          final username = (user['username'] ?? '').toString().trim();
          if (username.isEmpty) {
            continue;
          }
          final name = (user['name'] ?? '').toString().trim();
          users.add(
            RiverSideReactionUser(
              username: username,
              displayName: name.isEmpty ? username : name,
              avatarUrl: _normalizeAvatarUrl(
                (user['avatar_template'] ?? '').toString(),
              ),
              canUndo: _asBool(user['can_undo']),
              createdAt: DateTime.tryParse(
                (user['created_at'] ?? '').toString(),
              ),
            ),
          );
        }
      }

      result.add(
        RiverSidePostReactionUsersGroup(
          id: id,
          count: _asInt(group['count']) ?? users.length,
          users: users,
        ),
      );
    }
    return result;
  }
}
