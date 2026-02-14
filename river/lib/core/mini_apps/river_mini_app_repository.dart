import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:river/core/config/server_config.dart';
import 'package:river/core/mini_apps/river_mini_app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiverMiniAppRepository {
  RiverMiniAppRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String _cachePrefix = 'river.mini_apps.manifest.cache.';
  static const String _cacheMetaPrefix = 'river.mini_apps.manifest.meta.';

  final http.Client _httpClient;
  SharedPreferences? _prefs;

  Future<RiverMiniAppManifest> load({
    required String manifestUrl,
    String? cookieHeader,
    bool forceRefresh = false,
  }) async {
    final normalizedUrl = RiverServerConfig.normalizeUrl(manifestUrl);
    final manifestUri = Uri.parse(normalizedUrl);
    final cacheKey = _cachePrefix + _normalizeCacheKey(normalizedUrl);
    final metaKey = _cacheMetaPrefix + _normalizeCacheKey(normalizedUrl);
    _prefs ??= await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = _prefs?.getString(cacheKey);
      if (cached != null && cached.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          final parsed = _parseManifest(decoded, manifestUri);
          if (parsed.entries.isNotEmpty) {
            final cachedUpdatedAt = _prefs?.getString(metaKey) ?? '';
            return RiverMiniAppManifest(
              sourceUrl: normalizedUrl,
              entries: parsed.entries,
              version: parsed.version,
              updatedAt: cachedUpdatedAt,
            );
          }
        } catch (_) {
          // Ignore malformed cache and continue to network.
        }
      }
    }

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final cookie = cookieHeader?.trim() ?? '';
      final isForumHost = RiverServerConfig.instance.isForumHost(
        manifestUri.host,
      );
      if (isForumHost && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      final response = await _httpClient
          .get(manifestUri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      final manifest = _parseManifest(decoded, manifestUri);
      await _prefs?.setString(cacheKey, response.body);
      await _prefs?.setString(metaKey, DateTime.now().toIso8601String());
      return RiverMiniAppManifest(
        sourceUrl: normalizedUrl,
        entries: manifest.entries,
        version: manifest.version,
        updatedAt: DateTime.now().toIso8601String(),
      );
    } catch (error) {
      final cached = _prefs?.getString(cacheKey);
      if (cached != null && cached.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          final parsed = _parseManifest(decoded, manifestUri);
          final cachedUpdatedAt = _prefs?.getString(metaKey) ?? '';
          return RiverMiniAppManifest(
            sourceUrl: normalizedUrl,
            entries: parsed.entries,
            version: parsed.version,
            updatedAt: cachedUpdatedAt,
          );
        } catch (_) {
          // fallthrough
        }
      }
      throw Exception('加载小程序清单失败：$error');
    }
  }

  RiverMiniAppManifest _parseManifest(dynamic raw, Uri manifestUri) {
    final root = _toMap(raw);
    final entries =
        _parseEntries(raw: raw, root: root, manifestUri: manifestUri)
          ..sort((a, b) {
            final order = a.order.compareTo(b.order);
            if (order != 0) {
              return order;
            }
            return a.name.compareTo(b.name);
          });
    return RiverMiniAppManifest(
      sourceUrl: manifestUri.toString(),
      entries: entries.where((item) => item.enabled).toList(growable: false),
      version: _readString(root['version']),
      updatedAt: _readString(root['updated_at']),
    );
  }

  List<RiverMiniAppEntry> _parseEntries({
    required dynamic raw,
    required Map<String, dynamic> root,
    required Uri manifestUri,
  }) {
    List<dynamic> source = const <dynamic>[];
    if (raw is List) {
      source = raw;
    } else {
      source = _toList(root['apps']);
      if (source.isEmpty) {
        source = _toList(root['mini_apps']);
      }
      if (source.isEmpty) {
        source = _toList(root['miniApps']);
      }
      if (source.isEmpty) {
        source = _toList(root['data']);
      }
      if (source.isEmpty) {
        final payload = _toMap(root['payload']);
        source = _toList(payload['apps']);
      }
    }

    final result = <RiverMiniAppEntry>[];
    for (final item in source) {
      final map = _toMap(item);
      if (map.isEmpty) {
        continue;
      }
      final id = _readString(map['id'], fallback: _readString(map['app_id']));
      final name = _readString(
        map['name'],
        fallback: _readString(map['title']),
      );
      final rawUrl = _readString(
        map['url'],
        fallback: _readString(map['entry']),
      );
      final url = _resolveUrl(rawUrl, manifestUri);
      if (id.isEmpty || name.isEmpty || url.isEmpty) {
        continue;
      }
      final iconUrl = _resolveUrl(
        _readString(map['icon'], fallback: _readString(map['icon_url'])),
        manifestUri,
      );
      final tags = _toList(map['tags'])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      result.add(
        RiverMiniAppEntry(
          id: id,
          name: name,
          url: url,
          version: _readString(
            map['version'],
            fallback: _readString(map['app_version']),
          ),
          packageUrl: _resolveUrl(
            _readString(
              map['package_url'],
              fallback: _readString(
                map['packageUrl'],
                fallback: _readString(map['package']),
              ),
            ),
            manifestUri,
          ),
          packageSha256: _readString(
            map['package_sha256'],
            fallback: _readString(map['packageSha256']),
          ).toLowerCase(),
          packageBytes: _readInt(
            map['package_bytes'] ?? map['package_size'] ?? map['packageSize'],
          ),
          iconUrl: iconUrl,
          description: _readString(
            map['description'],
            fallback: _readString(map['desc']),
          ),
          tags: tags,
          requiresAuth: _readBool(
            map['requires_auth'],
            fallback: _readBool(map['requiresAuth']),
          ),
          enabled: _readBool(map['enabled'], fallback: true),
          order: _readInt(map['order']),
          bridgeVersion: _readString(
            map['bridge_version'],
            fallback: _readString(map['bridgeVersion'], fallback: '1.0.0'),
          ),
        ),
      );
    }
    return result;
  }

  Future<List<RiverMiniAppEntry>> search({
    required String manifestUrl,
    required String query,
    String? cookieHeader,
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const <RiverMiniAppEntry>[];
    }

    final normalizedUrl = RiverServerConfig.normalizeUrl(manifestUrl);
    final manifestUri = Uri.parse(normalizedUrl);
    final searchUri = manifestUri.resolve(
      '/api/miniapps/search?q=${Uri.encodeQueryComponent(q)}&limit=$limit',
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final cookie = cookieHeader?.trim() ?? '';
      if (cookie.isNotEmpty &&
          RiverServerConfig.instance.isForumHost(searchUri.host.trim())) {
        headers['Cookie'] = cookie;
      }
      final response = await _httpClient
          .get(searchUri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final root = _toMap(decoded);
        final parsed = _parseEntries(
          raw: decoded,
          root: root,
          manifestUri: manifestUri,
        );
        return parsed.take(limit.clamp(1, 200)).toList(growable: false);
      }
    } catch (_) {
      // Fallback to local filtering.
    }

    final manifest = await load(
      manifestUrl: manifestUrl,
      cookieHeader: cookieHeader,
      forceRefresh: false,
    );
    final lower = q.toLowerCase();
    final filtered = manifest.entries.where((item) {
      final haystack = <String>[
        item.id,
        item.name,
        item.description,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(lower);
    });
    return filtered.take(limit.clamp(1, 200)).toList(growable: false);
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      final result = <String, dynamic>{};
      for (final entry in raw.entries) {
        result['${entry.key}'] = entry.value;
      }
      return result;
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _toList(dynamic raw) {
    if (raw is List<dynamic>) {
      return raw;
    }
    if (raw is List) {
      return raw.cast<dynamic>();
    }
    return const <dynamic>[];
  }

  String _readString(dynamic raw, {String fallback = ''}) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return fallback;
    }
    return text;
  }

  bool _readBool(dynamic raw, {bool fallback = false}) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final text = '$raw'.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return fallback;
  }

  int _readInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse('$raw') ?? fallback;
  }

  String _resolveUrl(String source, Uri baseUri) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      return '';
    }
    if (parsed.hasScheme) {
      return parsed.toString();
    }
    return baseUri.resolveUri(parsed).toString();
  }

  String _normalizeCacheKey(String source) {
    return source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
