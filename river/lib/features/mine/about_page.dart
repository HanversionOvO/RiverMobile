import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  int _devTapCount = 0;
  DateTime? _lastDevTapAt;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  void _onVersionTap() {
    final now = DateTime.now();
    final last = _lastDevTapAt;
    _lastDevTapAt = now;

    if (widget.settingsController.developerModeEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开发者模式已开启')));
      return;
    }

    if (last == null || now.difference(last).inSeconds > 2) {
      _devTapCount = 1;
    } else {
      _devTapCount += 1;
    }

    final remain = 8 - _devTapCount;
    if (remain <= 0) {
      widget.settingsController.updateDeveloperModeEnabled(true);
      _devTapCount = 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开发者模式已开启')));
      return;
    }

    if (remain <= 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('再点击 $remain 次开启开发者模式')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const MineSettingsAppBar(
        title: '关于 River',
        subtitle: '应用信息与项目说明',
        icon: Icons.info_outline_rounded,
        heroTagPrefix: 'mine_settings_about',
      ),
      body: Center(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.waves_rounded,
                size: 56,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'River',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  'Version $_version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                '连接清水河畔的即时桥梁。\n基于 Flutter 构建，旨在提供流畅、现代的社区体验。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ),
            const Spacer(flex: 3),
            Text(
              '© ${DateTime.now().year} River Project',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
