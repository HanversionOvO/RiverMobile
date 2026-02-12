import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';

class RiverSideCategoryStore {
  RiverSideCategoryStore._();

  static final RiverSideCategoryStore instance = RiverSideCategoryStore._();

  final Map<String, List<RiverSideCategoryOption>> _cacheByUser =
      <String, List<RiverSideCategoryOption>>{};
  final Map<String, Future<List<RiverSideCategoryOption>>> _inflightByUser =
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

  Future<List<RiverSideCategoryOption>> load({
    required RiverSideApiClient apiClient,
    required String? username,
    String? cookieHeader,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(username);

    if (!forceRefresh) {
      final cached = _cacheByUser[key];
      if (cached != null) {
        return cached;
      }
      final inflight = _inflightByUser[key];
      if (inflight != null) {
        return inflight;
      }
    }

    final future = apiClient
        .fetchCategories(cookieHeader: cookieHeader)
        .then((items) {
          final snapshot = List<RiverSideCategoryOption>.unmodifiable(items);
          _cacheByUser[key] = snapshot;
          return snapshot;
        })
        .whenComplete(() {
          _inflightByUser.remove(key);
        });

    _inflightByUser[key] = future;
    return future;
  }

  void clear({String? username}) {
    if (username == null) {
      _cacheByUser.clear();
      _inflightByUser.clear();
      return;
    }
    final key = _cacheKey(username);
    _cacheByUser.remove(key);
    _inflightByUser.remove(key);
  }
}
