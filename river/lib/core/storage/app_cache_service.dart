import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class AppCacheService {
  const AppCacheService._();

  static Future<int> calculateCacheBytes() async {
    final directories = await _cacheDirectories();
    var total = 0;
    for (final directory in directories) {
      total += await _directorySize(directory);
    }
    return total;
  }

  static Future<void> clearCache() async {
    await DefaultCacheManager().emptyCache();

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();

    final directories = await _cacheDirectories();
    for (final directory in directories) {
      await _clearDirectoryChildren(directory);
    }
  }

  static Future<List<Directory>> _cacheDirectories() async {
    final result = <Directory>[];

    final temp = await getTemporaryDirectory();
    result.add(temp);

    try {
      final appCache = await getApplicationCacheDirectory();
      if (appCache.path != temp.path) {
        result.add(appCache);
      }
    } catch (_) {
      // Ignore unsupported platforms.
    }

    return result;
  }

  static Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      try {
        total += await entity.length();
      } catch (_) {
        // Skip inaccessible files.
      }
    }
    return total;
  }

  static Future<void> _clearDirectoryChildren(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // Skip delete failures.
      }
    }
  }
}
