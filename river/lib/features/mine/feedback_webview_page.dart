import 'package:flutter/material.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String riverFeedbackUrl = 'https://query.hanversion.cn/s/TDuOCWMP';

class FeedbackWebViewPage extends StatefulWidget {
  const FeedbackWebViewPage({super.key});

  @override
  State<FeedbackWebViewPage> createState() => _FeedbackWebViewPageState();
}

class _FeedbackWebViewPageState extends State<FeedbackWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = riverFeedbackUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onNavigationRequest: (request) {
            if (!mounted) {
              return NavigationDecision.navigate;
            }
            setState(() {
              _currentUrl = request.url;
            });
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(riverFeedbackUrl));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(_currentUrl.trim()) ?? Uri.parse(riverFeedbackUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('无法打开链接'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MineSettingsAppBar(
        title: '反馈',
        subtitle: '问题反馈与建议',
        icon: Icons.feedback_outlined,
        heroTagPrefix: 'mine_settings_feedback',
        actions: [
          IconButton(
            tooltip: '外部打开',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
