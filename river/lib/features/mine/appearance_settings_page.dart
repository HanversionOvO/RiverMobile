import 'package:flutter/material.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/storage/app_cache_service.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  static const List<Color> _themeColorOptions = <Color>[
    Color(0xFF12457A),
    Color(0xFF2174F1),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFFB71C1C),
    Color(0xFF6A1B9A),
  ];

  bool _loadingCacheSize = true;
  bool _clearingCache = false;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingCacheSize = true;
    });

    final bytes = await AppCacheService.calculateCacheBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _cacheBytes = bytes;
      _loadingCacheSize = false;
    });
  }

  Future<void> _clearCache() async {
    if (_clearingCache) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清除缓存'),
          content: Text('当前缓存约 ${_formatBytes(_cacheBytes)}，确认清除吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _clearingCache = true;
    });

    await AppCacheService.clearCache();
    await _refreshCacheSize();

    if (!mounted) {
      return;
    }

    setState(() {
      _clearingCache = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final fraction = unitIndex <= 1 ? 0 : 2;
    return '${value.toStringAsFixed(fraction)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController;

    return Scaffold(
      appBar: AppBar(title: const Text('外观与缓存')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('主题模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('跟随系统'),
                    icon: Icon(Icons.settings_suggest_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('浅色'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('深色'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: <ThemeMode>{settings.themeMode},
                onSelectionChanged: (selection) {
                  settings.updateThemeMode(selection.first);
                },
              ),
              const SizedBox(height: 20),
              Text('主题颜色', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in _themeColorOptions)
                    ChoiceChip(
                      selected:
                          settings.themeSeedColor.toARGB32() ==
                          color.toARGB32(),
                      label: const SizedBox(width: 20, height: 20),
                      avatar: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                      onSelected: (_) => settings.updateThemeSeedColor(color),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('字体大小', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前：${(settings.fontScale * 100).toStringAsFixed(0)}%',
                      ),
                      Slider(
                        value: settings.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label:
                            '${(settings.fontScale * 100).toStringAsFixed(0)}%',
                        onChanged: settings.updateFontScale,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('缓存', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('清除缓存'),
                  subtitle: Text(
                    _loadingCacheSize
                        ? '正在计算缓存大小...'
                        : '当前缓存：${_formatBytes(_cacheBytes)}',
                  ),
                  trailing: _clearingCache
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _clearingCache ? null : _clearCache,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
