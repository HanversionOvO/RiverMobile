import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';

class RiverSidePasswordLoginService {
  const RiverSidePasswordLoginService({required RiverSideApiClient apiClient})
    : _apiClient = apiClient;

  final RiverSideApiClient _apiClient;

  Future<RiverSidePasswordLoginResult> login({
    required String login,
    required String password,
  }) async {
    final loginValue = login.trim();
    final passwordValue = password;
    if (loginValue.isEmpty || passwordValue.isEmpty) {
      throw const RiverSidePasswordLoginException(
        'Account and password are required.',
      );
    }

    final cookieJar = <String, String>{};
    final about = await _getAbout(
      cookieHeader: _cookieHeaderFromJar(cookieJar),
    );
    _mergeSetCookieHeader(cookieJar, about.setCookieHeader);
    final version = (_toMap(about.payload['about'])['version'] ?? '')
        .toString();

    final csrfResponse = await _getCsrf(
      cookieHeader: _cookieHeaderFromJar(cookieJar),
    );
    _mergeSetCookieHeader(cookieJar, csrfResponse.setCookieHeader);
    final csrfToken = csrfResponse.csrf.trim();
    if (csrfToken.isEmpty) {
      throw const RiverSidePasswordLoginException(
        'Failed to obtain CSRF token.',
      );
    }

    final isLegacy25 = version.startsWith('2.5');

    final loginResponse = await _postSessionLogin(
      isLegacy25: isLegacy25,
      csrfToken: csrfToken,
      login: loginValue,
      password: passwordValue,
      cookieHeader: _cookieHeaderFromJar(cookieJar),
    );
    _mergeSetCookieHeader(cookieJar, loginResponse.setCookieHeader);

    final error = _readErrorMessage(loginResponse.payload);
    if (error != null && error.isNotEmpty) {
      throw RiverSidePasswordLoginException(error);
    }

    final finalCookieHeader = _cookieHeaderFromJar(cookieJar);
    if (finalCookieHeader.isEmpty) {
      throw const RiverSidePasswordLoginException(
        'Login succeeded but session cookie was not returned.',
      );
    }

    final profile = await _apiClient.fetchCurrentUserByCookie(
      cookieHeader: finalCookieHeader,
      fallbackLogin: loginValue,
    );

    return RiverSidePasswordLoginResult(
      profile: profile,
      cookieHeader: finalCookieHeader,
    );
  }

  Future<_AboutResponse> _getAbout({required String cookieHeader}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/about.json'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw RiverSidePasswordLoginException(
        'Failed to load site info, HTTP ${response.statusCode}',
      );
    }

    return _AboutResponse(
      payload: _decodeJsonObject(
        response,
        fallback: 'Site info response invalid.',
      ),
      setCookieHeader: response.headers['set-cookie'],
    );
  }

  Future<_CsrfResponse> _getCsrf({required String cookieHeader}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-CSRF-Token': 'undefined',
      'Referer': riverSideBaseUrl,
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/session/csrf'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw RiverSidePasswordLoginException(
        'Failed to load CSRF token, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallback: 'CSRF response invalid.',
    );

    return _CsrfResponse(
      csrf: (decoded['csrf'] ?? '').toString(),
      setCookieHeader: response.headers['set-cookie'],
    );
  }

  Future<_SessionLoginResponse> _postSessionLogin({
    required bool isLegacy25,
    required String csrfToken,
    required String login,
    required String password,
    required String cookieHeader,
  }) async {
    final data = <String, String>{'login': login, 'password': password};
    if (!isLegacy25) {
      data['authenticity_token'] = csrfToken;
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Origin': riverSideBaseUrl,
      'Referer': riverSideBaseUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    if (isLegacy25) {
      headers['X-CSRF-Token'] = csrfToken;
    }
    if (cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final response = await http.post(
      Uri.parse('$riverSideBaseUrl/session'),
      headers: headers,
      body: _serialize(data),
    );

    if (response.statusCode != 200) {
      final decoded = _decodeJsonObject(
        response,
        fallback: 'Login failed, HTTP ${response.statusCode}',
        softFail: true,
      );
      final errorMessage = _readErrorMessage(decoded);
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw RiverSidePasswordLoginException(errorMessage);
      }
      throw RiverSidePasswordLoginException(
        'Login failed, HTTP ${response.statusCode}',
      );
    }

    final payload = _decodeJsonObject(
      response,
      fallback: 'Login response invalid.',
    );

    return _SessionLoginResponse(
      payload: payload,
      setCookieHeader: response.headers['set-cookie'],
    );
  }

  String _serialize(Map<String, String> data) {
    return data.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  Map<String, dynamic> _decodeJsonObject(
    http.Response response, {
    required String fallback,
    bool softFail = false,
  }) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      if (softFail) {
        return const <String, dynamic>{};
      }
    } catch (_) {
      if (softFail) {
        return const <String, dynamic>{};
      }
    }
    throw RiverSidePasswordLoginException(fallback);
  }

  void _mergeSetCookieHeader(Map<String, String> jar, String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.trim().isEmpty) {
      return;
    }

    final pattern = RegExp(r'(?:^|,\s*)([A-Za-z0-9_\-]+)=([^;,\s]+)');
    for (final match in pattern.allMatches(setCookieHeader)) {
      final name = match.group(1);
      final value = match.group(2);
      if (name == null || value == null || name.isEmpty || value.isEmpty) {
        continue;
      }
      jar[name] = value;
    }
  }

  String _cookieHeaderFromJar(Map<String, String> jar) {
    if (jar.isEmpty) {
      return '';
    }
    return jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  String? _readErrorMessage(Map<String, dynamic> payload) {
    final single = (payload['error'] ?? '').toString().trim();
    if (single.isNotEmpty) {
      return single;
    }

    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      final value = errors
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .join('\n');
      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }
    return value.map((key, item) => MapEntry('$key', item));
  }
}

class RiverSidePasswordLoginResult {
  const RiverSidePasswordLoginResult({
    required this.profile,
    required this.cookieHeader,
  });

  final UserAccount profile;
  final String cookieHeader;
}

class RiverSidePasswordLoginException implements Exception {
  const RiverSidePasswordLoginException(this.message);

  final String message;
}

class _CsrfResponse {
  const _CsrfResponse({required this.csrf, required this.setCookieHeader});

  final String csrf;
  final String? setCookieHeader;
}

class _AboutResponse {
  const _AboutResponse({required this.payload, required this.setCookieHeader});

  final Map<String, dynamic> payload;
  final String? setCookieHeader;
}

class _SessionLoginResponse {
  const _SessionLoginResponse({
    required this.payload,
    required this.setCookieHeader,
  });

  final Map<String, dynamic> payload;
  final String? setCookieHeader;
}
