import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';

class RiverSideApiClient {
  Future<UserAccount> fetchUserProfile(String username) async {
    final uri = Uri.parse('$riverSideBaseUrl/u/$username.json');
    final response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        '接口返回 403：该端点需要登录态或 API Key。请先通过 RiverSide 登录后自动同步账号。',
      );
    }

    if (response.statusCode != 200) {
      throw RiverSideApiException('拉取失败，HTTP ${response.statusCode}');
    }

    late final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('root is not map');
      }
      data = decoded;
    } on FormatException {
      throw const RiverSideApiException('返回数据格式异常');
    }

    final userRaw = data['user'];
    if (userRaw is! Map) {
      throw const RiverSideApiException('未找到用户信息');
    }

    final user = userRaw.map((key, value) => MapEntry('$key', value));
    final usernameFromApi = (user['username'] ?? username).toString().trim();
    if (usernameFromApi.isEmpty) {
      throw const RiverSideApiException('用户信息不完整');
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

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class RiverSideApiException implements Exception {
  const RiverSideApiException(this.message);

  final String message;
}
