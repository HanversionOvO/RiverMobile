import 'package:flutter/material.dart';
import 'package:river/app/app_settings_controller.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  static const List<Color> _themeColorOptions = <Color>[
    Color(0xFF12457A), // Default Blue
    Color(0xFF2174F1), // Bright Blue
    Color(0xFF00695C), // Teal
    Color(0xFF2E7D32), // Green
    Color(0xFFEF6C00), // Orange
    Color(0xFFB71C1C), // Red
    Color(0xFF6A1B9A), // Purple
    Color(0xFF455A64), // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('外观'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: AnimatedBuilder(
        animation: settingsController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildSectionTitle(context, '主题风格'),
              _SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('跟随系统'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('浅色'),
                              icon: Icon(Icons.wb_sunny_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('深色'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {settingsController.themeMode},
                          onSelectionChanged: (selection) {
                            settingsController.updateThemeMode(selection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionTitle(context, '强调色'),
              _SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: [
                        for (final color in _themeColorOptions)
                          _ColorOption(
                            color: color,
                            isSelected:
                                settingsController.themeSeedColor.value ==
                                color.value,
                            onTap: () =>
                                settingsController.updateThemeSeedColor(color),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionTitle(context, '阅读体验'),
              _SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('字体大小', style: TextStyle(fontSize: 16)),
                            Text(
                              '${(settingsController.fontScale * 100).round()}%',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 20,
                            ),
                          ),
                          child: Slider(
                            value: settingsController.fontScale,
                            min: 0.85,
                            max: 1.40,
                            divisions: 11,
                            onChanged: settingsController.updateFontScale,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'A',
                              style: TextStyle(
                                fontSize: 14 * 0.85,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '标准',
                              style: TextStyle(
                                fontSize: 14 * 1.0,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'A',
                              style: TextStyle(
                                fontSize: 14 * 1.4,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 24)
            : null,
      ),
    );
  }
}
