import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: _onPageFinished,
          onNavigationRequest: (_) => NavigationDecision.navigate,
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) {
              return;
            }

            if (widget.flowMode == RiverSideLoginFlowMode.addAccount) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Load failed. Please retry in a newer WebView environment.',
                  ),
                ),
              );
              Navigator.of(context).pop();
              return;
            }

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

  Future<void> _switchToCredentialLogin() async {
    if (!mounted || _openingExternalFallback) {
      return;
    }

    _openingExternalFallback = true;
    try {
      final profile = await Navigator.of(context).push<UserAccount>(
        MaterialPageRoute<UserAccount>(
          builder: (_) =>
              RiverSideExternalFallbackPage(dependencies: widget.dependencies),
        ),
      );

      if (!mounted || profile == null || _completedFlow) {
        return;
      }

      if (widget.flowMode == RiverSideLoginFlowMode.initialLogin) {
        _completedFlow = true;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
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
    });

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
    final loggedIn =
        host.contains('river-side.cc') && !path.startsWith('/login');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login detected but account profile was not resolved. Please retry.',
            ),
          ),
        );
        return;
      }

      _completedFlow = true;
      Navigator.of(context).pop(profile);
      return;
    }

    _completedFlow = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
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
    final title = widget.flowMode == RiverSideLoginFlowMode.initialLogin
        ? 'RiverSide Login'
        : 'Add RiverSide Account';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            tooltip: '账号密码登录',
            onPressed: _switchToCredentialLogin,
            icon: const Icon(Icons.password_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
