import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:river/core/config/server_config.dart';
import 'package:river/core/mini_apps/river_mini_app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiverMiniAppInstallStore {
  RiverMiniAppInstallStore();

  static const String _installedAppsKey = 'river.mini_apps.installed.apps.v1';
  static const int _downloadMaxRetries = 5;

  SharedPreferences? _prefs;

  Future<List<RiverMiniAppEntry>> loadInstalledApps() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_installedAppsKey) ?? '';
    if (raw.trim().isEmpty) {
      return const <RiverMiniAppEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <RiverMiniAppEntry>[];
      }
      final result = <RiverMiniAppEntry>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final map = <String, dynamic>{};
        for (final entry in item.entries) {
          map['${entry.key}'] = entry.value;
        }
        final entry = RiverMiniAppEntry.fromJson(map);
        if (entry.id.isEmpty || entry.localEntryFilePath.isEmpty) {
          continue;
        }
        result.add(entry);
      }
      result.sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        if (orderCmp != 0) {
          return orderCmp;
        }
        return a.name.compareTo(b.name);
      });
      return result;
    } catch (_) {
      return const <RiverMiniAppEntry>[];
    }
  }

  Future<RiverMiniAppEntry> install({
    required RiverMiniAppEntry app,
    String? cookieHeader,
  }) async {
    final packageUrl = app.packageUrl.trim();
    if (packageUrl.isEmpty) {
      throw Exception('小程序未提供可安装包(package_url)');
    }

    final packageUri = Uri.tryParse(packageUrl);
    if (packageUri == null) {
      throw Exception('小程序安装包地址无效');
    }

    final headers = <String, String>{'Accept': '*/*'};
    headers['Connection'] = 'close';
    headers['Accept-Encoding'] = 'identity';
    final cookie = cookieHeader?.trim() ?? '';
    if (cookie.isNotEmpty &&
        RiverServerConfig.instance.isForumHost(packageUri.host.trim())) {
      headers['Cookie'] = cookie;
    }

    final zipFile = await _downloadPackageFile(
      packageUri: packageUri,
      headers: headers,
      appId: app.id,
    );
    try {
      final root = await _appsRootDir();
      final appDir = Directory(
        '${root.path}${Platform.pathSeparator}${_safeSegment(app.id)}',
      );
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }
      await appDir.create(recursive: true);

      await extractFileToDisk(zipFile.path, appDir.path);

      final entryFile = await _resolveEntryFile(app: app, appDir: appDir);
      if (entryFile == null || !await entryFile.exists()) {
        throw Exception('安装完成但未找到入口页面(index.html)');
      }

      final installed = app.copyWith(
        localEntryFilePath: entryFile.path,
        installedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _upsertInstalledApp(installed);
      return installed;
    } finally {
      await _safeDeleteFile(zipFile);
      final partFile = File('${zipFile.path}.part');
      await _safeDeleteFile(partFile);
    }
  }

  Future<void> removeInstalledById(String appId) async {
    final installed = await loadInstalledApps();
    final target = installed.where((item) => item.id == appId).toList();
    if (target.isNotEmpty) {
      final path = target.first.localEntryFilePath.trim();
      if (path.isNotEmpty) {
        final file = File(path);
        final dir = file.parent;
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }
    final remain = installed
        .where((item) => item.id != appId)
        .toList(growable: false);
    await _saveInstalled(remain);
  }

  Future<void> clearAllInstalled() async {
    final root = await _appsRootDir();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
    await _saveInstalled(const <RiverMiniAppEntry>[]);
  }

  Future<void> reorderInstalledByIds(List<String> idsInOrder) async {
    final installed = await loadInstalledApps();
    if (installed.isEmpty) {
      return;
    }
    final normalizedIds = idsInOrder
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }

    final byId = <String, RiverMiniAppEntry>{
      for (final item in installed) item.id: item,
    };
    final reordered = <RiverMiniAppEntry>[];
    for (final id in normalizedIds) {
      final item = byId.remove(id);
      if (item != null) {
        reordered.add(item);
      }
    }
    reordered.addAll(byId.values);

    final withOrder = <RiverMiniAppEntry>[];
    for (var i = 0; i < reordered.length; i++) {
      withOrder.add(reordered[i].copyWith(order: i));
    }
    await _saveInstalled(withOrder);
  }

  Future<RiverMiniAppStorageOverview> loadStorageOverview() async {
    final installed = await loadInstalledApps();
    final result = <RiverMiniAppStorageItem>[];
    var total = 0;
    for (final app in installed) {
      final bytes = await _appDirectoryBytes(app.localEntryFilePath);
      total += bytes;
      result.add(
        RiverMiniAppStorageItem(
          appId: app.id,
          appName: app.name,
          bytes: bytes,
          installedAtMillis: app.installedAtMillis,
        ),
      );
    }
    result.sort((a, b) => b.bytes.compareTo(a.bytes));
    return RiverMiniAppStorageOverview(
      totalBytes: total,
      appCount: installed.length,
      items: result,
    );
  }

  Future<void> _upsertInstalledApp(RiverMiniAppEntry app) async {
    final installed = await loadInstalledApps();
    final byId = <String, RiverMiniAppEntry>{
      for (final item in installed) item.id: item,
    };
    byId[app.id] = app;
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        if (orderCmp != 0) {
          return orderCmp;
        }
        return a.name.compareTo(b.name);
      });
    await _saveInstalled(merged);
  }

  Future<void> _saveInstalled(List<RiverMiniAppEntry> apps) async {
    _prefs ??= await SharedPreferences.getInstance();
    final list = apps.map((item) => item.toJson()).toList(growable: false);
    await _prefs?.setString(_installedAppsKey, jsonEncode(list));
  }

  Future<Directory> _appsRootDir() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}${Platform.pathSeparator}mini_apps');
    await root.create(recursive: true);
    return root;
  }

  Future<int> _appDirectoryBytes(String localEntryPath) async {
    final path = localEntryPath.trim();
    if (path.isEmpty) {
      return 0;
    }
    final entry = File(path);
    final dir = entry.parent;
    if (!await dir.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // Ignore unreadable file.
        }
      }
    }
    return total;
  }

  Future<File?> _resolveEntryFile({
    required RiverMiniAppEntry app,
    required Directory appDir,
  }) async {
    final fromUrl = _entryPathFromUrl(app.url);
    if (fromUrl.isNotEmpty) {
      final candidate = File('${appDir.path}${Platform.pathSeparator}$fromUrl');
      if (await candidate.exists()) {
        return candidate;
      }
    }

    final defaultEntry = File(
      '${appDir.path}${Platform.pathSeparator}index.html',
    );
    if (await defaultEntry.exists()) {
      return defaultEntry;
    }

    final htmlFiles = await appDir
        .list(recursive: true, followLinks: false)
        .where(
          (entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.html'),
        )
        .cast<File>()
        .toList();
    if (htmlFiles.isEmpty) {
      return null;
    }
    htmlFiles.sort((a, b) => a.path.length.compareTo(b.path.length));
    return htmlFiles.first;
  }

  String _entryPathFromUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null) {
      return '';
    }
    final path = uri.path.trim();
    if (path.isEmpty) {
      return '';
    }
    final segments = path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.trim())
        .toList(growable: false);
    if (segments.isEmpty) {
      return '';
    }
    if (segments.length >= 2 && segments.first == 'miniapps') {
      return segments.skip(2).join(Platform.pathSeparator);
    }
    if (segments.length >= 2) {
      return segments.skip(1).join(Platform.pathSeparator);
    }
    return segments.first;
  }

  String _safeSegment(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
  }

  Future<File> _downloadPackageFile({
    required Uri packageUri,
    required Map<String, String> headers,
    required String appId,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final downloadDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}mini_app_downloads',
    );
    await downloadDir.create(recursive: true);
    final baseName = _safeSegment(appId);
    final finalFile = File(
      '${downloadDir.path}${Platform.pathSeparator}$baseName.zip',
    );
    final partFile = File(
      '${downloadDir.path}${Platform.pathSeparator}$baseName.zip.part',
    );
    await _safeDeleteFile(finalFile);
    await _safeDeleteFile(partFile);

    Object? primaryError;
    try {
      await _downloadPackageFileWhole(
        packageUri: packageUri,
        headers: headers,
        partFile: partFile,
        maxRetries: _downloadMaxRetries + 2,
      );
      await _safeDeleteFile(finalFile);
      await partFile.rename(finalFile.path);
      return finalFile;
    } catch (error) {
      primaryError = error;
    }

    Object? fallbackError;
    try {
      final fallback = await _downloadPackageFileChunked(
        packageUri: packageUri,
        headers: headers,
        partFile: partFile,
        finalFile: finalFile,
      );
      if (fallback != null) {
        return fallback;
      }
    } catch (error) {
      fallbackError = error;
    }
    throw Exception(
      '下载小程序失败：整包下载失败：$primaryError；分片兜底失败：${fallbackError ?? "unknown"}',
    );
  }

  Future<File?> _downloadPackageFileChunked({
    required Uri packageUri,
    required Map<String, String> headers,
    required File partFile,
    required File finalFile,
  }) async {
    try {
      await _safeDeleteFile(finalFile);
      await _safeDeleteFile(partFile);

      const chunkSize = 64 * 1024;
      const perChunkMaxRetries = 6;

      var downloaded = 0;
      int? totalSize;
      final sink = partFile.openWrite(mode: FileMode.write);
      try {
        while (true) {
          if (totalSize != null && downloaded >= totalSize) {
            break;
          }
          final start = downloaded;
          final end = totalSize == null
              ? start + chunkSize - 1
              : math.min(start + chunkSize - 1, totalSize - 1);
          final requestedLength = end - start + 1;

          _RangeChunkResult? chunk;
          Object? chunkError;
          for (var attempt = 1; attempt <= perChunkMaxRetries; attempt++) {
            try {
              chunk = await _downloadRangeChunk(
                packageUri: packageUri,
                headers: headers,
                start: start,
                end: end,
              );
              chunkError = null;
              break;
            } catch (error) {
              chunkError = error;
              if (attempt >= perChunkMaxRetries) {
                break;
              }
              await Future<void>.delayed(
                Duration(milliseconds: 180 * attempt),
              );
            }
          }

          if (chunk == null) {
            throw Exception('分片下载失败($start-$end)：$chunkError');
          }
          if (chunk.bytes.isEmpty) {
            throw Exception('分片返回空数据($start-$end)');
          }

          final chunkStart = chunk.start ?? start;
          final chunkEnd = chunk.end ?? (chunkStart + chunk.bytes.length - 1);
          final serverLength = chunkEnd - chunkStart + 1;
          if (serverLength <= 0 || chunk.bytes.length != serverLength) {
            throw Exception(
              '分片长度异常($chunkStart-$chunkEnd, bytes=${chunk.bytes.length})',
            );
          }
          if (chunkStart != start) {
            throw Exception('分片起始偏移不匹配(期望$start, 实际$chunkStart)');
          }

          if (chunk.totalSize != null) {
            totalSize = chunk.totalSize;
          }

          sink.add(chunk.bytes);
          downloaded += chunk.bytes.length;

          if (totalSize == null && chunk.bytes.length < requestedLength) {
            // 服务器未知总长度场景：最后一片会小于请求长度。
            totalSize = downloaded;
          }
          if (totalSize != null && downloaded >= totalSize) {
            break;
          }
        }
      } finally {
        await sink.close();
      }

      if (downloaded <= 0) {
        await _safeDeleteFile(partFile);
        return null;
      }
      await _safeDeleteFile(finalFile);
      await partFile.rename(finalFile.path);
      return finalFile;
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadPackageFileWhole({
    required Uri packageUri,
    required Map<String, String> headers,
    required File partFile,
    int maxRetries = 4,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final ioClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 35)
        ..idleTimeout = const Duration(seconds: 20)
        ..autoUncompress = false
        ..maxConnectionsPerHost = 2;
      try {
        var existingLength = 0;
        if (await partFile.exists()) {
          existingLength = await partFile.length();
        }

        final request = await ioClient.getUrl(packageUri).timeout(
          const Duration(seconds: 35),
        );
        headers.forEach((key, value) {
          if (key.toLowerCase() == HttpHeaders.rangeHeader) {
            return;
          }
          request.headers.set(key, value);
        });
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        if (existingLength > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingLength-');
        }
        request.persistentConnection = false;
        final response = await request.close().timeout(
          const Duration(seconds: 35),
        );
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
          final total = _parseContentRangeTotal(
            response.headers.value(HttpHeaders.contentRangeHeader),
          );
          await response.drain<void>();
          if (total != null && existingLength >= total) {
            return;
          }
          await _safeDeleteFile(partFile);
          throw Exception('HTTP ${HttpStatus.requestedRangeNotSatisfiable}');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}');
        }

        var fileMode = FileMode.write;
        int? expectedTotal;
        final statusCode = response.statusCode;
        if (statusCode == HttpStatus.partialContent) {
          final rangeStart = _parseContentRangeStart(
            response.headers.value(HttpHeaders.contentRangeHeader),
          );
          expectedTotal = _parseContentRangeTotal(
            response.headers.value(HttpHeaders.contentRangeHeader),
          );
          if (rangeStart == null) {
            throw Exception('整包续传缺少 Content-Range');
          }
          if (existingLength > 0 && rangeStart == existingLength) {
            fileMode = FileMode.append;
          } else if (rangeStart == 0) {
            await _safeDeleteFile(partFile);
            existingLength = 0;
            fileMode = FileMode.write;
          } else {
            throw Exception('整包续传偏移不匹配(期望$existingLength, 实际$rangeStart)');
          }
        } else {
          if (existingLength > 0) {
            // 服务端未接受 Range，回退为从头覆盖。
            await _safeDeleteFile(partFile);
            existingLength = 0;
          }
          if (response.contentLength > 0) {
            expectedTotal = response.contentLength + existingLength;
          }
          fileMode = FileMode.write;
        }

        final sink = partFile.openWrite(mode: fileMode);
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 120),
          )) {
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }

        final actual = await partFile.length();
        if (actual <= 0) {
          throw Exception('整包下载为空');
        }
        if (expectedTotal != null && expectedTotal > 0 && actual < expectedTotal) {
          throw Exception('整包下载不完整($actual/$expectedTotal)');
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt >= maxRetries) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 260 * attempt));
      } finally {
        ioClient.close(force: true);
      }
    }
    throw Exception('整包下载失败：$lastError');
  }

  Future<_RangeChunkResult> _downloadRangeChunk({
    required Uri packageUri,
    required Map<String, String> headers,
    required int start,
    required int end,
  }) async {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..idleTimeout = const Duration(seconds: 15)
      ..autoUncompress = false
      ..maxConnectionsPerHost = 2;
    try {
      final request = await ioClient.getUrl(packageUri);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.persistentConnection = false;

      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await response.drain<void>();
        throw Exception('HTTP ${HttpStatus.requestedRangeNotSatisfiable}');
      }
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw Exception('HTTP ${response.statusCode}');
      }

      if (response.statusCode == HttpStatus.ok && start > 0) {
        throw Exception('服务器不支持断点续传');
      }

      int? actualStart;
      int? actualEnd;
      int? totalSize;
      if (response.statusCode == HttpStatus.partialContent) {
        final contentRangeRaw = response.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        actualStart = _parseContentRangeStart(contentRangeRaw);
        actualEnd = _parseContentRangeEnd(contentRangeRaw);
        totalSize = _parseContentRangeTotal(contentRangeRaw);
        if (actualStart == null || actualEnd == null) {
          throw Exception('响应缺少有效 Content-Range');
        }
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 40))) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (response.statusCode == HttpStatus.ok) {
        final knownTotal = response.contentLength > 0
            ? response.contentLength
            : bytes.length;
        return _RangeChunkResult(
          bytes: bytes,
          start: 0,
          end: bytes.isEmpty ? null : bytes.length - 1,
          totalSize: knownTotal,
        );
      }
      return _RangeChunkResult(
        bytes: bytes,
        start: actualStart,
        end: actualEnd,
        totalSize: totalSize,
      );
    } finally {
      ioClient.close(force: true);
    }
  }

  int? _parseContentRangeStart(String? rawHeader) {
    final raw = rawHeader?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  int? _parseContentRangeTotal(String? rawHeader) {
    final raw = rawHeader?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final fullMatch =
        RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(raw);
    if (fullMatch != null) {
      final totalRaw = fullMatch.group(3)!;
      if (totalRaw == '*') {
        return null;
      }
      return int.tryParse(totalRaw);
    }
    final unsatisfied = RegExp(r'^bytes\s+\*/(\d+)$').firstMatch(raw);
    if (unsatisfied != null) {
      return int.tryParse(unsatisfied.group(1)!);
    }
    return null;
  }

  int? _parseContentRangeEnd(String? rawHeader) {
    final raw = rawHeader?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(2)!);
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // ignore
    }
  }
}

class _RangeChunkResult {
  const _RangeChunkResult({
    required this.bytes,
    required this.start,
    required this.end,
    required this.totalSize,
  });

  final Uint8List bytes;
  final int? start;
  final int? end;
  final int? totalSize;
}

class RiverMiniAppStorageOverview {
  const RiverMiniAppStorageOverview({
    required this.totalBytes,
    required this.appCount,
    required this.items,
  });

  final int totalBytes;
  final int appCount;
  final List<RiverMiniAppStorageItem> items;
}

class RiverMiniAppStorageItem {
  const RiverMiniAppStorageItem({
    required this.appId,
    required this.appName,
    required this.bytes,
    required this.installedAtMillis,
  });

  final String appId;
  final String appName;
  final int bytes;
  final int installedAtMillis;
}
