import 'dart:convert';

import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RiverSideSessionReader {
  const RiverSideSessionReader(this._controller, this._apiClient);

  final WebViewController _controller;
  final RiverSideApiClient _apiClient;

  Future<String?> readCurrentUsername() async {
    final profile = await readCurrentProfile();
    return profile?.username;
  }

  Future<UserAccount?> readCurrentProfile() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        _profileScript,
      );
      final profile = _normalizeJsonMap(raw);
      if (profile == null) {
        return null;
      }

      final username = (profile['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        return null;
      }

      final name = (profile['name'] ?? '').toString().trim();
      final displayName = name.isEmpty ? username : name;
      final avatarTemplate = (profile['avatar_template'] ?? '').toString();
      final title = (profile['title'] ?? '').toString().trim();

      return UserAccount(
        provider: AccountProvider.riverSide,
        userId: _asInt(profile['id']),
        username: username,
        displayName: displayName,
        avatarUrl: _apiClient.normalizeAvatarUrl(avatarTemplate),
        title: title,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _normalizeJsonMap(Object? raw) {
    if (raw == null) {
      return null;
    }

    dynamic value = raw;
    if (value is String) {
      value = value.trim();
      if (value.isEmpty || value == 'null' || value == 'undefined') {
        return null;
      }

      value = _decodeJsonLenient(value);
    }

    if (value is String) {
      value = _decodeJsonLenient(value);
    }

    if (value is! Map) {
      return null;
    }

    return value.map((key, item) => MapEntry('$key', item));
  }

  dynamic _decodeJsonLenient(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      if ((source.startsWith('"') && source.endsWith('"')) ||
          (source.startsWith("'") && source.endsWith("'"))) {
        return source.substring(1, source.length - 1);
      }
      return source;
    }
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

  static const String _profileScript = r'''
(() => {
  const pickText = (value) => typeof value === 'string' ? value.trim() : '';

  const fromDiscourseCurrent = () => {
    try {
      if (!window.Discourse || !window.Discourse.User || typeof window.Discourse.User.current !== 'function') {
        return null;
      }
      const user = window.Discourse.User.current();
      if (!user) {
        return null;
      }
      return {
        id: user.id ?? null,
        username: pickText(user.username),
        name: pickText(user.name),
        avatar_template: pickText(user.avatar_template),
        title: pickText(user.title),
      };
    } catch (_) {
      return null;
    }
  };

  const fromMeta = () => {
    try {
      const usernameMeta = document.querySelector('meta[name="discourse_current_username"]');
      if (!usernameMeta) {
        return null;
      }
      return {
        username: pickText(usernameMeta.getAttribute('content')),
      };
    } catch (_) {
      return null;
    }
  };

  const fromPath = () => {
    try {
      const path = pickText(window.location && window.location.pathname);
      const match = path.match(/^\/u\/([^\/?#]+)/i);
      if (!match || !match[1]) {
        return null;
      }
      return {
        username: decodeURIComponent(match[1]),
      };
    } catch (_) {
      return null;
    }
  };

  const merge = (...objs) => {
    const out = {};
    for (const obj of objs) {
      if (!obj) continue;
      for (const key of Object.keys(obj)) {
        const value = obj[key];
        if (value !== null && value !== undefined && value !== '') {
          out[key] = value;
        }
      }
    }
    return out;
  };

  const base = merge(fromPath(), fromMeta(), fromDiscourseCurrent());
  const username = pickText(base.username);
  if (!username) {
    return JSON.stringify(null);
  }

  // 在 WebView 登录态内用同源请求尝试补全用户资料（携带 cookie）。
  try {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', `/u/${encodeURIComponent(username)}.json`, false);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.send(null);

    if (xhr.status === 200 && xhr.responseText) {
      const payload = JSON.parse(xhr.responseText);
      if (payload && payload.user) {
        const user = payload.user;
        return JSON.stringify(merge(base, {
          id: user.id ?? null,
          username: pickText(user.username),
          name: pickText(user.name),
          avatar_template: pickText(user.avatar_template),
          title: pickText(user.title),
        }));
      }
    }
  } catch (_) {
    // 忽略，回退到页面内可读信息。
  }

  return JSON.stringify(base);
})();
''';
}
