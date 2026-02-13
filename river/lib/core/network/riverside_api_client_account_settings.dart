part of 'riverside_api_client.dart';

extension RiverSideApiClientAccountSettingsMethods on RiverSideApiClient {
  Future<RiverSideAccountSettingsSnapshot> fetchAccountSettingsSnapshot({
    required String username,
    required String cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final encoded = Uri.encodeComponent(resolvedUsername);
    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/u/$encoded.json'),
      headers: _buildJsonHeaders(cookieHeader: cookie),
    );
    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load account settings, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid account settings response format',
    );
    final user = _toStringMap(decoded['user']);
    if (user.isEmpty) {
      throw const RiverSideApiException('User payload is missing.');
    }

    final userOption = _toStringMap(user['user_option']);
    final usernameFromPayload = (user['username'] ?? resolvedUsername)
        .toString()
        .trim();
    final name = (user['name'] ?? '').toString().trim();

    final ignored = _asStringList(user['ignored_usernames']);
    final authTokens = _parseAuthTokens(user['user_auth_tokens']);

    RiverSideUserEmailState emailState = const RiverSideUserEmailState(
      primaryEmail: '',
      secondaryEmails: <String>[],
      unconfirmedEmails: <String>[],
    );
    try {
      emailState = await fetchUserEmails(
        username: usernameFromPayload,
        cookieHeader: cookie,
      );
    } catch (_) {
      // Some sites may disable email endpoints for non-staff users.
    }

    return RiverSideAccountSettingsSnapshot(
      username: usernameFromPayload,
      userId: _asInt(user['id']),
      displayName: name,
      title: (user['title'] ?? '').toString().trim(),
      bioRaw: (user['bio_raw'] ?? '').toString().trim(),
      hideProfile: _asBool(userOption['hide_profile']),
      hidePresence: _asBool(userOption['hide_presence']),
      canEdit: _asBool(user['can_edit']),
      canEditName: _asBool(user['can_edit_name']),
      canEditEmail: _asBool(user['can_edit_email']),
      canChangeBio: _asBool(user['can_change_bio']),
      canIgnoreUsers: _asBool(user['can_ignore_users']),
      ignoredUsernames: ignored,
      authTokens: authTokens,
      emailState: emailState,
    );
  }

  Future<RiverSideUserEmailState> fetchUserEmails({
    required String username,
    required String cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded/emails.json'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/emails'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.get(
        uri,
        headers: _buildJsonHeaders(cookieHeader: cookie),
      );

      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode != 200) {
        lastError = RiverSideApiException(
          'Failed to load email settings, HTTP ${response.statusCode}',
        );
        continue;
      }

      final decoded = _decodeJsonObject(
        response,
        fallbackMessage: 'Invalid email settings response format',
      );
      return RiverSideUserEmailState(
        primaryEmail: (decoded['email'] ?? '').toString().trim(),
        secondaryEmails: _asStringList(decoded['secondary_emails']),
        unconfirmedEmails: _asStringList(decoded['unconfirmed_emails']),
      );
    }

    throw lastError ??
        const RiverSideApiException('Email settings endpoint is unavailable.');
  }

  Future<void> updateUserEmail({
    required String username,
    required String email,
    required String cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    final targetEmail = email.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (targetEmail.isEmpty) {
      throw const RiverSideApiException('Email is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/email.json'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/email'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.put(
        uri,
        headers: _buildFormHeaders(cookie: cookie, csrf: csrf, referer: uri),
        body: <String, String>{'email': targetEmail},
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '邮箱更新失败。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to update email, HTTP ${response.statusCode}',
      );
    }
    throw lastError ??
        const RiverSideApiException('Email endpoint is unavailable.');
  }

  Future<void> addSecondaryEmail({
    required String username,
    required String email,
    required String cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    final targetEmail = email.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (targetEmail.isEmpty) {
      throw const RiverSideApiException('Email is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/email.json'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/email'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.post(
        uri,
        headers: _buildFormHeaders(cookie: cookie, csrf: csrf, referer: uri),
        body: <String, String>{'email': targetEmail},
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '添加备用邮箱失败。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to add secondary email, HTTP ${response.statusCode}',
      );
    }
    throw lastError ??
        const RiverSideApiException('Secondary email endpoint is unavailable.');
  }

  Future<List<RiverSideTitleBadgeOption>> fetchTitleBadgeOptions({
    required String username,
    required String cookieHeader,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/user-badges/$encoded.json'),
      Uri.parse('$riverSideBaseUrl/user-badges/$encoded'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.get(
        uri,
        headers: _buildJsonHeaders(cookieHeader: cookie),
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode != 200) {
        lastError = RiverSideApiException(
          'Failed to load title badges, HTTP ${response.statusCode}',
        );
        continue;
      }

      final decoded = _decodeJsonObject(
        response,
        fallbackMessage: 'Invalid title badge response format',
      );
      final userBadgesRaw = decoded['user_badges'];
      if (userBadgesRaw is! List) {
        return const <RiverSideTitleBadgeOption>[];
      }

      // Discourse response commonly places badge details in top-level `badges`
      // and user_badges only carries `badge_id`.
      final badgesById = <int, Map<String, dynamic>>{};
      final badgesRaw = decoded['badges'];
      if (badgesRaw is List) {
        for (final rawBadge in badgesRaw) {
          final badge = _toStringMap(rawBadge);
          final badgeId = _asInt(badge['id']);
          if (badgeId == null) {
            continue;
          }
          badgesById[badgeId] = badge;
        }
      }

      final result = <RiverSideTitleBadgeOption>[];
      for (final raw in userBadgesRaw) {
        final userBadge = _toStringMap(raw);
        final userBadgeId = _asInt(userBadge['id']);
        if (userBadgeId == null) {
          continue;
        }

        // Compatibility with both payload styles:
        // 1) user_badges[i].badge (nested)
        // 2) user_badges[i].badge_id + top-level badges[]
        final nestedBadge = _toStringMap(userBadge['badge']);
        final linkedBadge =
            badgesById[_asInt(userBadge['badge_id']) ?? 0] ??
            const <String, dynamic>{};
        final badge = nestedBadge.isNotEmpty ? nestedBadge : linkedBadge;
        if (badge.isEmpty || !_asBool(badge['allow_title'])) {
          continue;
        }

        final badgeId = _asInt(badge['id']) ?? 0;
        final name = (badge['display_name'] ?? badge['name'] ?? '')
            .toString()
            .trim();
        if (name.isEmpty) {
          continue;
        }
        result.add(
          RiverSideTitleBadgeOption(
            userBadgeId: userBadgeId,
            badgeId: badgeId,
            name: name,
            icon: (badge['icon'] ?? '').toString().trim(),
            imageUrl: _normalizeMaybeRelativeUrl(
              (badge['image_url'] ?? '').toString().trim(),
            ),
            description: _sanitizeExcerpt(
              (badge['description'] ?? '').toString(),
            ),
            grantedAt: DateTime.tryParse(
              (userBadge['granted_at'] ?? '').toString(),
            ),
          ),
        );
      }

      result.sort((a, b) {
        final ta = a.grantedAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.grantedAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return result;
    }

    throw lastError ??
        const RiverSideApiException('Title badge endpoint is unavailable.');
  }

  Future<void> updateBadgeTitle({
    required String username,
    required String cookieHeader,
    required int userBadgeId,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/badge_title'),
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/badge_title.json'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.put(
        uri,
        headers: _buildFormHeaders(cookie: cookie, csrf: csrf, referer: uri),
        body: <String, String>{'user_badge_id': '$userBadgeId'},
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '头衔更新失败。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to update badge title, HTTP ${response.statusCode}',
      );
    }
    throw lastError ??
        const RiverSideApiException('Badge title endpoint is unavailable.');
  }

  Future<void> updateUserProfileSettings({
    required String username,
    required String cookieHeader,
    String? displayName,
    String? title,
    String? bioRaw,
    bool? hideProfile,
    bool? hidePresence,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final payload = <String, String>{};
    if (displayName != null) {
      payload['name'] = displayName.trim();
    }
    if (title != null) {
      payload['title'] = title.trim();
    }
    if (bioRaw != null) {
      payload['bio_raw'] = bioRaw.trim();
    }
    if (hideProfile != null) {
      payload['hide_profile'] = hideProfile ? 'true' : 'false';
    }
    if (hidePresence != null) {
      payload['hide_presence'] = hidePresence ? 'true' : 'false';
    }
    if (payload.isEmpty) {
      return;
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded.json'),
      Uri.parse('$riverSideBaseUrl/u/$encoded'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.put(
        uri,
        headers: _buildFormHeaders(
          cookie: cookie,
          csrf: csrf,
          referer: Uri.parse('$riverSideBaseUrl/u/$encoded/preferences'),
        ),
        body: payload,
        encoding: utf8,
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '资料更新失败。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to update profile settings, HTTP ${response.statusCode}',
      );
    }
    throw lastError ??
        const RiverSideApiException('Profile update endpoint is unavailable.');
  }

  Future<void> requestPasswordReset({
    required String login,
    required String cookieHeader,
  }) async {
    final target = login.trim();
    final cookie = cookieHeader.trim();
    if (target.isEmpty) {
      throw const RiverSideApiException('Login is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/session/forgot_password.json'),
      Uri.parse('$riverSideBaseUrl/session/forgot_password'),
    ];

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.post(
        uri,
        headers: _buildFormHeaders(cookie: cookie, csrf: csrf, referer: uri),
        body: <String, String>{'login': target},
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 422 || response.statusCode == 429) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '无法发送重置邮件。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to request password reset, HTTP ${response.statusCode}',
      );
    }
    throw lastError ??
        const RiverSideApiException('Password reset endpoint is unavailable.');
  }

  Future<void> setIgnoredUserState({
    required String targetUsername,
    required bool ignore,
    required String cookieHeader,
    int? actingUserId,
    DateTime? expiringAt,
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
    final encodedTarget = Uri.encodeComponent(target);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encodedTarget/notification_level'),
      Uri.parse('$riverSideBaseUrl/u/$encodedTarget/notification_level.json'),
    ];
    final expireAtValue =
        expiringAt ?? DateTime.now().toUtc().add(const Duration(days: 365 * 2));
    final body = <String, String>{
      'notification_level': ignore ? 'ignore' : 'normal',
      if (ignore) 'expiring_at': expireAtValue.toIso8601String(),
      if (actingUserId != null) 'acting_user_id': '$actingUserId',
    };

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.put(
        uri,
        headers: _buildFormHeaders(
          cookie: cookie,
          csrf: csrf,
          referer: Uri.parse('$riverSideBaseUrl/u/$encodedTarget'),
        ),
        body: body,
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(
          message.isEmpty ? (ignore ? '忽略用户失败。' : '取消忽略失败。') : message,
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to update ignore state, HTTP ${response.statusCode}',
      );
    }

    throw lastError ??
        const RiverSideApiException('Ignore state endpoint is unavailable.');
  }

  Future<void> revokeAuthToken({
    required String username,
    required String cookieHeader,
    int? tokenId,
  }) async {
    final resolvedUsername = username.trim();
    final cookie = cookieHeader.trim();
    if (resolvedUsername.isEmpty) {
      throw const RiverSideApiException('Username is empty.');
    }
    if (cookie.isEmpty) {
      throw const RiverSideApiException('Cookie header is empty.');
    }

    final csrf = await fetchSessionCsrfToken(cookieHeader: cookie);
    final encoded = Uri.encodeComponent(resolvedUsername);
    final candidates = <Uri>[
      Uri.parse('$riverSideBaseUrl/u/$encoded/preferences/revoke-auth-token'),
      Uri.parse(
        '$riverSideBaseUrl/u/$encoded/preferences/revoke-auth-token.json',
      ),
    ];

    final body = <String, String>{
      if (tokenId != null && tokenId > 0) 'token_id': '$tokenId',
    };

    RiverSideApiException? lastError;
    for (final uri in candidates) {
      final response = await http.post(
        uri,
        headers: _buildFormHeaders(
          cookie: cookie,
          csrf: csrf,
          referer: Uri.parse(
            '$riverSideBaseUrl/u/$encoded/preferences/account',
          ),
        ),
        body: body,
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      if (response.statusCode == 403) {
        throw const RiverSideApiException(
          'Login session expired. Please sign in again.',
        );
      }
      if (response.statusCode == 422) {
        final message = _extractErrorMessageFromResponse(response);
        throw RiverSideApiException(message.isEmpty ? '撤销设备登录失败。' : message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      lastError = RiverSideApiException(
        'Failed to revoke auth token, HTTP ${response.statusCode}',
      );
    }

    throw lastError ??
        const RiverSideApiException(
          'Revoke auth token endpoint is unavailable.',
        );
  }

  List<String> _asStringList(dynamic source) {
    if (source is! List) {
      return const <String>[];
    }
    final values = <String>[];
    for (final item in source) {
      final value = '$item'.trim();
      if (value.isEmpty || value.toLowerCase() == 'null') {
        continue;
      }
      values.add(value);
    }
    return values;
  }

  List<RiverSideUserAuthToken> _parseAuthTokens(dynamic source) {
    if (source is! List) {
      return const <RiverSideUserAuthToken>[];
    }
    final tokens = <RiverSideUserAuthToken>[];
    for (final item in source) {
      final map = _toStringMap(item);
      final id = _asInt(map['id']);
      if (id == null) {
        continue;
      }
      tokens.add(
        RiverSideUserAuthToken(
          id: id,
          clientIp: (map['client_ip'] ?? '').toString().trim(),
          location: (map['location'] ?? '').toString().trim(),
          browser: (map['browser'] ?? '').toString().trim(),
          device: (map['device'] ?? '').toString().trim(),
          os: (map['os'] ?? '').toString().trim(),
          icon: (map['icon'] ?? '').toString().trim(),
          createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
          seenAt: DateTime.tryParse((map['seen_at'] ?? '').toString()),
          isActive: _asBool(map['is_active']),
        ),
      );
    }

    tokens.sort((a, b) {
      final ta = (a.seenAt ?? a.createdAt)?.millisecondsSinceEpoch ?? 0;
      final tb = (b.seenAt ?? b.createdAt)?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return tokens;
  }

  Map<String, String> _buildFormHeaders({
    required String cookie,
    required String csrf,
    required Uri referer,
  }) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Cookie': cookie,
      'X-CSRF-Token': csrf,
      'X-Requested-With': 'XMLHttpRequest',
      'Origin': riverSideBaseUrl,
      'Referer': referer.toString(),
    };
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
