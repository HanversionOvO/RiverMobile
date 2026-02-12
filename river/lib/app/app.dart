import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/account/account_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/platform/riverside_cookie_bridge.dart';
import 'package:river/core/update/app_update_checker.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:river/features/login/login_page.dart';

class RiverApp extends StatefulWidget {
  const RiverApp({super.key});

  @override
  State<RiverApp> createState() => _RiverAppState();
}

class _RiverAppState extends State<RiverApp> {
  late final AppDependencies _dependencies;
  final GlobalKey<NavigatorState> _appNavigatorKey =
      GlobalKey<NavigatorState>();
  bool _initialized = false;
  bool _didAutoCheckUpdate = false;

  @override
  void initState() {
    super.initState();
    _dependencies = AppDependencies(
      settingsController: AppSettingsController(),
      accountStore: AccountStore(
        riverSideApiClient: RiverSideApiClient(),
        riverSideCookieBridge: RiverSideCookieBridge(),
      ),
      updateChecker: AppUpdateChecker(),
    );

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _dependencies.settingsController.initialize();
    await _dependencies.accountStore.initialize();
    await _dependencies.updateChecker.initialize();
    if (!mounted) {
      return;
    }

    setState(() {
      _initialized = true;
    });
    _scheduleAutoUpdateCheck();
    unawaited(_dependencies.accountStore.syncActiveRiverSideCookieToWebView());
  }

  void _scheduleAutoUpdateCheck() {
    if (_didAutoCheckUpdate) {
      return;
    }
    _didAutoCheckUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final result = await _dependencies.updateChecker.checkForUpdates();
      if (!mounted || !result.hasUpdate) {
        return;
      }
      final dialogContext = _appNavigatorKey.currentContext;
      if (dialogContext == null) {
        return;
      }
      if (!dialogContext.mounted) {
        return;
      }
      await showRiverUpdateDialog(
        context: dialogContext,
        result: result,
        fromManualAction: false,
      );
    });
  }

  @override
  void dispose() {
    _dependencies.settingsController.dispose();
    _dependencies.accountStore.dispose();
    _dependencies.updateChecker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dependencies.settingsController,
      builder: (context, _) {
        return MaterialApp(
          title: 'River Login',
          debugShowCheckedModeBanner: false,
          navigatorKey: _appNavigatorKey,
          builder: (context, child) {
            final data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                textScaler: TextScaler.linear(
                  _dependencies.settingsController.fontScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _dependencies.settingsController.themeSeedColor,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _dependencies.settingsController.themeSeedColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: _dependencies.settingsController.themeMode,
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_dependencies.accountStore.hasRiverSideAccount) {
      return HomeShellPage(dependencies: _dependencies);
    }

    return LoginPage(dependencies: _dependencies);
  }
}
