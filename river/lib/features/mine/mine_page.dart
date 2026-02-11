import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 新增引入
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/login/riverside_external_fallback_page.dart';
import 'package:river/features/login/riverside_login_flow_mode.dart';
import 'package:river/features/login/riverside_login_webview_page.dart';
import 'package:river/features/mine/about_page.dart';
import 'package:river/features/mine/appearance_settings_page.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  // ---------------------------------------------------------------------------
  // 状态与逻辑
  // ---------------------------------------------------------------------------
  bool _isBusy = false;
  String _appVersion = ''; // 用于存储版本号

  UserAccount? get _activeAccount =>
      widget.dependencies.accountStore.activeRiverSideAccount;

  List<UserAccount> get _allAccounts =>
      widget.dependencies.accountStore.accountsOf(AccountProvider.riverSide);

  @override
  void initState() {
    super.initState();
    _loadAppVersion(); // 初始化时获取版本号
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (e) {
      // 忽略版本获取错误，保持为空即可
    }
  }

  Future<void> _openCredentialAddFlow({String? detectedWebViewVersion}) async {
    _setBusy(true);
    final profile = await Navigator.of(context).push<UserAccount>(
      riverPageRoute<UserAccount>(
        builder: (_) => RiverSideExternalFallbackPage(
          dependencies: widget.dependencies,
          detectedWebViewVersion: detectedWebViewVersion,
        ),
      ),
    );
    _setBusy(false);
    if (profile != null) _showMessage('已添加账号: ${profile.displayName}');
  }

  Future<void> _onAddAccountPressed() async {
    if (_isBusy) return;
    Navigator.pop(context); // 关闭 BottomSheet

    final support = await RiverSideWebViewSupport.check();
    if (!mounted) return;

    if (!support.canUseEmbeddedWebView) {
      await _openCredentialAddFlow(
        detectedWebViewVersion: support.detectedVersion,
      );
      return;
    }

    _setBusy(true);
    final profile = await Navigator.of(context).push<UserAccount>(
      riverPageRoute<UserAccount>(
        builder: (_) => RiverSideLoginWebViewPage(
          dependencies: widget.dependencies,
          flowMode: RiverSideLoginFlowMode.addAccount,
        ),
      ),
    );
    _setBusy(false);

    if (profile != null) _showMessage('已添加账号: ${profile.displayName}');
  }

  Future<void> _onSwitchAccount(UserAccount account) async {
    if (_isBusy ||
        widget.dependencies.accountStore.isActiveRiverSideAccount(
          account.username,
        )) {
      return;
    }
    Navigator.pop(context); // 关闭 BottomSheet

    _setBusy(true);
    final success = await widget.dependencies.accountStore
        .switchActiveRiverSideAccount(account.username);
    _setBusy(false);

    if (success) {
      HapticFeedback.mediumImpact();
    } else {
      _showMessage('切换失败，请重试');
    }
  }

  Future<void> _openProfilePage() async {
    final account = _activeAccount;
    if (account == null) return;

    final cookieHeader = widget.dependencies.accountStore
        .riverSideCookieHeaderFor(account.username);
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _showMessage('登录状态已失效，请重新登录');
      return;
    }

    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => RiverSideProfilePage(
          dependencies: widget.dependencies,
          account: account,
          cookieHeader: cookieHeader,
        ),
      ),
    );
  }

  Future<void> _onDeleteAccount(UserAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('确定要移除 "${account.displayName}" 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.dependencies.accountStore.removeRiverSideAccounts([
        account.username,
      ]);
      _showMessage('账号已移除');
    }
  }

  void _showAccountManagerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 透明背景以实现圆角
      builder: (context) => _AccountManagerSheet(
        accounts: _allAccounts,
        activeAccount: _activeAccount,
        onSwitch: _onSwitchAccount,
        onAdd: _onAddAccountPressed,
        onDelete: _onDeleteAccount,
      ),
    );
  }

  void _openAppearanceSettings() {
    Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => AppearanceSettingsPage(
          settingsController: widget.dependencies.settingsController,
        ),
      ),
    );
  }

  void _openAboutPage() {
    Navigator.of(
      context,
    ).push(riverPageRoute<void>(builder: (_) => const AboutPage()));
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _isBusy = value);
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // UI 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // 监听账号变化
    return AnimatedBuilder(
      animation: widget.dependencies.accountStore,
      builder: (context, _) {
        final account = _activeAccount;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 1. 顶部个人信息卡片
              SliverToBoxAdapter(child: _buildHeader(context, account)),

              // 2. 设置选项列表
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _SectionTitle(title: '通用设置'),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          title: '外观与主题',
                          subtitle: '深色模式、主题色',
                          onTap: _openAppearanceSettings,
                        ),
                        // 预留位置：通知设置、隐私设置等
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: '关于'),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: '关于 River',
                          // 使用本地状态 _appVersion
                          subtitle: _appVersion.isNotEmpty
                              ? '版本 $_appVersion'
                              : '版本信息加载中...',
                          onTap: _openAboutPage,
                        ),
                      ],
                    ),

                    // 底部留白
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserAccount? account) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.6),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          if (account != null) ...[
            // 已登录状态
            GestureDetector(
              onTap: _openProfilePage,
              child: Hero(
                tag: 'profile_avatar',
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: account.avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(account.avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: account.avatarUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 48,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              account.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${account.username}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _openProfilePage,
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('个人主页'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showAccountManagerSheet,
                  icon: const Icon(Icons.switch_account_rounded, size: 18),
                  label: const Text('切换账号'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // 未登录状态
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '欢迎来到 River',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录以查看您的个人信息',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _onAddAccountPressed,
              icon: const Icon(Icons.login_rounded),
              label: const Text('登录 / 注册'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 组件：设置卡片容器
// -----------------------------------------------------------------------------
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

// -----------------------------------------------------------------------------
// 组件：单个设置项
// -----------------------------------------------------------------------------
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.withOpacity(0.5),
        size: 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 组件：账号管理底部弹窗
// -----------------------------------------------------------------------------
class _AccountManagerSheet extends StatefulWidget {
  const _AccountManagerSheet({
    required this.accounts,
    required this.activeAccount,
    required this.onSwitch,
    required this.onAdd,
    required this.onDelete,
  });

  final List<UserAccount> accounts;
  final UserAccount? activeAccount;
  final ValueChanged<UserAccount> onSwitch;
  final VoidCallback onAdd;
  final ValueChanged<UserAccount> onDelete;

  @override
  State<_AccountManagerSheet> createState() => _AccountManagerSheetState();
}

class _AccountManagerSheetState extends State<_AccountManagerSheet> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '账号管理',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.accounts.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                      },
                      child: Text(_isEditing ? '完成' : '编辑'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('暂无登录账号', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final account = widget.accounts[index];
                    final isActive =
                        account.username == widget.activeAccount?.username;

                    return ListTile(
                      onTap: _isEditing ? null : () => widget.onSwitch(account),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        backgroundImage: account.avatarUrl.isNotEmpty
                            ? NetworkImage(account.avatarUrl)
                            : null,
                        child: account.avatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      title: Text(
                        account.displayName,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? theme.colorScheme.primary : null,
                        ),
                      ),
                      subtitle: Text('@${account.username}'),
                      trailing: _isEditing
                          ? IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => widget.onDelete(account),
                            )
                          : isActive
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isActive && !_isEditing
                            ? BorderSide(
                                color: theme.colorScheme.primary,
                                width: 1,
                              )
                            : BorderSide.none,
                      ),
                      tileColor: isActive
                          ? theme.colorScheme.primaryContainer.withOpacity(0.1)
                          : null,
                    );
                  },
                ),
              ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: const Text('添加 RiverSide 账号'),
                    onTap: widget.onAdd,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('添加 清水河畔 账号'),
                    subtitle: const Text(
                      '即将上线',
                      style: TextStyle(fontSize: 10),
                    ),
                    enabled: false, // 暂时禁用
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
