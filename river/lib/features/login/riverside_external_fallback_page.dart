import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/features/login/riverside_password_login_service.dart';

Future<UserAccount?> showRiverSideCredentialLoginSheet({
  required BuildContext context,
  required AppDependencies dependencies,
  String? detectedWebViewVersion,
}) {
  return showModalBottomSheet<UserAccount>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _RiverSideCredentialLoginSheet(
        dependencies: dependencies,
        detectedWebViewVersion: detectedWebViewVersion,
      );
    },
  );
}

class RiverSideExternalFallbackPage extends StatelessWidget {
  const RiverSideExternalFallbackPage({
    super.key,
    required this.dependencies,
    this.detectedWebViewVersion,
  });

  final AppDependencies dependencies;
  final String? detectedWebViewVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号密码登录')),
      body: _RiverSideCredentialLoginSheetBody(
        dependencies: dependencies,
        detectedWebViewVersion: detectedWebViewVersion,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _RiverSideCredentialLoginSheet extends StatelessWidget {
  const _RiverSideCredentialLoginSheet({
    required this.dependencies,
    this.detectedWebViewVersion,
  });

  final AppDependencies dependencies;
  final String? detectedWebViewVersion;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return Padding(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: _RiverSideCredentialLoginSheetBody(
              dependencies: dependencies,
              detectedWebViewVersion: detectedWebViewVersion,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiverSideCredentialLoginSheetBody extends StatefulWidget {
  const _RiverSideCredentialLoginSheetBody({
    required this.dependencies,
    required this.onClose,
    this.detectedWebViewVersion,
  });

  final AppDependencies dependencies;
  final VoidCallback onClose;
  final String? detectedWebViewVersion;

  @override
  State<_RiverSideCredentialLoginSheetBody> createState() =>
      _RiverSideCredentialLoginSheetBodyState();
}

class _RiverSideCredentialLoginSheetBodyState
    extends State<_RiverSideCredentialLoginSheetBody> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    final account = _accountController.text.trim();
    final password = _passwordController.text;

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
    final theme = Theme.of(context);
    final versionTip =
        widget.detectedWebViewVersion == null ||
            widget.detectedWebViewVersion!.isEmpty
        ? null
        : 'WebView ${widget.detectedWebViewVersion}';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '账号密码登录',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '用于 WebView 不可用或异常场景',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (versionTip != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.55),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                versionTip,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: _accountController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        hintText: '用户名或邮箱',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入账号';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_submitting,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _submitLogin(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        hintText: '请输入密码',
                        prefixIcon: const Icon(Icons.password_rounded),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submitLogin,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_submitting ? '登录中...' : '登录并继续'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
