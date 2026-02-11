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
}
