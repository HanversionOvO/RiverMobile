import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/config/server_config.dart';
import 'package:river/core/mini_apps/river_mini_app_models.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MiniAppWebViewPage extends StatefulWidget {
  const MiniAppWebViewPage({
    super.key,
    required this.dependencies,
    required this.miniApp,
  });

  final AppDependencies dependencies;
  final RiverMiniAppEntry miniApp;

  @override
  State<MiniAppWebViewPage> createState() => _MiniAppWebViewPageState();
}

class _MiniAppWebViewPageState extends State<MiniAppWebViewPage> {
  late final WebViewController _controller;
  String _title = '';
  bool _loading = true;
  bool _canGoBack = false;
  HttpServer? _localMiniAppServer;
  Uri? _localMiniAppEntryUri;

  @override
  void initState() {
    super.initState();
    _title = widget.miniApp.name;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loading = true;
            });
            unawaited(_syncNavigationState());
          },
          onPageFinished: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loading = false;
            });
            unawaited(_injectBridgeBootstrap());
            unawaited(_syncNavigationState());
          },
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('小程序加载失败：${error.description}')),
            );
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      );
    unawaited(
      _controller.addJavaScriptChannel(
        'RiverMiniAppBridge',
        onMessageReceived: _onBridgeMessage,
      ),
    );
    unawaited(_loadInitialUrl());
  }

  Future<void> _loadInitialUrl() async {
    final localPath = widget.miniApp.localEntryFilePath.trim();
    if (localPath.isNotEmpty) {
      final localFile = File(localPath);
      if (await localFile.exists()) {
        final localUri = await _ensureLocalMiniAppEntryUri(localFile);
        await _controller.loadRequest(localUri);
        return;
      }
    }

    final uri = Uri.tryParse(widget.miniApp.url);
    if (uri == null) {
      return;
    }
    final headers = <String, String>{
      'X-River-MiniApp-Id': widget.miniApp.id,
      'X-River-MiniApp-Bridge': widget.miniApp.bridgeVersion,
    };
    if (widget.miniApp.requiresAuth) {
      final cookie = _activeCookieHeader();
      if (cookie.isNotEmpty &&
          RiverServerConfig.instance.isForumHost(uri.host.trim())) {
        headers['Cookie'] = cookie;
      }
    }
    await _controller.loadRequest(uri, headers: headers);
  }

  Future<Uri> _ensureLocalMiniAppEntryUri(File entryFile) async {
    if (_localMiniAppEntryUri != null && _localMiniAppServer != null) {
      return _localMiniAppEntryUri!;
    }

    final rootDir = entryFile.parent;
    final entryName = entryFile.uri.pathSegments.isNotEmpty
        ? entryFile.uri.pathSegments.last
        : 'index.html';

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _localMiniAppServer = server;
    server.listen((request) async {
      try {
        final rawPath = Uri.decodeComponent(request.uri.path);
        final normalizedPath = rawPath == '/' || rawPath.trim().isEmpty
            ? entryName
            : rawPath.replaceFirst(RegExp(r'^/+'), '');
        final segments = normalizedPath
            .split('/')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e != '.' && e != '..')
            .toList(growable: false);
        final localPath = segments.isEmpty
            ? entryName
            : segments.join(Platform.pathSeparator);
        final targetPath = '${rootDir.path}${Platform.pathSeparator}$localPath';
        final targetFile = File(targetPath);

        if (!await targetFile.exists()) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final bytes = await targetFile.readAsBytes();
        request.response.headers.contentType = _guessContentType(targetFile.path);
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.add(bytes);
        await request.response.close();
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });

    _localMiniAppEntryUri = Uri.parse(
      'http://127.0.0.1:${server.port}/${Uri.encodeComponent(entryName)}',
    );
    return _localMiniAppEntryUri!;
  }

  ContentType _guessContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return ContentType.html;
    }
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      return ContentType('application', 'javascript', charset: 'utf-8');
    }
    if (lower.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (lower.endsWith('.json')) {
      return ContentType.json;
    }
    if (lower.endsWith('.svg')) {
      return ContentType('image', 'svg+xml');
    }
    if (lower.endsWith('.png')) {
      return ContentType('image', 'png');
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return ContentType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) {
      return ContentType('image', 'webp');
    }
    if (lower.endsWith('.ico')) {
      return ContentType('image', 'x-icon');
    }
    if (lower.endsWith('.woff')) {
      return ContentType('font', 'woff');
    }
    if (lower.endsWith('.woff2')) {
      return ContentType('font', 'woff2');
    }
    if (lower.endsWith('.ttf')) {
      return ContentType('font', 'ttf');
    }
    return ContentType.binary;
  }

  String _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return '';
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(
          username,
        ) ??
        '';
  }

  Future<void> _syncNavigationState() async {
    try {
      final canGoBack = await _controller.canGoBack();
      if (!mounted || canGoBack == _canGoBack) {
        return;
      }
      setState(() {
        _canGoBack = canGoBack;
      });
    } catch (_) {
      // Ignore navigation probe failures.
    }
  }

  Future<void> _injectBridgeBootstrap() async {
    const script = '''
(() => {
  if (window.__riverMiniAppBridgeBooted) return;
  window.__riverMiniAppBridgeBooted = true;
  window.__riverMiniAppPending = {};
  window.RiverMiniApp = {
    call(action, payload) {
      const id = Date.now().toString() + '_' + Math.random().toString(16).slice(2);
      return new Promise((resolve, reject) => {
        window.__riverMiniAppPending[id] = { resolve, reject };
        RiverMiniAppBridge.postMessage(JSON.stringify({
          id,
          action: String(action || ''),
          payload: payload || {}
        }));
      });
    }
  };
  window.__riverMiniAppOnNativeMessage = function(message) {
    try {
      const data = (typeof message === 'string') ? JSON.parse(message) : message;
      if (!data || !data.id) return;
      const pending = window.__riverMiniAppPending[data.id];
      if (!pending) return;
      delete window.__riverMiniAppPending[data.id];
      if (data.ok) pending.resolve(data.data || null);
      else pending.reject(data.error || 'native_error');
    } catch (_) {}
  };
  window.dispatchEvent(new CustomEvent('river-miniapp-ready'));
})();
''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      // Ignore JS injection failure on some pages.
    }
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    final raw = message.message.trim();
    if (raw.isEmpty) {
      return;
    }
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      payload = <String, dynamic>{};
      for (final entry in decoded.entries) {
        payload['${entry.key}'] = entry.value;
      }
    } catch (_) {
      return;
    }

    final id = (payload['id'] ?? '').toString().trim();
    final action = (payload['action'] ?? '').toString().trim();
    final data = payload['payload'];
    if (id.isEmpty || action.isEmpty) {
      return;
    }

    try {
      final result = await _handleBridgeAction(action, data);
      await _postBridgeResponse(id: id, action: action, ok: true, data: result);
    } catch (error) {
      await _postBridgeResponse(
        id: id,
        action: action,
        ok: false,
        error: '$error',
      );
    }
  }

  Future<dynamic> _handleBridgeAction(String action, dynamic payload) async {
    final lowerAction = action.trim().toLowerCase();
    switch (lowerAction) {
      case 'getcontext':
      case 'context':
        return _buildContextPayload();
      case 'getauth':
      case 'auth':
        return _buildAuthPayload();
      case 'settitle':
        final nextTitle = _readStringFromPayload(payload, 'title');
        if (nextTitle.isNotEmpty && mounted) {
          setState(() {
            _title = nextTitle;
          });
        }
        return <String, dynamic>{'success': true};
      case 'copytext':
        final text = _readStringFromPayload(payload, 'text');
        if (text.isEmpty) {
          throw Exception('copyText missing text');
        }
        await Clipboard.setData(ClipboardData(text: text));
        return <String, dynamic>{'success': true};
      case 'openexternal':
        throw Exception('openExternal is disabled');
      case 'close':
        if (mounted) {
          Navigator.of(context).maybePop();
        }
        return <String, dynamic>{'success': true};
      default:
        throw Exception('Unsupported action: $action');
    }
  }

  Future<Map<String, dynamic>> _buildContextPayload() async {
    final brightness = Theme.of(context).brightness;
    final package = await PackageInfo.fromPlatform();
    final active = widget.dependencies.accountStore.activeRiverSideAccount;
    return <String, dynamic>{
      'app': <String, dynamic>{
        'name': package.appName,
        'version': package.version,
        'buildNumber': package.buildNumber,
      },
      'miniApp': <String, dynamic>{
        'id': widget.miniApp.id,
        'name': widget.miniApp.name,
        'bridgeVersion': widget.miniApp.bridgeVersion,
      },
      'theme': <String, dynamic>{
        'brightness': brightness.name,
        'seedColor':
            '#${widget.dependencies.settingsController.themeSeedColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      },
      'account': <String, dynamic>{
        'isGuest': widget.dependencies.accountStore.isGuestBrowsing,
        'username': active?.username ?? '',
        'displayName': active?.displayName ?? '',
      },
      'baseUrl': widget.dependencies.settingsController.riverSideBaseUrl,
    };
  }

  Map<String, dynamic> _buildAuthPayload() {
    final accountStore = widget.dependencies.accountStore;
    final active = accountStore.activeRiverSideAccount;
    final cookieHeader = _activeCookieHeader();
    return <String, dynamic>{
      'isGuest': accountStore.isGuestBrowsing,
      'username': active?.username ?? '',
      'displayName': active?.displayName ?? '',
      'cookieHeader': cookieHeader,
      'forumBaseUrl': widget.dependencies.settingsController.riverSideBaseUrl,
    };
  }

  String _readStringFromPayload(dynamic payload, String key) {
    if (payload is! Map) {
      return '';
    }
    final value = payload[key];
    return (value ?? '').toString().trim();
  }

  Future<void> _postBridgeResponse({
    required String id,
    required String action,
    required bool ok,
    dynamic data,
    String error = '',
  }) async {
    final response = <String, dynamic>{
      'id': id,
      'action': action,
      'ok': ok,
      if (ok) 'data': data,
      if (!ok) 'error': error,
    };
    final raw = jsonEncode(response);
    final js =
        'window.__riverMiniAppOnNativeMessage && '
        'window.__riverMiniAppOnNativeMessage(JSON.parse(${jsonEncode(raw)}));';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore response delivery failure.
    }
  }

  Future<void> _refresh() async {
    await _controller.reload();
  }

  Future<void> _showMoreSheet() async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      image: widget.miniApp.iconUrl.trim().isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(widget.miniApp.iconUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: widget.miniApp.iconUrl.trim().isEmpty
                        ? Icon(
                            Icons.widgets_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title.trim().isNotEmpty
                              ? _title.trim()
                              : widget.miniApp.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.miniApp.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.miniApp.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.miniApp.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.miniApp.tags
                      .take(6)
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MiniAppSheetAction(
                    icon: Icons.refresh_rounded,
                    label: '刷新小程序',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _refresh();
                    },
                  ),
                  _MiniAppSheetAction(
                    icon: Icons.home_work_outlined,
                    label: '回到首页',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _loadInitialUrl();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.78,
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_localMiniAppServer?.close(force: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          await _syncNavigationState();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controller)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.985, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: _loading
                  ? _MiniAppLoadingOverlay(
                      key: const ValueKey('mini_app_loading'),
                      miniApp: widget.miniApp,
                    )
                  : const SizedBox.shrink(key: ValueKey('mini_app_loaded')),
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingWindowButton(
                      icon: Icons.close_rounded,
                      tooltip: '关闭小程序',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    _buildFloatingWindowButton(
                      icon: Icons.more_horiz_rounded,
                      tooltip: '更多',
                      onTap: () {
                        unawaited(_showMoreSheet());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAppLoadingOverlay extends StatelessWidget {
  const _MiniAppLoadingOverlay({super.key, required this.miniApp});

  final RiverMiniAppEntry miniApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconUrl = miniApp.iconUrl.trim();

    return SizedBox.expand(
      child: Container(
        color: theme.colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.2,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                        image: iconUrl.isEmpty
                            ? null
                            : DecorationImage(
                                image: NetworkImage(iconUrl),
                                fit: BoxFit.cover,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: iconUrl.isEmpty
                          ? Icon(
                              Icons.widgets_rounded,
                              color: theme.colorScheme.primary,
                              size: 30,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                miniApp.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAppSheetAction extends StatelessWidget {
  const _MiniAppSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(onTap());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
