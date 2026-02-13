import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/navigation/river_page_route.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:river/features/login/riverside_external_fallback_page.dart';
import 'package:river/features/login/riverside_login_flow_mode.dart';
import 'package:river/features/login/riverside_session_reader.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RiverSideLoginWebViewPage extends StatefulWidget {
  const RiverSideLoginWebViewPage({
    super.key,
    required this.dependencies,
    this.flowMode = RiverSideLoginFlowMode.initialLogin,
  });

  final AppDependencies dependencies;
  final RiverSideLoginFlowMode flowMode;

  @override
  State<RiverSideLoginWebViewPage> createState() =>
      _RiverSideLoginWebViewPageState();
}

class _RiverSideLoginWebViewPageState extends State<RiverSideLoginWebViewPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _completedFlow = false;
  bool _syncingAccount = false;
  bool _openingExternalFallback = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentHost = riverSideHost;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _currentHost = _parseHost(url);
            });
            unawaited(_updateNavigationState());
          },
          onPageFinished: _onPageFinished,
          onNavigationRequest: (request) {
            if (mounted) {
              setState(() {
                _currentHost = _parseHost(request.url);
              });
            }
            unawaited(_updateNavigationState());
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('WebView 加载失败，已切换账号密码登录')),
            );
            unawaited(_switchToCredentialLogin());
          },
        ),
      );

    unawaited(_prepareAndLoad());
  }

  Future<void> _prepareAndLoad() async {
    if (widget.flowMode == RiverSideLoginFlowMode.addAccount) {
      await widget.dependencies.accountStore
          .captureAndPersistActiveRiverSideCookies();
      await widget.dependencies.accountStore.clearWebViewCookies();
    }

    if (!mounted) {
      return;
    }
    await _controller.loadRequest(Uri.parse(riverSideLoginUrl));
  }

  Future<void> _updateNavigationState() async {
    final canBack = await _controller.canGoBack();
    final canForward = await _controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canBack;
      _canGoForward = canForward;
    });
  }

  String _parseHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return riverSideHost;
    }
    return uri.host;
  }

  Future<void> _switchToCredentialLogin() async {
    if (!mounted || _openingExternalFallback) {
      return;
    }
    _openingExternalFallback = true;
    try {
      final profile = await showRiverSideCredentialLoginSheet(
        context: context,
        dependencies: widget.dependencies,
      );
      if (!mounted || profile == null || _completedFlow) {
        return;
      }

      if (widget.flowMode == RiverSideLoginFlowMode.initialLogin) {
        _completedFlow = true;
        Navigator.of(context).pushAndRemoveUntil(
          riverPageRoute<void>(
            builder: (_) => HomeShellPage(dependencies: widget.dependencies),
          ),
          (_) => false,
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账号密码登录成功，已添加账号。')));
      Navigator.of(context).pop(profile);
    } finally {
      _openingExternalFallback = false;
    }
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _currentHost = _parseHost(url);
    });
    await _updateNavigationState();
    await _checkLoginSuccess(url);
  }

  Future<void> _checkLoginSuccess(String url) async {
    if (_completedFlow || _syncingAccount) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final loggedIn = isRiverSideHost(host) && !path.startsWith('/login');
    if (!loggedIn) {
      return;
    }

    _syncingAccount = true;
    UserAccount? profile;
    try {
      profile = await _resolveProfile(path);
      if (profile != null) {
        await widget.dependencies.accountStore.upsertRiverSideAccount(profile);
        await widget.dependencies.accountStore
            .captureAndPersistCurrentRiverSideCookies(profile.username);
        await widget.dependencies.accountStore.switchActiveRiverSideAccount(
          profile.username,
        );
      }
    } finally {
      _syncingAccount = false;
    }

    if (!mounted) {
      return;
    }

    if (widget.flowMode == RiverSideLoginFlowMode.addAccount) {
      if (profile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已检测登录，但未解析到账号信息，请重试。')));
        return;
      }
      _completedFlow = true;
      Navigator.of(context).pop(profile);
      return;
    }

    _completedFlow = true;
    Navigator.of(context).pushAndRemoveUntil(
      riverPageRoute<void>(
        builder: (_) => HomeShellPage(dependencies: widget.dependencies),
      ),
      (_) => false,
    );
  }

  Future<UserAccount?> _resolveProfile(String currentPath) async {
    final reader = RiverSideSessionReader(
      _controller,
      widget.dependencies.accountStore.riverSideApiClient,
    );

    for (var attempt = 0; attempt < 8; attempt++) {
      final profile = await reader.readCurrentProfile();
      if (profile != null && profile.username.isNotEmpty) {
        return profile;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final username = _extractUsernameFromPath(currentPath);
    if (username == null || username.isEmpty) {
      return null;
    }

    return UserAccount(
      provider: AccountProvider.riverSide,
      username: username,
      displayName: username,
      avatarUrl: '',
    );
  }

  String? _extractUsernameFromPath(String path) {
    final pattern = RegExp(r'^/u/([^/?#]+)', caseSensitive: false);
    final match = pattern.firstMatch(path);
    if (match == null) {
      return null;
    }
    final value = match.group(1);
    if (value == null || value.isEmpty) {
      return null;
    }
    return Uri.decodeComponent(value);
  }

  @override
  Widget build(BuildContext context) {
    final isInitial = widget.flowMode == RiverSideLoginFlowMode.initialLogin;
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isInitial ? '登录 RiverSide' : '添加 RiverSide 账号',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _currentHost,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: IconButton.filledTonal(
              tooltip: '账号密码登录',
              onPressed: _switchToCredentialLogin,
              icon: const Icon(Icons.password_rounded),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                theme.colorScheme.surface.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surfaceContainerLowest,
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: topInset + kToolbarHeight + 10,
            bottom: 84,
            left: 10,
            right: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.34,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '后退',
                          onPressed: _canGoBack
                              ? () async {
                                  await _controller.goBack();
                                  await _updateNavigationState();
                                }
                              : null,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        IconButton(
                          tooltip: '前进',
                          onPressed: _canGoForward
                              ? () async {
                                  await _controller.goForward();
                                  await _updateNavigationState();
                                }
                              : null,
                          icon: const Icon(Icons.arrow_forward_ios_rounded),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await _controller.reload();
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('刷新'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
