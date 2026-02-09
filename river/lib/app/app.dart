import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/account/account_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/platform/riverside_cookie_bridge.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:river/features/login/login_page.dart';

class RiverApp extends StatefulWidget {
  const RiverApp({super.key});

  @override
  State<RiverApp> createState() => _RiverAppState();
}

class _RiverAppState extends State<RiverApp> {
  late final AppDependencies _dependencies;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _dependencies = AppDependencies(
      settingsController: AppSettingsController(),
      accountStore: AccountStore(
        riverSideApiClient: RiverSideApiClient(),
        riverSideCookieBridge: RiverSideCookieBridge(),
      ),
    );

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _dependencies.accountStore.initialize();
    await _dependencies.accountStore.syncActiveRiverSideCookieToWebView();
    if (!mounted) {
      return;
    }

    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _dependencies.settingsController.dispose();
    _dependencies.accountStore.dispose();
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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF12457A),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF12457A),
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
