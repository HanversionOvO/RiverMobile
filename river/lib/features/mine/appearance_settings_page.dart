import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/platform/app_icon_switcher.dart';
import 'package:river/core/platform/system_fonts_bridge.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

part 'appearance_settings_widgets.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  static const String _systemDefaultToken = '__system_default__';

  static const List<Color> _themeColorOptions = <Color>[
    Color(0xFF12457A),
    Color(0xFF2174F1),
    Color(0xFF2E7D32),
    Color(0xFF00897B),
    Color(0xFFF57C00),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFF546E7A),
  ];

  static const Set<int> _presetColorValues = <int>{
    0xFF12457A,
    0xFF2174F1,
    0xFF2E7D32,
    0xFF00897B,
    0xFFF57C00,
    0xFFE53935,
    0xFF8E24AA,
    0xFF546E7A,
  };

  static const List<_IconOption> _iconOptions = <_IconOption>[
    _IconOption(
      preset: AppAppIconPreset.classic,
      title: '经典',
      assetPath: 'assets/images/app_icon_classic.png',
    ),
    _IconOption(
      preset: AppAppIconPreset.riverBlue,
      title: 'RiverSide',
      assetPath: 'assets/images/rs.png',
    ),
    _IconOption(
      preset: AppAppIconPreset.minimal,
      title: '清水河畔',
      assetPath: 'assets/images/hp.png',
    ),
  ];

  List<String> _systemFonts = const <String>[];
  bool _fontsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSystemFonts();
  }

  Future<void> _loadSystemFonts() async {
    final fonts = await SystemFontsBridge.getSystemFonts();
    if (!mounted) {
      return;
    }
    setState(() {
      _systemFonts = fonts;
      _fontsLoading = false;
    });
  }

  Future<void> _pickCustomAccentColor(Color current) async {
    var selected = current;
    final result = await showModalBottomSheet<Color>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.36,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '自定义强调色',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '使用系统调色盘，实时预览主题主色',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: selected,
                      onColorChanged: (color) =>
                          setState(() => selected = color),
                      enableAlpha: false,
                      labelTypes: const [],
                      pickerAreaHeightPercent: 0.7,
                      displayThumbColor: true,
                      portraitOnly: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
                            child: const Text('应用颜色'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }
    widget.settingsController.updateThemeSeedColor(result);
  }

  Future<void> _applyIconPreset(AppAppIconPreset preset) async {
    if (widget.settingsController.iconPreset == preset) {
      return;
    }
    widget.settingsController.updateIconPreset(preset);
    final applied = await AppIconSwitcher.switchToPreset(preset);
    if (!mounted || applied) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('当前平台暂不支持即时切换图标，已保存你的选择'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fontDisplayName(String? family) {
    if (family == null || family.trim().isEmpty) {
      return '系统默认';
    }
    return family;
  }

  List<String> _effectiveFonts(String? current) {
    final set = <String>{..._systemFonts};
    if (current != null && current.trim().isNotEmpty) {
      set.add(current.trim());
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _openFontPicker(AppSettingsController settings) async {
    if (!_fontsLoading) {
      await _loadSystemFonts();
    }

    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FontPickerSheet(
          fonts: _effectiveFonts(settings.fontFamilyName),
          selectedFamily: settings.fontFamilyName,
          systemDefaultToken: _systemDefaultToken,
        );
      },
    );
    if (selected == null) {
      return;
    }
    if (selected == _systemDefaultToken) {
      settings.updateFontFamilyName(null);
    } else {
      settings.updateFontFamilyName(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MineSettingsAppBar(
        title: '外观',
        subtitle: '应用基础外观自定义设置',
        icon: Icons.palette_outlined,
        heroTagPrefix: 'mine_settings_appearance',
      ),
      body: AnimatedBuilder(
        animation: widget.settingsController,
        builder: (context, _) {
          final settings = widget.settingsController;
          final currentColor = settings.themeSeedColor;
          final isCustomColor = !_presetColorValues.contains(
            currentColor.toARGB32(),
          );
          final fontName = settings.fontFamilyName;
          final fontCount = _effectiveFonts(fontName).length + 1;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SettingsSection(
                title: '主题模式',
                subtitle: '选择浅色、深色或跟随系统',
                child: _PillWrap<ThemeMode>(
                  selected: settings.themeMode,
                  options: const [
                    _PillOption(
                      value: ThemeMode.system,
                      label: '跟随系统',
                      icon: Icons.brightness_auto_outlined,
                    ),
                    _PillOption(
                      value: ThemeMode.light,
                      label: '浅色',
                      icon: Icons.light_mode_outlined,
                    ),
                    _PillOption(
                      value: ThemeMode.dark,
                      label: '深色',
                      icon: Icons.dark_mode_outlined,
                    ),
                  ],
                  onChanged: settings.updateThemeMode,
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: '强调色',
                subtitle: '预设色板 + 自定义调色盘',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _themeColorOptions)
                      _ColorDot(
                        color: color,
                        selected:
                            settings.themeSeedColor.toARGB32() ==
                            color.toARGB32(),
                        onTap: () => settings.updateThemeSeedColor(color),
                      ),
                    _CustomColorDot(
                      currentColor: currentColor,
                      selected: isCustomColor,
                      onTap: () => _pickCustomAccentColor(currentColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: '字体与排版',
                subtitle: '字号、字重、字体选择',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelRow(
                      icon: Icons.format_size_rounded,
                      title: '字体大小',
                      trailing: '${(settings.fontScale * 100).round()}%',
                    ),
                    Slider(
                      value: settings.fontScale,
                      min: 0.85,
                      max: 1.4,
                      divisions: 11,
                      onChanged: settings.updateFontScale,
                    ),
                    const SizedBox(height: 4),
                    _LabelRow(icon: Icons.line_weight_rounded, title: '字体粗细'),
                    const SizedBox(height: 8),
                    _PillWrap<AppFontWeightPreset>(
                      selected: settings.fontWeightPreset,
                      options: const [
                        _PillOption(
                          value: AppFontWeightPreset.regular,
                          label: '偏细',
                          icon: Icons.format_bold_outlined,
                        ),
                        _PillOption(
                          value: AppFontWeightPreset.medium,
                          label: '标准',
                          icon: Icons.format_bold_rounded,
                        ),
                        _PillOption(
                          value: AppFontWeightPreset.bold,
                          label: '偏粗',
                          icon: Icons.format_bold,
                        ),
                      ],
                      onChanged: settings.updateFontWeightPreset,
                    ),
                    const SizedBox(height: 14),
                    _LabelRow(
                      icon: Icons.font_download_outlined,
                      title: '字体选择',
                    ),
                    const SizedBox(height: 10),
                    _CurrentFontCard(
                      fontName: _fontDisplayName(fontName),
                      actualFamily: fontName,
                      loading: _fontsLoading,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openFontPicker(settings),
                            icon: const Icon(Icons.manage_search_rounded),
                            label: Text(
                              _fontsLoading
                                  ? '正在读取系统字体...'
                                  : '全部字体 ($fontCount)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: '界面与个性化',
                subtitle: '圆角、布局密度与动效',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelRow(
                      icon: Icons.rounded_corner_rounded,
                      title: '圆角风格',
                    ),
                    const SizedBox(height: 8),
                    _PillWrap<AppCornerPreset>(
                      selected: settings.cornerPreset,
                      options: const [
                        _PillOption(
                          value: AppCornerPreset.compact,
                          label: '紧凑',
                        ),
                        _PillOption(
                          value: AppCornerPreset.standard,
                          label: '标准',
                        ),
                        _PillOption(
                          value: AppCornerPreset.relaxed,
                          label: '圆润',
                        ),
                      ],
                      onChanged: settings.updateCornerPreset,
                    ),
                    const SizedBox(height: 14),
                    _SwitchTile(
                      icon: Icons.view_compact_alt_outlined,
                      title: '紧凑布局',
                      subtitle: '减少间距，单屏展示更多信息',
                      value: settings.compactDensity,
                      onChanged: settings.updateCompactDensity,
                    ),
                    const SizedBox(height: 8),
                    _SwitchTile(
                      icon: Icons.motion_photos_off_outlined,
                      title: '减少动效',
                      subtitle: '降低过渡动画，减少视觉干扰',
                      value: settings.reduceMotion,
                      onChanged: settings.updateReduceMotion,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: '应用图标',
                subtitle: '左右滑动查看更多图标',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _iconOptions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _IconChoiceCard(
                          option: _iconOptions[i],
                          selected:
                              settings.iconPreset == _iconOptions[i].preset,
                          onTap: () => _applyIconPreset(_iconOptions[i].preset),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
