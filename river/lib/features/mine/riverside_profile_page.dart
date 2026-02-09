import 'package:flutter/material.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RiverSideProfilePage extends StatefulWidget {
  const RiverSideProfilePage({
    super.key,
    required this.account,
    this.cookieHeader,
  });

  final UserAccount account;
  final String? cookieHeader;

  @override
  State<RiverSideProfilePage> createState() => _RiverSideProfilePageState();
}

class _RiverSideProfilePageState extends State<RiverSideProfilePage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final profileUrl = Uri.parse(
      '$riverSideBaseUrl/u/${Uri.encodeComponent(widget.account.username)}',
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
    final title = widget.account.displayName.isEmpty
        ? widget.account.username
        : widget.account.displayName;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
