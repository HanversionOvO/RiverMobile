part of 'riverside_api_client.dart';

extension RiverSideApiClientCategoryEmojiMethods on RiverSideApiClient {
  Future<List<RiverSideCategoryOption>> fetchCategories({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final categoriesUri = Uri.parse('$riverSideBaseUrl/categories.json')
        .replace(
          queryParameters: const <String, String>{
            'include_subcategories': 'true',
          },
        );
    final response = await http.get(
      categoriesUri,
      headers: _buildJsonHeaders(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );

    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load categories, HTTP ${response.statusCode}',
      );
    }

    final decoded = _decodeJsonObject(
      response,
      fallbackMessage: 'Invalid categories response format',
    );

    final categoryList = _toStringMap(decoded['category_list']);
    final categoriesRaw = categoryList['categories'];
    if (categoriesRaw is! List) {
      return const <RiverSideCategoryOption>[];
    }

    final rawById = <int, Map<String, dynamic>>{};
    for (final raw in categoriesRaw) {
      final map = _toStringMap(raw);
      final id = _asInt(map['id']);
      if (id != null) {
        rawById[id] = map;
      }
      final subcategoryListRaw = map['subcategory_list'];
      if (subcategoryListRaw is! List) {
        continue;
      }
      for (final childRaw in subcategoryListRaw) {
        final childMap = _toStringMap(childRaw);
        final childId = _asInt(childMap['id']);
        if (childId == null) {
          continue;
        }
        rawById[childId] = <String, dynamic>{
          ...childMap,
          'parent_category_id': _asInt(childMap['parent_category_id']) ?? id,
        };
      }
    }

    final optionById = <int, RiverSideCategoryOption>{};
    for (final raw in rawById.values) {
      final option = _parseCategoryOption(raw);
      if (option != null) {
        optionById[option.id] = option;
      }
    }

    final topLevel =
        optionById.values
            .where((option) => option.parentCategoryId == null)
            .toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            if (byPosition != 0) {
              return byPosition;
            }
            return a.id.compareTo(b.id);
          });

    final ordered = <RiverSideCategoryOption>[];
    for (final parent in topLevel) {
      ordered.add(parent);
      final children =
          optionById.values
              .where((option) => option.parentCategoryId == parent.id)
              .toList()
            ..sort((a, b) {
              final byPosition = a.position.compareTo(b.position);
              if (byPosition != 0) {
                return byPosition;
              }
              return a.id.compareTo(b.id);
            });
      ordered.addAll(children);
    }

    final already = ordered.map((item) => item.id).toSet();
    final orphans =
        optionById.values.where((item) => !already.contains(item.id)).toList()
          ..sort((a, b) {
            final byPosition = a.position.compareTo(b.position);
            if (byPosition != 0) {
              return byPosition;
            }
            return a.id.compareTo(b.id);
          });
    ordered.addAll(orphans);

    final cacheKey = _categoryCacheKey(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    _categoryOptionCacheByCookieKey[cacheKey] = <int, RiverSideCategoryOption>{
      for (final item in ordered) item.id: item,
    };
    _categoryNameCacheByCookieKey[cacheKey] = _buildCategoryNameMap(ordered);
    return ordered;
  }

  Future<Map<String, String>> fetchEmojiUrlMap({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cacheKey = _categoryCacheKey(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    await _ensureEmojiCaches(
      cacheKey: cacheKey,
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    return _emojiUrlCacheByCookieKey[cacheKey] ?? const <String, String>{};
  }

  Future<Map<String, List<String>>> fetchEmojiGroups({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cacheKey = _categoryCacheKey(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    await _ensureEmojiCaches(
      cacheKey: cacheKey,
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    return _emojiGroupsCacheByCookieKey[cacheKey] ??
        const <String, List<String>>{};
  }

  Future<void> _ensureEmojiCaches({
    required String cacheKey,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cachedUrls = _emojiUrlCacheByCookieKey[cacheKey];
    final cachedGroups = _emojiGroupsCacheByCookieKey[cacheKey];
    if (cachedUrls != null &&
        cachedUrls.isNotEmpty &&
        cachedGroups != null &&
        cachedGroups.isNotEmpty) {
      return;
    }

    final response = await http.get(
      Uri.parse('$riverSideBaseUrl/emojis.json'),
      headers: _buildJsonHeaders(
        cookieHeader: cookieHeader,
        userApiKey: userApiKey,
        userApiClientId: userApiClientId,
      ),
    );
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to load emojis, HTTP ${response.statusCode}',
      );
    }

    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const RiverSideApiException('Invalid emojis response format');
    }

    final result = <String, String>{};
    final groups = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final list = entry.value;
      if (list is! List) {
        continue;
      }
      final categoryName = '${entry.key}'.trim();
      final groupKey = categoryName.isEmpty ? 'default' : categoryName;
      final groupNames = groups.putIfAbsent(groupKey, () => <String>[]);
      for (final rawEmoji in list) {
        final emoji = _toStringMap(rawEmoji);
        final name = (emoji['name'] ?? '').toString().trim();
        final url = _normalizeEmojiUrl((emoji['url'] ?? '').toString());
        if (name.isEmpty || url.isEmpty) {
          continue;
        }
        result[name] = url;
        result[name.toLowerCase()] = url;
        if (!groupNames.contains(name)) {
          groupNames.add(name);
        }

        final aliases = emoji['search_aliases'];
        if (aliases is List) {
          for (final rawAlias in aliases) {
            final alias = '$rawAlias'.trim();
            if (alias.isEmpty) {
              continue;
            }
            result.putIfAbsent(alias, () => url);
            result.putIfAbsent(alias.toLowerCase(), () => url);
          }
        }
      }
    }

    for (final entry in groups.entries) {
      entry.value.sort((a, b) => a.compareTo(b));
    }
    _emojiUrlCacheByCookieKey[cacheKey] = result;
    _emojiGroupsCacheByCookieKey[cacheKey] = groups;
  }

  Future<Map<int, RiverSideCategoryOption>> _loadCategoryOptionMap({
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    final cache =
        _categoryOptionCacheByCookieKey[_categoryCacheKey(
          cookieHeader: cookieHeader,
          userApiKey: userApiKey,
          userApiClientId: userApiClientId,
        )];
    if (cache != null && cache.isNotEmpty) {
      return cache;
    }

    final options = await fetchCategories(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    return <int, RiverSideCategoryOption>{
      for (final item in options) item.id: item,
    };
  }

  Map<int, String> _buildCategoryNameMap(
    List<RiverSideCategoryOption> options,
  ) {
    final byId = <int, RiverSideCategoryOption>{
      for (final item in options) item.id: item,
    };
    final names = <int, String>{};
    for (final option in options) {
      final parentId = option.parentCategoryId;
      if (parentId == null) {
        names[option.id] = option.name;
        continue;
      }

      final parent = byId[parentId];
      names[option.id] = parent == null
          ? option.name
          : '${parent.name} / ${option.name}';
    }
    return names;
  }

  RiverSideCategoryOption? _parseCategoryOption(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']);
    final name = (raw['name'] ?? '').toString().trim();
    if (id == null || name.isEmpty) {
      return null;
    }

    return RiverSideCategoryOption(
      id: id,
      name: name,
      position: _asInt(raw['position']) ?? 9999,
      parentCategoryId: _asInt(raw['parent_category_id']),
      description: (raw['description_text'] ?? '').toString().trim(),
    );
  }

  Future<Uri> _buildTopicUri({
    required RiverSideTopicFeed feed,
    required int page,
    required int? categoryId,
    String? cookieHeader,
    String? userApiKey,
    String? userApiClientId,
  }) async {
    if (categoryId == null) {
      return feed.uri(page: page);
    }

    final optionsById = await _loadCategoryOptionMap(
      cookieHeader: cookieHeader,
      userApiKey: userApiKey,
      userApiClientId: userApiClientId,
    );
    final option = optionsById[categoryId];
    final categoryPath = option == null
        ? '/c/$categoryId'
        : option.parentCategoryId == null
        ? '/c/${option.id}'
        : '/c/${option.parentCategoryId}/${option.id}';

    switch (feed) {
      case RiverSideTopicFeed.latestCreated:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/latest.json?filter=latest&order=created&page=$page',
        );
      case RiverSideTopicFeed.latestReplied:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/latest.json?filter=latest&page=$page',
        );
      case RiverSideTopicFeed.hot:
        return Uri.parse(
          '$riverSideBaseUrl$categoryPath/l/hot.json?page=$page',
        );
    }
  }
}
