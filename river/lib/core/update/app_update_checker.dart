import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:river/core/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.description,
    required this.highlights,
  });

  final String version;
  final String downloadUrl;
  final String description;
  final List<String> highlights;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.latestInfo,
    required this.hasUpdate,
    required this.checkedAt,
    this.errorMessage,
  });

  final String currentVersion;
  final AppUpdateInfo? latestInfo;
  final bool hasUpdate;
  final DateTime? checkedAt;
  final String? errorMessage;

  String get latestVersion => latestInfo?.version ?? '';
}

class AppUpdateChecker extends ChangeNotifier {
  AppUpdateChecker({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  String _currentVersion = '';
  bool _initialized = false;
  bool _isChecking = false;
  DateTime? _checkedAt;
  AppUpdateInfo? _latestInfo;
  String? _errorMessage;
  String _lastManifestUrl = '';

  String get currentVersion => _currentVersion;
  String get latestVersion => _latestInfo?.version ?? '';
  bool get isChecking => _isChecking;
  DateTime? get checkedAt => _checkedAt;
  String? get errorMessage => _errorMessage;

  bool get hasUpdate {
    final latest = _latestInfo?.version ?? '';
    if (latest.isEmpty || _currentVersion.isEmpty) {
      return false;
    }
    return compareVersion(latest, _currentVersion) > 0;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version.trim();
    } catch (_) {
      _currentVersion = '';
    }
    _initialized = true;
    notifyListeners();
  }

  Future<AppUpdateCheckResult> checkForUpdates({bool force = false}) async {
    if (!_initialized) {
      await initialize();
    }

    final manifestUrl = riverUpdateManifestUrl;
    if (_lastManifestUrl != manifestUrl) {
      _lastManifestUrl = manifestUrl;
      _checkedAt = null;
      _latestInfo = null;
      _errorMessage = null;
    }

    if (_isChecking) {
      return _snapshot();
    }

    if (!force && _checkedAt != null) {
      final delta = DateTime.now().difference(_checkedAt!);
      if (delta.inMinutes < 5) {
        return _snapshot();
      }
    }

    _isChecking = true;
    notifyListeners();

    try {
      final response = await _httpClient
          .get(
            Uri.parse(manifestUrl),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid updater.json format');
      }

      final version = (decoded['version'] ?? '').toString().trim();
      if (version.isEmpty) {
        throw const FormatException('Missing version field');
      }
      final link = (decoded['link'] ?? '').toString().trim();
      final desc = (decoded['desc'] ?? '').toString().trim();
      final updatesRaw = decoded['updates'];
      final updates = <String>[];
      if (updatesRaw is List) {
        for (final item in updatesRaw) {
          final text = item.toString().trim();
          if (text.isNotEmpty) {
            updates.add(text);
          }
        }
      }

      _latestInfo = AppUpdateInfo(
        version: version,
        downloadUrl: link,
        description: desc,
        highlights: updates,
      );
      _checkedAt = DateTime.now();
      _errorMessage = null;
    } catch (error) {
      _checkedAt = DateTime.now();
      _errorMessage = '检查更新失败：$error';
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return _snapshot();
  }

  AppUpdateCheckResult _snapshot() {
    return AppUpdateCheckResult(
      currentVersion: _currentVersion,
      latestInfo: _latestInfo,
      hasUpdate: hasUpdate,
      checkedAt: _checkedAt,
      errorMessage: _errorMessage,
    );
  }

  static int compareVersion(String a, String b) {
    final aParts = _splitVersion(a);
    final bParts = _splitVersion(b);

    final mainDiff = _compareMain(aParts.main, bParts.main);
    if (mainDiff != 0) {
      return mainDiff;
    }
    return _comparePreRelease(aParts.preRelease, bParts.preRelease);
  }

  static _VersionParts _splitVersion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return const _VersionParts(main: <int>[], preRelease: <String>[]);
    }

    final plusIndex = normalized.indexOf('+');
    final withoutBuild = plusIndex >= 0
        ? normalized.substring(0, plusIndex)
        : normalized;
    final dashIndex = withoutBuild.indexOf('-');
    final core = dashIndex >= 0
        ? withoutBuild.substring(0, dashIndex)
        : withoutBuild;
    final pre = dashIndex >= 0 ? withoutBuild.substring(dashIndex + 1) : '';

    final coreParts = core
        .split('.')
        .map((segment) {
          final matched = RegExp(r'^\d+').firstMatch(segment.trim());
          return int.tryParse(matched?.group(0) ?? '0') ?? 0;
        })
        .toList(growable: false);

    final preParts = pre.isEmpty
        ? const <String>[]
        : pre
              .split('.')
              .map((segment) => segment.trim())
              .where((segment) => segment.isNotEmpty)
              .toList(growable: false);
    return _VersionParts(main: coreParts, preRelease: preParts);
  }

  static int _compareMain(List<int> a, List<int> b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) {
        return x.compareTo(y);
      }
    }
    return 0;
  }

  static int _comparePreRelease(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) {
      return 0;
    }
    if (a.isEmpty) {
      return 1;
    }
    if (b.isEmpty) {
      return -1;
    }

    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      if (i >= a.length) {
        return -1;
      }
      if (i >= b.length) {
        return 1;
      }
      final left = a[i];
      final right = b[i];

      final leftInt = int.tryParse(left);
      final rightInt = int.tryParse(right);
      if (leftInt != null && rightInt != null) {
        if (leftInt != rightInt) {
          return leftInt.compareTo(rightInt);
        }
        continue;
      }
      if (leftInt != null && rightInt == null) {
        return -1;
      }
      if (leftInt == null && rightInt != null) {
        return 1;
      }
      final textDiff = left.compareTo(right);
      if (textDiff != 0) {
        return textDiff;
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

class _VersionParts {
  const _VersionParts({required this.main, required this.preRelease});

  final List<int> main;
  final List<String> preRelease;
}

Future<void> showRiverUpdateDialog({
  required BuildContext context,
  required AppUpdateCheckResult result,
  required bool fromManualAction,
}) async {
  if (!result.hasUpdate || result.latestInfo == null) {
    if (!fromManualAction) {
      return;
    }

    final message = result.errorMessage == null
        ? '当前版本 ${result.currentVersion.isEmpty ? '- ' : result.currentVersion} 已是最新版本'
        : result.errorMessage!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.95, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (dialogContext, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: _RiverInfoDialogCard(
            title: '版本',
            message: message,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
    return;
  }

  final info = result.latestInfo!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final shouldUpdate = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.94, end: 1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (dialogContext, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: _RiverUpdatePromptCard(
            result: result,
            info: info,
            onSkip: () => Navigator.of(ctx).pop(false),
            onUpdate: info.downloadUrl.isEmpty
                ? null
                : () => Navigator.of(ctx).pop(true),
          ),
        ),
      );
    },
  );

  if (shouldUpdate != true || info.downloadUrl.isEmpty) {
    return;
  }

  final uri = Uri.tryParse(info.downloadUrl);
  if (uri == null) {
    messenger?.showSnackBar(const SnackBar(content: Text('更新链接无效')));
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    messenger?.showSnackBar(const SnackBar(content: Text('无法打开更新链接')));
  }
}

class _RiverInfoDialogCard extends StatelessWidget {
  const _RiverInfoDialogCard({
    required this.title,
    required this.message,
    required this.onClose,
  });

  final String title;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onClose,
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiverUpdatePromptCard extends StatelessWidget {
  const _RiverUpdatePromptCard({
    required this.result,
    required this.info,
    required this.onSkip,
    required this.onUpdate,
  });

  final AppUpdateCheckResult result;
  final AppUpdateInfo info;
  final VoidCallback onSkip;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = result.currentVersion.isEmpty ? '-' : result.currentVersion;
    final latest = info.version;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.78),
                  theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现新版本',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'v$latest',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '稍后',
                  onPressed: onSkip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _VersionStatCard(
                          label: '当前',
                          value: current,
                          icon: Icons.smartphone_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VersionStatCard(
                          label: '最新',
                          value: latest,
                          icon: Icons.system_update_alt_rounded,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                  if (info.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      info.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '更新内容',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (info.highlights.isEmpty)
                    Text(
                      '本次更新包含体验优化与问题修复。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  for (final item in info.highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.66),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('暂不更新'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onUpdate,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('立即更新'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionStatCard extends StatelessWidget {
  const _VersionStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = emphasized
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.62)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.64);
    final fgColor = emphasized
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: fgColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'v$value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
