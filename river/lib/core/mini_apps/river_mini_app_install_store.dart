import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:river/core/config/server_config.dart';
import 'package:river/core/mini_apps/river_mini_app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiverMiniAppInstallStore {
  RiverMiniAppInstallStore();

  static const String _installedAppsKey = 'river.mini_apps.installed.apps.v1';
  static const int _chunkBytes = 256 * 1024;
  static const int _maxChunkRetries = 8;
  static const int _maxInstallAttempts = 3;
  static final StreamController<int> _installedAppsChangedController =
      StreamController<int>.broadcast(sync: true);
  static int _installedAppsRevision = 0;

  static Stream<int> get installedAppsChanged =>
      _installedAppsChangedController.stream;

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

    final headers = <String, String>{
      'Accept': '*/*',
      HttpHeaders.acceptEncodingHeader: 'identity',
      HttpHeaders.connectionHeader: 'close',
    };
    final cookie = cookieHeader?.trim() ?? '';
    if (cookie.isNotEmpty &&
        RiverServerConfig.instance.isForumHost(packageUri.host.trim())) {
      headers['Cookie'] = cookie;
    }

    final meta = await _resolvePackageMeta(
      packageUri: packageUri,
      headers: headers,
      app: app,
    );
    if (meta.length <= 0) {
      throw Exception('无法获取安装包长度，已中止安装');
    }

    final zipFile = await _downloadPackageFile(
      packageUri: packageUri,
      headers: headers,
      appId: app.id,
      expectedLength: meta.length,
      expectedSha256: meta.sha256,
    );
    try {
      final installed = await _installZipAtomically(app: app, zipFile: zipFile);
      await _upsertInstalledApp(installed);
      return installed;
    } finally {
      await _safeDeleteFile(zipFile);
      await _safeDeleteFile(File('${zipFile.path}.part'));
    }
  }

  Future<RiverMiniAppEntry> installFromLocalZip({
    required RiverMiniAppEntry app,
    required String zipFilePath,
  }) async {
    final path = zipFilePath.trim();
    if (path.isEmpty) {
      throw Exception('未选择本地安装包');
    }
    final zipFile = File(path);
    if (!await zipFile.exists()) {
      throw Exception('本地安装包不存在');
    }
    final length = await _fileLengthOrZero(zipFile);
    if (length <= 0) {
      throw Exception('本地安装包为空');
    }

    if (app.packageBytes > 0 && app.packageBytes != length) {
      throw Exception('本地安装包大小不匹配(${app.packageBytes}/$length)');
    }

    final expectedSha = app.packageSha256.trim().toLowerCase();
    if (expectedSha.isNotEmpty) {
      final actualSha = await _computeFileSha256(zipFile);
      if (actualSha != expectedSha) {
        throw Exception('本地安装包SHA256不匹配');
      }
    }

    if (!await _isValidZipArchive(zipFile)) {
      throw Exception('本地安装包不是有效ZIP');
    }

    final installed = await _installZipAtomically(app: app, zipFile: zipFile);
    await _upsertInstalledApp(installed);
    return installed;
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
    final saved = await _prefs?.setString(_installedAppsKey, jsonEncode(list));
    if (saved == true && !_installedAppsChangedController.isClosed) {
      _installedAppsChangedController.add(++_installedAppsRevision);
    }
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

  Future<RiverMiniAppEntry> _installZipAtomically({
    required RiverMiniAppEntry app,
    required File zipFile,
  }) async {
    final root = await _appsRootDir();
    final appDirName = _safeSegment(app.id);
    final appDir = Directory(
      '${root.path}${Platform.pathSeparator}$appDirName',
    );
    final stagingDir = Directory(
      '${root.path}${Platform.pathSeparator}.$appDirName.staging',
    );

    await _safeDeleteDirectory(stagingDir);
    await stagingDir.create(recursive: true);

    await _extractZipToDirectory(zipFile: zipFile, outputDir: stagingDir);

    final stagingEntry = await _resolveEntryFile(app: app, appDir: stagingDir);
    if (stagingEntry == null || !await stagingEntry.exists()) {
      throw Exception('安装完成但未找到入口页面(index.html)');
    }

    final relativeEntryPath = _relativePath(
      rootDirPath: stagingDir.path,
      filePath: stagingEntry.path,
    );

    await _safeDeleteDirectory(appDir);
    await _moveDirectory(source: stagingDir, target: appDir);

    final installedEntry = File(
      '${appDir.path}${Platform.pathSeparator}$relativeEntryPath',
    );
    if (!await installedEntry.exists()) {
      throw Exception('安装后入口文件丢失，请重试');
    }

    return app.copyWith(
      localEntryFilePath: installedEntry.path,
      installedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _relativePath({
    required String rootDirPath,
    required String filePath,
  }) {
    final separator = Platform.pathSeparator;
    final normalizedRoot = rootDirPath.endsWith(separator)
        ? rootDirPath
        : '$rootDirPath$separator';
    if (!filePath.startsWith(normalizedRoot)) {
      throw Exception('安装目录结构异常，无法定位入口文件');
    }
    return filePath.substring(normalizedRoot.length);
  }

  Future<void> _moveDirectory({
    required Directory source,
    required Directory target,
  }) async {
    try {
      await source.rename(target.path);
      return;
    } catch (_) {
      // fall back to copy
    }

    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = _relativePath(
        rootDirPath: source.path,
        filePath: entity.path,
      );
      final nextPath = '${target.path}${Platform.pathSeparator}$relative';
      if (entity is Directory) {
        await Directory(nextPath).create(recursive: true);
        continue;
      }
      if (entity is File) {
        final dst = File(nextPath);
        await dst.parent.create(recursive: true);
        await entity.copy(dst.path);
      }
    }
    await _safeDeleteDirectory(source);
  }

  Future<_PackageMeta> _resolvePackageMeta({
    required Uri packageUri,
    required Map<String, String> headers,
    required RiverMiniAppEntry app,
  }) async {
    final expectedFromManifest = app.packageBytes > 0 ? app.packageBytes : null;
    final expectedFromProbe = await _probeContentLength(
      packageUri: packageUri,
      headers: headers,
    );

    final length = expectedFromManifest ?? expectedFromProbe ?? 0;
    if (expectedFromManifest != null &&
        expectedFromProbe != null &&
        expectedFromManifest != expectedFromProbe) {
      throw Exception(
        '安装包长度不一致(manifest=$expectedFromManifest, server=$expectedFromProbe)',
      );
    }

    return _PackageMeta(
      length: length,
      sha256: app.packageSha256.trim().toLowerCase(),
    );
  }

  Future<File> _downloadPackageFile({
    required Uri packageUri,
    required Map<String, String> headers,
    required String appId,
    required int expectedLength,
    required String expectedSha256,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final downloadDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}mini_app_downloads',
    );
    await downloadDir.create(recursive: true);

    final safeId = _safeSegment(appId);
    final finalZip = File(
      '${downloadDir.path}${Platform.pathSeparator}$safeId.zip',
    );
    final partZip = File('${finalZip.path}.part');

    await _safeDeleteFile(finalZip);
    if (await partZip.exists()) {
      final old = await partZip.length();
      if (old > expectedLength) {
        await _safeDeleteFile(partZip);
      }
    }

    Object? lastError;
    for (var attempt = 1; attempt <= _maxInstallAttempts; attempt++) {
      try {
        await _downloadByRangeChunks(
          packageUri: packageUri,
          headers: headers,
          partZip: partZip,
          expectedLength: expectedLength,
        );

        final current = await _fileLengthOrZero(partZip);
        if (current != expectedLength) {
          throw Exception('下载长度异常($current/$expectedLength)');
        }

        if (expectedSha256.isNotEmpty) {
          final actualSha = await _computeFileSha256(partZip);
          if (actualSha != expectedSha256) {
            throw Exception(
              'SHA256校验失败(expected=$expectedSha256, actual=$actualSha)',
            );
          }
        }

        if (!await _isValidZipArchive(partZip)) {
          throw Exception('ZIP校验失败');
        }

        await _safeDeleteFile(finalZip);
        await partZip.rename(finalZip.path);
        return finalZip;
      } catch (error) {
        lastError = error;
        final current = await _fileLengthOrZero(partZip);
        if (current <= 0 || current >= expectedLength) {
          await _safeDeleteFile(partZip);
        }
        if (attempt >= _maxInstallAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 320 * attempt));
      }
    }

    throw Exception('下载小程序失败：$lastError');
  }

  Future<void> _downloadByRangeChunks({
    required Uri packageUri,
    required Map<String, String> headers,
    required File partZip,
    required int expectedLength,
  }) async {
    if (!await partZip.parent.exists()) {
      await partZip.parent.create(recursive: true);
    }

    var offset = await _fileLengthOrZero(partZip);
    if (offset > expectedLength) {
      await _safeDeleteFile(partZip);
      offset = 0;
    }

    final sink = partZip.openWrite(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    try {
      while (offset < expectedLength) {
        final chunkEnd = math.min(offset + _chunkBytes - 1, expectedLength - 1);
        final chunk = await _downloadChunkWithRetries(
          packageUri: packageUri,
          headers: headers,
          start: offset,
          end: chunkEnd,
          expectedTotal: expectedLength,
        );
        sink.add(chunk);
        offset += chunk.length;
      }
    } finally {
      await sink.close();
    }
  }

  Future<Uint8List> _downloadChunkWithRetries({
    required Uri packageUri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required int expectedTotal,
  }) async {
    final expectedChunkLength = (end - start) + 1;
    Object? lastError;

    for (var attempt = 1; attempt <= _maxChunkRetries; attempt++) {
      try {
        final result = await _fetchChunk(
          packageUri: packageUri,
          headers: headers,
          start: start,
          end: end,
        );

        if (result.totalSize != null && result.totalSize != expectedTotal) {
          throw Exception('包总长度不一致(${result.totalSize} != $expectedTotal)');
        }
        if (result.start != null && result.start != start) {
          throw Exception('Range起点不一致(${result.start} != $start)');
        }
        if (result.bytes.length != expectedChunkLength) {
          throw Exception(
            'Range长度不一致(${result.bytes.length} != $expectedChunkLength)',
          );
        }

        return result.bytes;
      } catch (error) {
        lastError = error;
        if (attempt < _maxChunkRetries) {
          await Future<void>.delayed(Duration(milliseconds: 180 * attempt));
        }
      }
    }

    throw Exception('分片下载失败($start-$end)：$lastError');
  }

  Future<_ChunkResult> _fetchChunk({
    required Uri packageUri,
    required Map<String, String> headers,
    required int start,
    required int end,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 6)
      ..maxConnectionsPerHost = 2;

    try {
      final request = await client.getUrl(packageUri);
      headers.forEach((key, value) {
        if (value.trim().isNotEmpty) {
          request.headers.set(key, value);
        }
      });
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        throw Exception('HTTP ${HttpStatus.requestedRangeNotSatisfiable}');
      }
      if (response.statusCode != HttpStatus.partialContent) {
        throw Exception('服务器不支持分片下载，HTTP ${response.statusCode}');
      }

      final rawRange = response.headers.value(HttpHeaders.contentRangeHeader);
      final parsedStart = _parseContentRangeStart(rawRange);
      final parsedEnd = _parseContentRangeEnd(rawRange);
      final total = _parseContentRangeTotal(rawRange);

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (parsedStart != null && parsedEnd != null) {
        final expectedLen = (parsedEnd - parsedStart) + 1;
        if (bytes.length != expectedLen) {
          throw Exception('分片体积异常(${bytes.length} != $expectedLen)');
        }
      }

      return _ChunkResult(
        bytes: bytes,
        start: parsedStart,
        end: parsedEnd,
        totalSize: total,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<int?> _probeContentLength({
    required Uri packageUri,
    required Map<String, String> headers,
  }) async {
    final fromHead = await _probeContentLengthByHead(
      packageUri: packageUri,
      headers: headers,
    );
    if (fromHead != null && fromHead > 0) {
      return fromHead;
    }

    try {
      final chunk = await _fetchChunk(
        packageUri: packageUri,
        headers: headers,
        start: 0,
        end: 0,
      );
      if (chunk.totalSize != null && chunk.totalSize! > 0) {
        return chunk.totalSize;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<int?> _probeContentLengthByHead({
    required Uri packageUri,
    required Map<String, String> headers,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.openUrl('HEAD', packageUri);
      headers.forEach((key, value) {
        if (value.trim().isNotEmpty) {
          request.headers.set(key, value);
        }
      });
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.connectionHeader, 'close');

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final raw = response.headers.value(HttpHeaders.contentLengthHeader) ?? '';
      final length = int.tryParse(raw);
      if (length != null && length > 0) {
        return length;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
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

  int? _parseContentRangeTotal(String? rawHeader) {
    final raw = rawHeader?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final totalRaw = match.group(3)!;
    if (totalRaw == '*') {
      return null;
    }
    return int.tryParse(totalRaw);
  }

  Future<String> _computeFileSha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase();
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
      try {
        final head = await raf.read(4);
        if (head.length < 4 || head[0] != 0x50 || head[1] != 0x4b) {
          return false;
        }
      } finally {
        await raf.close();
      }
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      return archive.isNotEmpty;
    } catch (_) {
      return false;
    }
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
      final fullPath = '${outputDir.path}${Platform.pathSeparator}$targetPath';
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

  Future<int> _fileLengthOrZero(File file) async {
    try {
      if (!await file.exists()) {
        return 0;
      }
      return await file.length();
    } catch (_) {
      return 0;
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

  Future<void> _safeDeleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // ignore
    }
  }
}

class _PackageMeta {
  const _PackageMeta({required this.length, required this.sha256});

  final int length;
  final String sha256;
}

class _ChunkResult {
  const _ChunkResult({
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
