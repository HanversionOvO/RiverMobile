import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';

class RiverSideCategoryStore {
  RiverSideCategoryStore._();

  static final RiverSideCategoryStore instance = RiverSideCategoryStore._();

  final Map<String, List<RiverSideCategoryOption>> _cacheByUser =
      <String, List<RiverSideCategoryOption>>{};
  final Map<String, bool> _cacheAuthenticatedByUser = <String, bool>{};
  final Map<String, Future<List<RiverSideCategoryOption>>> _inflightByRequest =
      <String, Future<List<RiverSideCategoryOption>>>{};

  String _cacheKey(String? username) {
    if (username == null || username.trim().isEmpty) {
      return '__anonymous__';
    }
    return username.trim().toLowerCase();
  }

  List<RiverSideCategoryOption>? peek(String? username) {
    final key = _cacheKey(username);
    return _cacheByUser[key];
  }

  bool _hasAuthenticatedCookie(String? cookieHeader) {
    final source = cookieHeader?.trim().toLowerCase() ?? '';
    if (source.isEmpty) {
      return false;
    }
    return source.contains('_forum_session=') || source.contains('_t=');
  }

  String _requestKey({required String userKey, required bool authenticated}) {
    return '$userKey|${authenticated ? 'auth' : 'guest'}';
  }

  List<RiverSideCategoryOption> _mergeStableCategories({
    required List<RiverSideCategoryOption> existing,
    required List<RiverSideCategoryOption> incoming,
  }) {
    if (existing.isEmpty) {
      return List<RiverSideCategoryOption>.unmodifiable(incoming);
    }
    if (incoming.isEmpty) {
      return List<RiverSideCategoryOption>.unmodifiable(existing);
    }

    final incomingIds = incoming.map((item) => item.id).toSet();
    final extras =
        existing.where((item) => !incomingIds.contains(item.id)).toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            if (byPosition != 0) {
              return byPosition;
            }
            return a.id.compareTo(b.id);
          });

    return List<RiverSideCategoryOption>.unmodifiable([...incoming, ...extras]);
  }

  Future<List<RiverSideCategoryOption>> load({
    required RiverSideApiClient apiClient,
    required String? username,
    String? cookieHeader,
    bool forceRefresh = false,
  }) async {
    final userKey = _cacheKey(username);
    final hasAuthCookie = _hasAuthenticatedCookie(cookieHeader);
    final requestKey = _requestKey(
      userKey: userKey,
      authenticated: hasAuthCookie,
    );
    final cached = _cacheByUser[userKey];
    final cachedIsAuthenticated = _cacheAuthenticatedByUser[userKey] ?? false;

    if (!forceRefresh) {
      if (cached != null) {
        // 若当前请求缺少登录态，直接复用现有缓存，避免出现“回退到匿名板块”
        if (!hasAuthCookie) {
          return cached;
        }
        // 若当前请求有登录态，优先使用已认证缓存；否则继续请求升级为认证数据
        if (cachedIsAuthenticated) {
          return cached;
        }
      }
      final inflight = _inflightByRequest[requestKey];
      if (inflight != null) {
        return inflight;
      }
    } else if (!hasAuthCookie && cached != null && cachedIsAuthenticated) {
      // 手动刷新时若临时拿不到 cookie，也不允许用匿名结果覆盖已认证结果
      return cached;
    }

    final requestCookieHeader = hasAuthCookie ? cookieHeader : null;
    final future = apiClient
        .fetchCategories(cookieHeader: requestCookieHeader)
        .then((items) {
          final snapshot = List<RiverSideCategoryOption>.from(items);
          final latestCached = _cacheByUser[userKey];
          final latestCachedIsAuthenticated =
              _cacheAuthenticatedByUser[userKey] ?? false;

          // 保护：禁止匿名结果覆盖已认证缓存
          if (!hasAuthCookie &&
              latestCached != null &&
              latestCachedIsAuthenticated) {
            return latestCached;
          }

          final merged = latestCached != null
              ? _mergeStableCategories(
                  existing: latestCached,
                  incoming: snapshot,
                )
              : List<RiverSideCategoryOption>.unmodifiable(snapshot);

          _cacheByUser[userKey] = merged;
          _cacheAuthenticatedByUser[userKey] = hasAuthCookie;
          return merged;
        })
        .whenComplete(() {
          _inflightByRequest.remove(requestKey);
        });

    _inflightByRequest[requestKey] = future;
    return future;
  }

  void clear({String? username}) {
    if (username == null) {
      _cacheByUser.clear();
      _cacheAuthenticatedByUser.clear();
      _inflightByRequest.clear();
      return;
    }
    final key = _cacheKey(username);
    _cacheByUser.remove(key);
    _cacheAuthenticatedByUser.remove(key);
    _inflightByRequest.remove(_requestKey(userKey: key, authenticated: true));
    _inflightByRequest.remove(_requestKey(userKey: key, authenticated: false));
  }
}
