import 'package:flutter/material.dart';
import 'package:river/app/app_settings_controller.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外观设置')),
      body: AnimatedBuilder(
        animation: settingsController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                selected: <ThemeMode>{settingsController.themeMode},
                onSelectionChanged: (selection) {
                  settingsController.updateThemeMode(selection.first);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
