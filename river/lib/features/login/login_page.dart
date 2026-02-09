import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:river/features/login/riverside_external_fallback_page.dart';
import 'package:river/features/login/riverside_login_webview_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _checkingWebView = false;

  Future<void> _openExternalBrowserLogin({
    String? detectedWebViewVersion,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RiverSideExternalFallbackPage(
          dependencies: widget.dependencies,
          detectedWebViewVersion: detectedWebViewVersion,
        ),
      ),
    );

    if (!mounted || completed != true) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeShellPage(dependencies: widget.dependencies),
      ),
      (_) => false,
    );
  }

  Future<void> _onRiverSideLoginPressed() async {
    if (_checkingWebView) {
      return;
    }

    setState(() {
      _checkingWebView = true;
    });

    final support = await RiverSideWebViewSupport.check();
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingWebView = false;
    });

    if (support.canUseEmbeddedWebView) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RiverSideLoginWebViewPage(dependencies: widget.dependencies),
        ),
      );
      return;
    }

    await _openExternalBrowserLogin(
      detectedWebViewVersion: support.detectedVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                '欢迎来到 River',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                width: 220,
                child: Lottie.network(
                  'https://assets1.lottiefiles.com/packages/lf20_jcikwtux.json',
                  fit: BoxFit.contain,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _checkingWebView ? null : _onRiverSideLoginPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12457A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _checkingWebView
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登录至RiverSide'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('清水河畔登录暂未实现')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2174F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('登录至清水河畔'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
