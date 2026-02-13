import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/navigation/river_page_route.dart';
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

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  static const Color _riverSideColor = Color(0xFF12457A);
  static const Color _qingShuiColor = Color(0xFF2174F1);

  bool _checkingWebView = false;
  bool _enteringGuest = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _openCredentialLogin({String? detectedWebViewVersion}) async {
    final profile = await showRiverSideCredentialLoginSheet(
      context: context,
      dependencies: widget.dependencies,
      detectedWebViewVersion: detectedWebViewVersion,
    );
    if (!mounted || profile == null) {
      return;
    }
    await widget.dependencies.accountStore.setGuestBrowsing(false);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      riverPageRoute<void>(
        builder: (_) => HomeShellPage(dependencies: widget.dependencies),
      ),
      (_) => false,
    );
  }

  Future<void> _onRiverSideLoginPressed() async {
    if (_checkingWebView || _enteringGuest) {
      return;
    }
    await widget.dependencies.accountStore.setGuestBrowsing(false);
    if (!mounted) {
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
        riverPageRoute<void>(
          builder: (_) =>
              RiverSideLoginWebViewPage(dependencies: widget.dependencies),
        ),
      );
      return;
    }
    await _openCredentialLogin(detectedWebViewVersion: support.detectedVersion);
  }

  Future<void> _enterAsGuest() async {
    if (_checkingWebView || _enteringGuest) {
      return;
    }
    setState(() {
      _enteringGuest = true;
    });
    await widget.dependencies.accountStore.setGuestBrowsing(true);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      riverPageRoute<void>(
        builder: (_) => HomeShellPage(dependencies: widget.dependencies),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFEAF3FF),
                    Color(0xFFF8FBFF),
                    Color(0xFFE8F1FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -42,
            right: -54,
            child: _buildGlowCircle(
              color: _qingShuiColor.withValues(alpha: 0.14),
              size: 188,
            ),
          ),
          Positioned(
            bottom: 110,
            left: -38,
            child: _buildGlowCircle(
              color: _riverSideColor.withValues(alpha: 0.10),
              size: 170,
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: Column(
                    children: [
                      const Spacer(),
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Lottie.asset(
                            'assets/lottie/login_welcome.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '欢迎来到 River',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _riverSideColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '连接 RiverSide 与清水河畔',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(flex: 2),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.88,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildLoginButton(
                              label: '登录至 RiverSide',
                              onPressed: _checkingWebView
                                  ? null
                                  : _onRiverSideLoginPressed,
                              isLoading: _checkingWebView,
                              backgroundColor: _riverSideColor,
                              foregroundColor: Colors.white,
                              leading: _buildAssetIcon(
                                assetPath: 'assets/images/rs.png',
                                fallbackIcon: Icons.public_rounded,
                                fallbackColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildLoginButton(
                              label: '登录至清水河畔',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('清水河畔登录接口开发中...'),
                                  ),
                                );
                              },
                              isLoading: false,
                              backgroundColor: _qingShuiColor,
                              foregroundColor: Colors.white,
                              leading: _buildAssetIcon(
                                assetPath: 'assets/images/hp.png',
                                fallbackIcon: Icons.school_rounded,
                                fallbackColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _enterAsGuest,
                              icon: _enteringGuest
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.explore_outlined),
                              label: const Text('以游客身份浏览'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowCircle({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildAssetIcon({
    required String assetPath,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(fallbackIcon, size: 16, color: fallbackColor);
        },
      ),
    );
  }

  Widget _buildLoginButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
    required Color backgroundColor,
    required Color foregroundColor,
    required Widget leading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
