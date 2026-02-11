import 'dart:ui'; // 用于 ImageFilter

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/home/home_shell_page.dart';
import 'package:river/features/login/riverside_external_fallback_page.dart';
import 'package:river/features/login/riverside_login_webview_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _checkingWebView = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // 初始化入场动画控制器
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    // 启动动画
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _openCredentialLogin({String? detectedWebViewVersion}) async {
    final profile = await Navigator.of(context).push<UserAccount>(
      riverPageRoute<UserAccount>(
        builder: (_) => RiverSideExternalFallbackPage(
          dependencies: widget.dependencies,
          detectedWebViewVersion: detectedWebViewVersion,
        ),
      ),
    );

    if (!mounted || profile == null) {
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
        riverPageRoute<void>(
          builder: (_) =>
              RiverSideLoginWebViewPage(dependencies: widget.dependencies),
        ),
      );
      return;
    }

    await _openCredentialLogin(detectedWebViewVersion: support.detectedVersion);
  }

  @override
  Widget build(BuildContext context) {
    // 定义主题色，保持原有蓝色基调但更柔和
    final primaryColor = const Color(0xFF12457A);
    final secondaryColor = const Color(0xFF2174F1);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. 背景层：柔和的渐变
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                    Colors.blue.shade100.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // 2. 装饰层：右上角和左下角的模糊光晕，增加氛围感
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurCircle(Colors.blue.withOpacity(0.1), 200),
          ),
          Positioned(
            bottom: 100,
            left: -30,
            child: _buildBlurCircle(Colors.indigo.withOpacity(0.05), 150),
          ),

          // 3. 内容层
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Logo 动画区域
                      Hero(
                        tag: 'login_logo',
                        child: Container(
                          height: 240,
                          width: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Lottie.network(
                            'https://assets1.lottiefiles.com/packages/lf20_jcikwtux.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 标题
                      Text(
                        '欢迎来到 River',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '连接清水河畔的即时桥梁',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(flex: 3),

                      // 登录按钮区域
                      Column(
                        children: [
                          _buildLoginButton(
                            onPressed: _checkingWebView
                                ? null
                                : _onRiverSideLoginPressed,
                            isLoading: _checkingWebView,
                            label: '登录至 RiverSide',
                            icon: Icons.water_drop_rounded,
                            backgroundColor: primaryColor,
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          _buildLoginButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('清水河畔登录接口开发中...'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            isLoading: false,
                            label: '登录至清水河畔',
                            icon: Icons.school_rounded,
                            backgroundColor: secondaryColor.withOpacity(0.1),
                            textColor: secondaryColor,
                            isOutlined: true, // 次要按钮使用描边或浅色背景风格
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
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

  // 辅助方法：构建模糊光晕背景
  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // 辅助方法：构建通用的登录按钮
  Widget _buildLoginButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    bool isOutlined = false,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: isOutlined ? 0 : 4,
      shadowColor: isOutlined
          ? Colors.transparent
          : backgroundColor.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: const StadiumBorder(), // 胶囊形状
      minimumSize: const Size(double.infinity, 56),
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
