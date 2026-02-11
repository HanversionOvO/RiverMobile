import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'app.theme_mode';
  static const String _themeSeedColorKey = 'app.theme_seed_color';
  static const String _fontScaleKey = 'app.font_scale';

  static const Color defaultSeedColor = Color(0xFF12457A);

  ThemeMode _themeMode = ThemeMode.system;
  Color _themeSeedColor = defaultSeedColor;
  double _fontScale = 1.0;

  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Color get themeSeedColor => _themeSeedColor;
  double get fontScale => _fontScale;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    final themeModeRaw = _prefs?.getString(_themeModeKey);
    if (themeModeRaw != null) {
      for (final mode in ThemeMode.values) {
        if (mode.name == themeModeRaw) {
          _themeMode = mode;
          break;
        }
      }
    }

    final seedColorValue = _prefs?.getInt(_themeSeedColorKey);
    if (seedColorValue != null) {
      _themeSeedColor = Color(seedColorValue);
    }

    final scaleValue = _prefs?.getDouble(_fontScaleKey);
    if (scaleValue != null) {
      _fontScale = _clampFontScale(scaleValue);
    }
  }

  void updateThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }

    _themeMode = value;
    notifyListeners();
    unawaited(_saveThemeMode());
  }

  void updateThemeSeedColor(Color value) {
    if (_themeSeedColor.toARGB32() == value.toARGB32()) {
      return;
    }

    _themeSeedColor = value;
    notifyListeners();
    unawaited(_saveThemeSeedColor());
  }

  void updateFontScale(double value) {
    final next = _clampFontScale(value);
    if ((_fontScale - next).abs() < 0.001) {
      return;
    }

    _fontScale = next;
    notifyListeners();
    unawaited(_saveFontScale());
  }

  double _clampFontScale(double value) {
    if (value < 0.85) {
      return 0.85;
    }
    if (value > 1.4) {
      return 1.4;
    }
    return value;
  }

  Future<void> _saveThemeMode() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_themeModeKey, _themeMode.name);
  }

  Future<void> _saveThemeSeedColor() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_themeSeedColorKey, _themeSeedColor.toARGB32());
  }

  Future<void> _saveFontScale() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble(_fontScaleKey, _fontScale);
  }
}
