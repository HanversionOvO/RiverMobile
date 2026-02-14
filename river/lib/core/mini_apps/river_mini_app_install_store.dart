import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;
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

      await _extractZipToDirectory(zipFile: zipFile, outputDir: appDir);

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

  Future<void> _extractZipToDirectory({
    required File zipFile,
    required Directory outputDir,
  }) async {
    final bytes = await zipFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('安装包为空');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.isEmpty) {
      final head = bytes
          .take(8)
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      throw Exception('安装包解压后为空(len=${bytes.length}, head=$head)');
    }

    for (final item in archive) {
      final rawName = item.name.trim();
      if (rawName.isEmpty) {
        continue;
      }
      final normalized = rawName.replaceAll('\\', '/');
      if (normalized.startsWith('/') || normalized.contains('../')) {
        continue;
      }
      final targetPath = normalized
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .join(Platform.pathSeparator);
      if (targetPath.isEmpty) {
        continue;
      }
      final fullPath =
          '${outputDir.path}${Platform.pathSeparator}$targetPath';
      if (item.isFile) {
        final outFile = File(fullPath);
        await outFile.parent.create(recursive: true);
        final data = item.content as List<int>;
        await outFile.writeAsBytes(data, flush: true);
      } else {
        await Directory(fullPath).create(recursive: true);
      }
    }
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
    final baseName = _safeSegment(appId);
    final filename = '$baseName.zip';
    final task = DownloadTask(
      taskId: 'miniapp.$baseName.${DateTime.now().microsecondsSinceEpoch}',
      url: packageUri.toString(),
      filename: filename,
      directory: 'mini_app_downloads',
      baseDirectory: BaseDirectory.temporary,
      headers: headers,
      updates: Updates.statusAndProgress,
      retries: _downloadMaxRetries + 4,
      allowPause: true,
      requiresWiFi: false,
      priority: 5,
    );

    final expectedPath = await task.filePath();
    final targetFile = File(expectedPath);
    await _safeDeleteFile(targetFile);

    TaskStatusUpdate? result;
    Object? primaryError;
    try {
      result = await FileDownloader().download(
        task,
        onStatus: (_) {},
        onProgress: (_) {},
      );
    } catch (error) {
      primaryError = error;
    }

    if (result != null && result.status == TaskStatus.complete) {
      if (await targetFile.exists() && await _isValidZipArchive(targetFile)) {
        return targetFile;
      }
      primaryError = Exception('下载完成但文件不是有效ZIP');
    } else if (result != null) {
      final code = result.responseStatusCode == null
          ? ''
          : ' http=${result.responseStatusCode}';
      final reason = result.exception?.description ?? 'unknown';
      primaryError = Exception('下载失败(${result.status.name})$code: $reason');
    } else {
      primaryError ??= Exception('下载失败：未知错误');
    }

    final fallbackFile = await _downloadByHttpDirect(
      packageUri: packageUri,
      headers: headers,
      targetFile: targetFile,
    );
    if (fallbackFile != null && await _isValidZipArchive(fallbackFile)) {
      return fallbackFile;
    }

    final length = await _fileLengthOrNull(targetFile);
    final head = await _fileHeadHex(targetFile);
    throw Exception(
      '下载失败：primary=$primaryError；fallback=http-direct-failed；len=$length；head=$head',
    );
  }

  Future<File?> _downloadByHttpDirect({
    required Uri packageUri,
    required Map<String, String> headers,
    required File targetFile,
  }) async {
    const maxRetries = 5;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final client = http.Client();
      try {
        await _safeDeleteFile(targetFile);
        final request = http.Request('GET', packageUri);
        request.headers.addAll(headers);
        request.headers.removeWhere(
          (key, _) => key.toLowerCase() == HttpHeaders.rangeHeader,
        );
        request.headers[HttpHeaders.acceptEncodingHeader] = 'identity';

        final streamed = await client.send(request).timeout(
          const Duration(seconds: 30),
        );
        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          throw Exception('HTTP ${streamed.statusCode}');
        }

        var received = 0;
        final sink = targetFile.openWrite(mode: FileMode.write);
        try {
          await for (final chunk in streamed.stream.timeout(
            const Duration(seconds: 120),
          )) {
            sink.add(chunk);
            received += chunk.length;
          }
        } finally {
          await sink.close();
        }

        final expected = int.tryParse(streamed.headers['content-length'] ?? '');
        if (expected != null && expected > 0 && received < expected) {
          throw Exception('下载不完整($received/$expected)');
        }
        if (received <= 0 || !await targetFile.exists()) {
          throw Exception('下载为空');
        }
        return targetFile;
      } catch (_) {
        if (attempt >= maxRetries) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 220 * attempt));
      } finally {
        client.close();
      }
    }
    return null;
  }

  Future<bool> _isValidZipArchive(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      final length = await file.length();
      if (length < 4) {
        return false;
      }
      final raf = await file.open();
      late final List<int> head;
      try {
        head = await raf.read(4);
      } finally {
        await raf.close();
      }
      if (head.length < 4 || head[0] != 0x50 || head[1] != 0x4b) {
        return false;
      }
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      return archive.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int?> _fileLengthOrNull(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<String> _fileHeadHex(File file, [int count = 12]) async {
    try {
      if (!await file.exists()) {
        return 'missing';
      }
      final raf = await file.open();
      try {
        final bytes = await raf.read(count);
        if (bytes.isEmpty) {
          return 'empty';
        }
        return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
      } finally {
        await raf.close();
      }
    } catch (_) {
      return 'unreadable';
    }
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
