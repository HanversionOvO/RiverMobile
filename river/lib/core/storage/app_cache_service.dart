import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CacheCategoryInfo {
  const CacheCategoryInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.path,
    required this.bytes,
  });

  final String id;
  final String title;
  final String description;
  final String path;
  final int bytes;
}

class CacheEntryInfo {
  const CacheEntryInfo({
    required this.name,
    required this.path,
    required this.bytes,
    required this.isDirectory,
    this.modifiedAt,
  });

  final String name;
  final String path;
  final int bytes;
  final bool isDirectory;
  final DateTime? modifiedAt;
}

class CacheOverview {
  const CacheOverview({required this.totalBytes, required this.categories});

  final int totalBytes;
  final List<CacheCategoryInfo> categories;
}

class AppCacheService {
  const AppCacheService._();

  static const String imageDiskCacheCategoryId = 'image_disk_cache';
  static const String imageMemoryCacheCategoryId = 'image_memory_cache';
  static const String tempCacheCategoryId = 'temp_cache';
  static const String appCacheCategoryId = 'app_cache';

  static Future<int> calculateCacheBytes() async {
    final overview = await loadCacheOverview();
    return overview.totalBytes;
  }

  static Future<CacheOverview> loadCacheOverview() async {
    final directories = await _cacheDirectories();
    final tempPath = _normalizePath((await getTemporaryDirectory()).path);
    final imageCacheDir = await _imageCacheDirectory();
    final imagePath = imageCacheDir?.path;

    final categories = <CacheCategoryInfo>[];
    final usedPaths = <String>{};

    if (imagePath != null) {
      final imageBytes = await _imageCacheBytes();
      categories.add(
        CacheCategoryInfo(
          id: imageDiskCacheCategoryId,
          title: '图片磁盘缓存',
          description: '帖子图片、头像和缩略图（磁盘）',
          path: imagePath,
          bytes: imageBytes,
        ),
      );
      usedPaths.add(_normalizePath(imagePath));
    }

    categories.add(
      CacheCategoryInfo(
        id: imageMemoryCacheCategoryId,
        title: '图片内存缓存',
        description: '当前会话图片解码缓存（内存）',
        path: 'memory://image-cache',
        bytes: _memoryImageCacheBytes(),
      ),
    );

    for (final directory in directories) {
      final normalized = _normalizePath(directory.path);
      if (usedPaths.contains(normalized)) {
        continue;
      }

      final id = normalized == tempPath
          ? tempCacheCategoryId
          : appCacheCategoryId;
      final title = id == tempCacheCategoryId ? '临时缓存' : '应用缓存';
      final description = id == tempCacheCategoryId
          ? '临时文件与下载缓存'
          : '应用级缓存与网络响应';
      final bytes = await _directorySize(directory, ignoredRoots: usedPaths);

      categories.add(
        CacheCategoryInfo(
          id: id,
          title: title,
          description: description,
          path: directory.path,
          bytes: bytes,
        ),
      );
      usedPaths.add(normalized);
    }

    final total = categories.fold<int>(
      0,
      (sum, category) => sum + category.bytes,
    );
    return CacheOverview(totalBytes: total, categories: categories);
  }

  static Future<void> clearCache() async {
    await clearImageDiskCache();
    clearImageMemoryCache();
    final directories = await _cacheDirectories();
    for (final directory in directories) {
      await _clearDirectoryChildren(directory);
    }
  }

  static Future<void> clearImageDiskCache() async {
    await DefaultCacheManager().emptyCache();
  }

  static void clearImageMemoryCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static Future<void> clearImageCache() async {
    await clearImageDiskCache();
    clearImageMemoryCache();
  }

  static Future<void> clearCategory(String categoryId) async {
    if (categoryId == imageDiskCacheCategoryId) {
      await clearImageDiskCache();
      return;
    }
    if (categoryId == imageMemoryCacheCategoryId) {
      clearImageMemoryCache();
      return;
    }

    final overview = await loadCacheOverview();
    final target = overview.categories.firstWhere(
      (item) => item.id == categoryId,
      orElse: () => const CacheCategoryInfo(
        id: '',
        title: '',
        description: '',
        path: '',
        bytes: 0,
      ),
    );
    if (target.id.isEmpty || target.path.isEmpty) {
      return;
    }
    await _clearDirectoryChildren(Directory(target.path));
  }

  static Future<List<CacheEntryInfo>> listTopEntries({
    required String categoryPath,
    int limit = 30,
  }) async {
    final directory = Directory(categoryPath);
    if (!await directory.exists()) {
      return const <CacheEntryInfo>[];
    }

    final result = <CacheEntryInfo>[];
    await for (final entity in directory.list(followLinks: false)) {
      final isDir = entity is Directory;
      final bytes = isDir
          ? await _directorySize(entity)
          : entity is File
          ? await _fileSize(entity)
          : 0;
      DateTime? modifiedAt;
      try {
        modifiedAt = await entity.stat().then((s) => s.modified);
      } catch (_) {
        // Ignore stat failures.
      }
      result.add(
        CacheEntryInfo(
          name: _entityName(entity.path),
          path: entity.path,
          bytes: bytes,
          isDirectory: isDir,
          modifiedAt: modifiedAt,
        ),
      );
    }

    result.sort((a, b) => b.bytes.compareTo(a.bytes));
    return result.take(limit).toList();
  }

  static Future<List<Directory>> _cacheDirectories() async {
    final result = <Directory>[];

    final temp = await getTemporaryDirectory();
    result.add(temp);

    try {
      final appCache = await getApplicationCacheDirectory();
      if (_normalizePath(appCache.path) != _normalizePath(temp.path)) {
        result.add(appCache);
      }
    } catch (_) {
      // Ignore unsupported platforms.
    }

    return result;
  }

  static Future<Directory?> _imageCacheDirectory() async {
    try {
      final temp = await getTemporaryDirectory();
      final key = DefaultCacheManager().store.storeKey;
      final path = '${temp.path}${Platform.pathSeparator}$key';
      return Directory(path);
    } catch (_) {
      return null;
    }
  }

  static Future<int> _imageCacheBytes() async {
    try {
      return await DefaultCacheManager().store.getCacheSize();
    } catch (_) {
      return 0;
    }
  }

  static int _memoryImageCacheBytes() {
    try {
      return PaintingBinding.instance.imageCache.currentSizeBytes;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _directorySize(
    Directory directory, {
    Set<String> ignoredRoots = const <String>{},
  }) async {
    if (!await directory.exists()) {
      return 0;
    }

    final ignored = ignoredRoots.map(_normalizePath).toSet();
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final normalized = _normalizePath(entity.path);
      if (_isIgnored(normalized, ignored)) {
        continue;
      }
      total += await _fileSize(entity);
    }
    return total;
  }

  static bool _isIgnored(String filePath, Set<String> ignoredRoots) {
    for (final root in ignoredRoots) {
      if (filePath == root ||
          filePath.startsWith('$root${Platform.pathSeparator}')) {
        return true;
      }
    }
    return false;
  }

  static Future<int> _fileSize(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
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

  static String _normalizePath(String path) {
    return path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  }

  static String _entityName(String path) {
    final normalized = _normalizePath(path);
    final segments = normalized
        .split('/')
        .where((it) => it.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return path;
    }
    return segments.last;
  }
}
