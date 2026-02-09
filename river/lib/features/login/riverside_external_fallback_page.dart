import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/features/login/riverside_password_login_service.dart';

class RiverSideExternalFallbackPage extends StatefulWidget {
  const RiverSideExternalFallbackPage({
    super.key,
    required this.dependencies,
    this.detectedWebViewVersion,
  });

  final AppDependencies dependencies;
  final String? detectedWebViewVersion;

  @override
  State<RiverSideExternalFallbackPage> createState() =>
      _RiverSideExternalFallbackPageState();
}

class _RiverSideExternalFallbackPageState
    extends State<RiverSideExternalFallbackPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_submitting) {
      return;
    }

    final account = _accountController.text.trim();
    final password = _passwordController.text;
    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入账号和密码')));
      return;
    }

    setState(() {
      _submitting = true;
    });

    final service = RiverSidePasswordLoginService(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
    );

    try {
      final result = await service.login(login: account, password: password);
      final profile = result.profile;

      await widget.dependencies.accountStore.upsertRiverSideAccount(profile);
      await widget.dependencies.accountStore.upsertRiverSideCookieHeader(
        username: profile.username,
        cookieHeader: result.cookieHeader,
      );
      await widget.dependencies.accountStore.switchActiveRiverSideAccount(
        profile.username,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop<UserAccount>(profile);
    } on RiverSidePasswordLoginException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionTip =
        widget.detectedWebViewVersion == null ||
            widget.detectedWebViewVersion!.isEmpty
        ? ''
        : '\nWebView: ${widget.detectedWebViewVersion}';

    return Scaffold(
      appBar: AppBar(title: const Text('RiverSide 登录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(
            '当前设备内置 WebView 不可用，请直接输入 RiverSide 账号密码登录。$versionTip',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _accountController,
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '账号',
              hintText: '用户名或邮箱',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_submitting,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _submitLogin(),
            decoration: InputDecoration(
              labelText: '密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submitLogin,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}
