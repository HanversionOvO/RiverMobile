import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:url_launcher/url_launcher.dart';

class RiverSideExternalFallbackPage extends StatelessWidget {
  const RiverSideExternalFallbackPage({
    super.key,
    required this.dependencies,
    this.detectedWebViewVersion,
  });

  final AppDependencies dependencies;
  final String? detectedWebViewVersion;

  Future<void> _openExternalBrowser(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(riverSideLoginUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开外部浏览器')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionTip =
        detectedWebViewVersion == null || detectedWebViewVersion!.isEmpty
        ? ''
        : '\n\nWebView: $detectedWebViewVersion';

    return Scaffold(
      appBar: AppBar(title: const Text('RiverSide')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              '检测到设备内置 WebView 版本过低或不可用，已自动切换到外部浏览器登录。$versionTip',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _openExternalBrowser(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12457A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('使用系统浏览器登录'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => HomeShellPage(dependencies: dependencies),
                  ),
                  (_) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('我已登录，进入主页'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
