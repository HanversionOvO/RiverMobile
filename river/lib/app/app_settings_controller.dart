import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river/core/config/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontWeightPreset { regular, medium, bold }

enum AppAppIconPreset { classic, riverBlue, minimal }

enum AppCornerPreset { compact, standard, relaxed }

enum AppAiProvider { deepseek, openAiCompatible }

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'app.theme_mode';
  static const String _themeSeedColorKey = 'app.theme_seed_color';
  static const String _fontScaleKey = 'app.font_scale';
  static const String _fontWeightPresetKey = 'app.font_weight_preset';
  static const String _fontFamilyNameKey = 'app.font_family_name';
  static const String _legacyFontFamilyPresetKey = 'app.font_family_preset';
  static const String _iconPresetKey = 'app.icon_preset';
  static const String _compactDensityKey = 'app.compact_density';
  static const String _reduceMotionKey = 'app.reduce_motion';
  static const String _cornerPresetKey = 'app.corner_preset';
  static const String _postsRealtimeRefreshBannerKey =
      'app.posts_realtime_refresh_banner';
  static const String _notificationsRealtimeRefreshBannerKey =
      'app.notifications_realtime_refresh_banner';
  static const String _topicCommentsRealtimeRefreshBannerKey =
      'app.topic_comments_realtime_refresh_banner';
  static const String _riverSideBaseUrlKey = 'app.riverside_base_url';
  static const String _updateManifestUrlKey = 'app.update_manifest_url';
  static const String _miniAppsManifestUrlKey = 'app.mini_apps_manifest_url';
  static const String _aiProviderKey = 'app.ai_provider';
  static const String _aiBaseUrlKey = 'app.ai_base_url';
  static const String _aiModelKey = 'app.ai_model';
  static const String _aiApiKeyKey = 'app.ai_api_key';
  static const String _aiSystemPromptKey = 'app.ai_system_prompt';
  static const String _aiTemperatureKey = 'app.ai_temperature';
  static const String _developerModeEnabledKey = 'app.developer_mode_enabled';

  static const Color defaultSeedColor = Color(0xFF12457A);
  static const String defaultAiBaseUrl =
      'https://api.deepseek.com/v1/chat/completions';
  static const String defaultAiModel = 'deepseek-chat';
  static const String defaultAiSystemPrompt =
      '你是 River App 的写作助手，请用简洁、自然、友好的中文输出，不要添加多余解释。';

  ThemeMode _themeMode = ThemeMode.system;
  Color _themeSeedColor = defaultSeedColor;
  double _fontScale = 1.0;
  AppFontWeightPreset _fontWeightPreset = AppFontWeightPreset.medium;
  String? _fontFamilyName;
  AppAppIconPreset _iconPreset = AppAppIconPreset.classic;
  AppCornerPreset _cornerPreset = AppCornerPreset.standard;
  bool _compactDensity = false;
  bool _reduceMotion = false;
  bool _showPostsRealtimeRefreshBanner = true;
  bool _showNotificationsRealtimeRefreshBanner = true;
  bool _showTopicCommentsRealtimeRefreshBanner = true;
  String _riverSideBaseUrl = RiverServerConfig.defaultBaseUrl;
  String _updateManifestUrl = RiverServerConfig.defaultUpdateManifestUrl;
  String _miniAppsManifestUrl = RiverServerConfig.defaultMiniAppsManifestUrl;
  AppAiProvider _aiProvider = AppAiProvider.deepseek;
  String _aiBaseUrl = defaultAiBaseUrl;
  String _aiModel = defaultAiModel;
  String _aiApiKey = '';
  String _aiSystemPrompt = defaultAiSystemPrompt;
  double _aiTemperature = 0.7;
  bool _developerModeEnabled = false;

  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Color get themeSeedColor => _themeSeedColor;
  double get fontScale => _fontScale;
  AppFontWeightPreset get fontWeightPreset => _fontWeightPreset;
  String? get fontFamilyName => _fontFamilyName;
  AppAppIconPreset get iconPreset => _iconPreset;
  AppCornerPreset get cornerPreset => _cornerPreset;
  bool get compactDensity => _compactDensity;
  bool get reduceMotion => _reduceMotion;
  bool get showPostsRealtimeRefreshBanner => _showPostsRealtimeRefreshBanner;
  bool get showNotificationsRealtimeRefreshBanner =>
      _showNotificationsRealtimeRefreshBanner;
  bool get showTopicCommentsRealtimeRefreshBanner =>
      _showTopicCommentsRealtimeRefreshBanner;
  String get riverSideBaseUrl => _riverSideBaseUrl;
  String get updateManifestUrl => _updateManifestUrl;
  String get miniAppsManifestUrl => _miniAppsManifestUrl;
  AppAiProvider get aiProvider => _aiProvider;
  String get aiBaseUrl => _aiBaseUrl;
  String get aiModel => _aiModel;
  String get aiApiKey => _aiApiKey;
  String get aiSystemPrompt => _aiSystemPrompt;
  double get aiTemperature => _aiTemperature;
  bool get developerModeEnabled => _developerModeEnabled;
  bool get aiConfigured =>
      _aiBaseUrl.trim().isNotEmpty &&
      _aiModel.trim().isNotEmpty &&
      _aiApiKey.trim().isNotEmpty;

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

    final fontWeightRaw = _prefs?.getString(_fontWeightPresetKey);
    if (fontWeightRaw != null) {
      for (final value in AppFontWeightPreset.values) {
        if (value.name == fontWeightRaw) {
          _fontWeightPreset = value;
          break;
        }
      }
    }

    final rawFontFamily = _prefs?.getString(_fontFamilyNameKey);
    if (rawFontFamily != null) {
      final trimmed = rawFontFamily.trim();
      _fontFamilyName = trimmed.isEmpty ? null : trimmed;
    } else {
      final legacyPreset = _prefs?.getString(_legacyFontFamilyPresetKey);
      _fontFamilyName = _mapLegacyFontPresetToFamily(legacyPreset);
    }

    final iconPresetRaw = _prefs?.getString(_iconPresetKey);
    if (iconPresetRaw != null) {
      for (final value in AppAppIconPreset.values) {
        if (value.name == iconPresetRaw) {
          _iconPreset = value;
          break;
        }
      }
    }

    final cornerPresetRaw = _prefs?.getString(_cornerPresetKey);
    if (cornerPresetRaw != null) {
      for (final value in AppCornerPreset.values) {
        if (value.name == cornerPresetRaw) {
          _cornerPreset = value;
          break;
        }
      }
    }

    _compactDensity = _prefs?.getBool(_compactDensityKey) ?? false;
    _reduceMotion = _prefs?.getBool(_reduceMotionKey) ?? false;
    _showPostsRealtimeRefreshBanner =
        _prefs?.getBool(_postsRealtimeRefreshBannerKey) ?? true;
    _showNotificationsRealtimeRefreshBanner =
        _prefs?.getBool(_notificationsRealtimeRefreshBannerKey) ?? true;
    _showTopicCommentsRealtimeRefreshBanner =
        _prefs?.getBool(_topicCommentsRealtimeRefreshBannerKey) ?? true;

    final rawBaseUrl = _prefs?.getString(_riverSideBaseUrlKey);
    if (rawBaseUrl != null && rawBaseUrl.trim().isNotEmpty) {
      try {
        _riverSideBaseUrl = RiverServerConfig.normalizeBaseUrl(rawBaseUrl);
      } catch (_) {
        _riverSideBaseUrl = RiverServerConfig.defaultBaseUrl;
      }
    }

    final rawUpdateUrl = _prefs?.getString(_updateManifestUrlKey);
    if (rawUpdateUrl != null && rawUpdateUrl.trim().isNotEmpty) {
      try {
        _updateManifestUrl = RiverServerConfig.normalizeUrl(rawUpdateUrl);
      } catch (_) {
        _updateManifestUrl = RiverServerConfig.defaultUpdateManifestUrl;
      }
    }

    final rawMiniAppsUrl = _prefs?.getString(_miniAppsManifestUrlKey);
    if (rawMiniAppsUrl != null && rawMiniAppsUrl.trim().isNotEmpty) {
      try {
        _miniAppsManifestUrl = RiverServerConfig.normalizeUrl(rawMiniAppsUrl);
      } catch (_) {
        _miniAppsManifestUrl = RiverServerConfig.defaultMiniAppsManifestUrl;
      }
    }

    final aiProviderRaw = _prefs?.getString(_aiProviderKey);
    if (aiProviderRaw != null) {
      for (final provider in AppAiProvider.values) {
        if (provider.name == aiProviderRaw) {
          _aiProvider = provider;
          break;
        }
      }
    }

    final aiBaseUrlRaw = _prefs?.getString(_aiBaseUrlKey);
    if (aiBaseUrlRaw != null && aiBaseUrlRaw.trim().isNotEmpty) {
      try {
        _aiBaseUrl = RiverServerConfig.normalizeUrl(aiBaseUrlRaw);
      } catch (_) {
        _aiBaseUrl = defaultAiBaseUrl;
      }
    }

    final aiModelRaw = _prefs?.getString(_aiModelKey);
    if (aiModelRaw != null) {
      final model = aiModelRaw.trim();
      _aiModel = model.isEmpty ? defaultAiModel : model;
    }

    final aiApiKeyRaw = _prefs?.getString(_aiApiKeyKey);
    if (aiApiKeyRaw != null) {
      _aiApiKey = aiApiKeyRaw.trim();
    }

    final aiSystemPromptRaw = _prefs?.getString(_aiSystemPromptKey);
    if (aiSystemPromptRaw != null) {
      final prompt = aiSystemPromptRaw.trim();
      _aiSystemPrompt = prompt.isEmpty ? defaultAiSystemPrompt : prompt;
    }

    final aiTemperatureRaw = _prefs?.getDouble(_aiTemperatureKey);
    if (aiTemperatureRaw != null) {
      _aiTemperature = _clampAiTemperature(aiTemperatureRaw);
    }

    _developerModeEnabled = _prefs?.getBool(_developerModeEnabledKey) ?? false;

    RiverServerConfig.instance.apply(
      baseUrl: _riverSideBaseUrl,
      updateManifestUrl: _updateManifestUrl,
      miniAppsManifestUrl: _miniAppsManifestUrl,
    );
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

  void updateFontWeightPreset(AppFontWeightPreset value) {
    if (_fontWeightPreset == value) {
      return;
    }
    _fontWeightPreset = value;
    notifyListeners();
    unawaited(_saveFontWeightPreset());
  }

  void updateFontFamilyName(String? value) {
    final next = value?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_fontFamilyName == normalized) {
      return;
    }
    _fontFamilyName = normalized;
    notifyListeners();
    unawaited(_saveFontFamilyName());
  }

  void updateIconPreset(AppAppIconPreset value) {
    if (_iconPreset == value) {
      return;
    }
    _iconPreset = value;
    notifyListeners();
    unawaited(_saveIconPreset());
  }

  void updateCompactDensity(bool value) {
    if (_compactDensity == value) {
      return;
    }
    _compactDensity = value;
    notifyListeners();
    unawaited(_saveCompactDensity());
  }

  void updateReduceMotion(bool value) {
    if (_reduceMotion == value) {
      return;
    }
    _reduceMotion = value;
    notifyListeners();
    unawaited(_saveReduceMotion());
  }

  void updateCornerPreset(AppCornerPreset value) {
    if (_cornerPreset == value) {
      return;
    }
    _cornerPreset = value;
    notifyListeners();
    unawaited(_saveCornerPreset());
  }

  void updateShowPostsRealtimeRefreshBanner(bool value) {
    if (_showPostsRealtimeRefreshBanner == value) {
      return;
    }
    _showPostsRealtimeRefreshBanner = value;
    notifyListeners();
    unawaited(_saveShowPostsRealtimeRefreshBanner());
  }

  void updateShowNotificationsRealtimeRefreshBanner(bool value) {
    if (_showNotificationsRealtimeRefreshBanner == value) {
      return;
    }
    _showNotificationsRealtimeRefreshBanner = value;
    notifyListeners();
    unawaited(_saveShowNotificationsRealtimeRefreshBanner());
  }

  void updateShowTopicCommentsRealtimeRefreshBanner(bool value) {
    if (_showTopicCommentsRealtimeRefreshBanner == value) {
      return;
    }
    _showTopicCommentsRealtimeRefreshBanner = value;
    notifyListeners();
    unawaited(_saveShowTopicCommentsRealtimeRefreshBanner());
  }

  void updateRiverSideBaseUrl(String value) {
    final normalized = RiverServerConfig.normalizeBaseUrl(value);
    if (_riverSideBaseUrl == normalized) {
      return;
    }
    _riverSideBaseUrl = normalized;
    RiverServerConfig.instance.updateBaseUrl(normalized);
    notifyListeners();
    unawaited(_saveRiverSideBaseUrl());
  }

  void updateUpdateManifestUrl(String value) {
    final normalized = RiverServerConfig.normalizeUrl(value);
    if (_updateManifestUrl == normalized) {
      return;
    }
    _updateManifestUrl = normalized;
    RiverServerConfig.instance.setUpdateManifestUrl(normalized);
    notifyListeners();
    unawaited(_saveUpdateManifestUrl());
  }

  void updateMiniAppsManifestUrl(String value) {
    final normalized = RiverServerConfig.normalizeUrl(value);
    if (_miniAppsManifestUrl == normalized) {
      return;
    }
    _miniAppsManifestUrl = normalized;
    RiverServerConfig.instance.setMiniAppsManifestUrl(normalized);
    notifyListeners();
    unawaited(_saveMiniAppsManifestUrl());
  }

  void updateAiProvider(AppAiProvider value) {
    if (_aiProvider == value) {
      return;
    }
    _aiProvider = value;
    notifyListeners();
    unawaited(_saveAiProvider());
  }

  void updateAiBaseUrl(String value) {
    final normalized = RiverServerConfig.normalizeUrl(value);
    if (_aiBaseUrl == normalized) {
      return;
    }
    _aiBaseUrl = normalized;
    notifyListeners();
    unawaited(_saveAiBaseUrl());
  }

  void updateAiModel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || _aiModel == normalized) {
      return;
    }
    _aiModel = normalized;
    notifyListeners();
    unawaited(_saveAiModel());
  }

  void updateAiApiKey(String value) {
    final normalized = value.trim();
    if (_aiApiKey == normalized) {
      return;
    }
    _aiApiKey = normalized;
    notifyListeners();
    unawaited(_saveAiApiKey());
  }

  void updateAiSystemPrompt(String value) {
    final normalized = value.trim();
    final next = normalized.isEmpty ? defaultAiSystemPrompt : normalized;
    if (_aiSystemPrompt == next) {
      return;
    }
    _aiSystemPrompt = next;
    notifyListeners();
    unawaited(_saveAiSystemPrompt());
  }

  void updateAiTemperature(double value) {
    final next = _clampAiTemperature(value);
    if ((_aiTemperature - next).abs() < 0.001) {
      return;
    }
    _aiTemperature = next;
    notifyListeners();
    unawaited(_saveAiTemperature());
  }

  void updateDeveloperModeEnabled(bool value) {
    if (_developerModeEnabled == value) {
      return;
    }
    _developerModeEnabled = value;
    notifyListeners();
    unawaited(_saveDeveloperModeEnabled());
  }

  String? _mapLegacyFontPresetToFamily(String? presetName) {
    switch (presetName) {
      case 'system':
        return null;
      case 'sans':
        return 'sans-serif';
      case 'sansThin':
        return 'sans-serif-thin';
      case 'sansLight':
        return 'sans-serif-light';
      case 'sansMedium':
        return 'sans-serif-medium';
      case 'sansBlack':
        return 'sans-serif-black';
      case 'rounded':
        return 'sans-serif-rounded';
      case 'condensed':
        return 'sans-serif-condensed';
      case 'condensedMedium':
        return 'sans-serif-condensed-medium';
      case 'smallCaps':
        return 'sans-serif-smallcaps';
      case 'serif':
        return 'serif';
      case 'monospace':
        return 'monospace';
      default:
        return null;
    }
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

  double _clampAiTemperature(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 2) {
      return 2;
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

  Future<void> _saveFontWeightPreset() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_fontWeightPresetKey, _fontWeightPreset.name);
  }

  Future<void> _saveFontFamilyName() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_fontFamilyNameKey, _fontFamilyName ?? '');
  }

  Future<void> _saveIconPreset() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_iconPresetKey, _iconPreset.name);
  }

  Future<void> _saveCompactDensity() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_compactDensityKey, _compactDensity);
  }

  Future<void> _saveReduceMotion() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_reduceMotionKey, _reduceMotion);
  }

  Future<void> _saveCornerPreset() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_cornerPresetKey, _cornerPreset.name);
  }

  Future<void> _saveShowPostsRealtimeRefreshBanner() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(
      _postsRealtimeRefreshBannerKey,
      _showPostsRealtimeRefreshBanner,
    );
  }

  Future<void> _saveShowNotificationsRealtimeRefreshBanner() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(
      _notificationsRealtimeRefreshBannerKey,
      _showNotificationsRealtimeRefreshBanner,
    );
  }

  Future<void> _saveShowTopicCommentsRealtimeRefreshBanner() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(
      _topicCommentsRealtimeRefreshBannerKey,
      _showTopicCommentsRealtimeRefreshBanner,
    );
  }

  Future<void> _saveRiverSideBaseUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_riverSideBaseUrlKey, _riverSideBaseUrl);
  }

  Future<void> _saveUpdateManifestUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_updateManifestUrlKey, _updateManifestUrl);
  }

  Future<void> _saveMiniAppsManifestUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_miniAppsManifestUrlKey, _miniAppsManifestUrl);
  }

  Future<void> _saveAiProvider() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_aiProviderKey, _aiProvider.name);
  }

  Future<void> _saveAiBaseUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_aiBaseUrlKey, _aiBaseUrl);
  }

  Future<void> _saveAiModel() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_aiModelKey, _aiModel);
  }

  Future<void> _saveAiApiKey() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_aiApiKeyKey, _aiApiKey);
  }

  Future<void> _saveAiSystemPrompt() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_aiSystemPromptKey, _aiSystemPrompt);
  }

  Future<void> _saveAiTemperature() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble(_aiTemperatureKey, _aiTemperature);
  }

  Future<void> _saveDeveloperModeEnabled() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_developerModeEnabledKey, _developerModeEnabled);
  }
}
