import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/account/account_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/platform/app_icon_switcher.dart';
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
    unawaited(
      AppIconSwitcher.switchToPreset(
        _dependencies.settingsController.iconPreset,
      ),
    );
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
        final settings = _dependencies.settingsController;
        return MaterialApp(
          title: 'River Login',
          debugShowCheckedModeBanner: false,
          navigatorKey: _appNavigatorKey,
          builder: (context, child) {
            final data = MediaQuery.of(context);
            final mediaQueryChild = MediaQuery(
              data: data.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
            if (defaultTargetPlatform != TargetPlatform.android) {
              return mediaQueryChild;
            }
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _androidOverlayStyleForBrightness(
                Theme.of(context).brightness,
              ),
              child: mediaQueryChild,
            );
          },
          theme: _buildTheme(brightness: Brightness.light),
          darkTheme: _buildTheme(brightness: Brightness.dark),
          themeMode: settings.themeMode,
          home: _buildHome(),
        );
      },
    );
  }

  SystemUiOverlayStyle _androidOverlayStyleForBrightness(
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  ThemeData _buildTheme({required Brightness brightness}) {
    final settings = _dependencies.settingsController;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: settings.themeSeedColor,
      brightness: brightness,
    );
    final cornerRadius = _cornerRadiusForPreset(settings.cornerPreset);
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: settings.compactDensity
          ? VisualDensity.compact
          : VisualDensity.standard,
      splashFactory: settings.reduceMotion
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      pageTransitionsTheme: settings.reduceMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
              },
            )
          : null,
    );

    final textTheme = _applyFontWeightPreset(
      base.textTheme.apply(fontFamily: settings.fontFamilyName),
      settings.fontWeightPreset,
    );
    final primaryTextTheme = _applyFontWeightPreset(
      base.primaryTextTheme.apply(fontFamily: settings.fontFamilyName),
      settings.fontWeightPreset,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius + 4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
    );
  }

  double _cornerRadiusForPreset(AppCornerPreset preset) {
    switch (preset) {
      case AppCornerPreset.compact:
        return 10;
      case AppCornerPreset.standard:
        return 14;
      case AppCornerPreset.relaxed:
        return 20;
    }
  }

  TextTheme _applyFontWeightPreset(
    TextTheme theme,
    AppFontWeightPreset preset,
  ) {
    final delta = switch (preset) {
      AppFontWeightPreset.regular => -1,
      AppFontWeightPreset.medium => 0,
      AppFontWeightPreset.bold => 1,
    };
    if (delta == 0) {
      return theme;
    }
    return theme.copyWith(
      displayLarge: _shiftTextStyleWeight(theme.displayLarge, delta),
      displayMedium: _shiftTextStyleWeight(theme.displayMedium, delta),
      displaySmall: _shiftTextStyleWeight(theme.displaySmall, delta),
      headlineLarge: _shiftTextStyleWeight(theme.headlineLarge, delta),
      headlineMedium: _shiftTextStyleWeight(theme.headlineMedium, delta),
      headlineSmall: _shiftTextStyleWeight(theme.headlineSmall, delta),
      titleLarge: _shiftTextStyleWeight(theme.titleLarge, delta),
      titleMedium: _shiftTextStyleWeight(theme.titleMedium, delta),
      titleSmall: _shiftTextStyleWeight(theme.titleSmall, delta),
      bodyLarge: _shiftTextStyleWeight(theme.bodyLarge, delta),
      bodyMedium: _shiftTextStyleWeight(theme.bodyMedium, delta),
      bodySmall: _shiftTextStyleWeight(theme.bodySmall, delta),
      labelLarge: _shiftTextStyleWeight(theme.labelLarge, delta),
      labelMedium: _shiftTextStyleWeight(theme.labelMedium, delta),
      labelSmall: _shiftTextStyleWeight(theme.labelSmall, delta),
    );
  }

  TextStyle? _shiftTextStyleWeight(TextStyle? style, int delta) {
    if (style == null) {
      return null;
    }
    return style.copyWith(
      fontWeight: _shiftFontWeight(style.fontWeight ?? FontWeight.w400, delta),
    );
  }

  FontWeight _shiftFontWeight(FontWeight source, int delta) {
    const all = <FontWeight>[
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    var index = all.indexOf(source);
    if (index < 0) {
      index = 3;
    }
    final next = (index + delta).clamp(0, all.length - 1);
    return all[next];
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_dependencies.accountStore.hasRiverSideAccount ||
        _dependencies.accountStore.isGuestBrowsing) {
      return HomeShellPage(dependencies: _dependencies);
    }

    return LoginPage(dependencies: _dependencies);
  }
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
