import 'package:flutter/material.dart';
import 'package:river/core/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RiverSideProfileWebViewPage extends StatefulWidget {
  const RiverSideProfileWebViewPage({
    super.key,
    required this.username,
    required this.title,
    this.cookieHeader,
  });

  final String username;
  final String title;
  final String? cookieHeader;

  @override
  State<RiverSideProfileWebViewPage> createState() =>
      _RiverSideProfileWebViewPageState();
}

class _RiverSideProfileWebViewPageState
    extends State<RiverSideProfileWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final profileUrl = Uri.parse(
      '$riverSideBaseUrl/u/${Uri.encodeComponent(widget.username)}',
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    final cookieHeader = widget.cookieHeader?.trim();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      _controller.loadRequest(
        profileUrl,
        headers: <String, String>{'Cookie': cookieHeader},
      );
    } else {
      _controller.loadRequest(profileUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
