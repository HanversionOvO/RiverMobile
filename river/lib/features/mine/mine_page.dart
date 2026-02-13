import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/core/update/app_update_checker.dart';
import 'package:river/features/login/riverside_external_fallback_page.dart';
import 'package:river/features/login/riverside_login_flow_mode.dart';
import 'package:river/features/login/riverside_login_webview_page.dart';
import 'package:river/features/mine/about_page.dart';
import 'package:river/features/mine/appearance_settings_page.dart';
import 'package:river/features/mine/feedback_webview_page.dart';
import 'package:river/features/mine/notifications_push_settings_page.dart';
import 'package:river/features/mine/riverside_account_settings_page.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/features/mine/server_settings_page.dart';
import 'package:river/features/mine/storage_settings_page.dart'; // 引入新页面
import 'package:river/core/navigation/river_page_route.dart';

part 'mine_page_widgets.dart';

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
  bool _isCheckingVersion = false;
  bool _avatarAsCardBackground = false;
  final ScrollController _scrollController = ScrollController();
  double _headerScrollFactor = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  UserAccount? get _activeAccount =>
      widget.dependencies.accountStore.activeRiverSideAccount;

  List<UserAccount> get _allAccounts =>
      widget.dependencies.accountStore.accountsOf(AccountProvider.riverSide);

  Future<void> _openCredentialAddFlow({String? detectedWebViewVersion}) async {
    _setBusy(true);
    final profile = await showRiverSideCredentialLoginSheet(
      context: context,
      dependencies: widget.dependencies,
      detectedWebViewVersion: detectedWebViewVersion,
    );
    _setBusy(false);
    if (profile != null) _showMessage('已添加账号: ${profile.displayName}');
  }

  Future<void> _onAddAccountPressed() async {
    if (_isBusy) return;
    Navigator.pop(context);

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
    Navigator.pop(context);

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

  Future<bool> _onDeleteAccount(UserAccount account) async {
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

    if (confirmed != true) {
      return false;
    }

    await widget.dependencies.accountStore.removeRiverSideAccounts([
      account.username,
    ]);
    _showMessage('账号已移除');
    return true;
  }

  void _showAccountManagerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  // 新增：打开存储设置
  void _openStorageSettings() {
    Navigator.of(
      context,
    ).push(riverPageRoute<void>(builder: (_) => const StorageSettingsPage()));
  }

  void _openServerSettings() {
    Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => ServerSettingsPage(
          settingsController: widget.dependencies.settingsController,
          updateChecker: widget.dependencies.updateChecker,
        ),
      ),
    );
  }

  void _openNotificationsPushSettings() {
    Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => NotificationsPushSettingsPage(
          settingsController: widget.dependencies.settingsController,
        ),
      ),
    );
  }

  void _openRiverSideAccountSettings() {
    Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) =>
            RiverSideAccountSettingsPage(dependencies: widget.dependencies),
      ),
    );
  }

  void _openAboutPage() {
    Navigator.of(
      context,
    ).push(riverPageRoute<void>(builder: (_) => const AboutPage()));
  }

  void _openFeedbackPage() {
    Navigator.of(
      context,
    ).push(riverPageRoute<void>(builder: (_) => const FeedbackWebViewPage()));
  }

  Future<void> _openVersionDialog() async {
    if (_isCheckingVersion) {
      return;
    }
    setState(() {
      _isCheckingVersion = true;
    });
    try {
      final result = await widget.dependencies.updateChecker.checkForUpdates(
        force: true,
      );
      if (!mounted) {
        return;
      }
      await showRiverUpdateDialog(
        context: context,
        result: result,
        fromManualAction: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVersion = false;
        });
      }
    }
  }

  String _buildVersionSubtitle(AppUpdateChecker checker) {
    final currentVersion = checker.currentVersion.trim();
    if (checker.isChecking && currentVersion.isEmpty) {
      return '正在检查更新...';
    }
    if (currentVersion.isEmpty) {
      return '点击检查更新';
    }
    if (checker.hasUpdate && checker.latestVersion.isNotEmpty) {
      return '当前 $currentVersion · 可更新到 ${checker.latestVersion}';
    }
    return '当前版本 $currentVersion';
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _isBusy = value);
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleAvatarCardVisual() {
    HapticFeedback.selectionClick();
    setState(() {
      _avatarAsCardBackground = !_avatarAsCardBackground;
    });
  }

  void _onEditAvatarPressed() {
    _showMessage('修改头像功能开发中...');
  }

  void _onScroll() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0;
    final next = (offset / 96).clamp(0.0, 1.0);
    if ((_headerScrollFactor - next).abs() < 0.01 || !mounted) {
      return;
    }
    setState(() {
      _headerScrollFactor = next;
    });
  }

  Widget _buildProfileActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool emphasized,
    required bool overImage,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(999);
    final bgColor = emphasized
        ? (overImage
              ? Colors.white.withValues(alpha: 0.92)
              : theme.colorScheme.primary)
        : (overImage
              ? Colors.white.withValues(alpha: 0.16)
              : theme.colorScheme.surface.withValues(alpha: 0.88));
    final fgColor = emphasized
        ? (overImage ? theme.colorScheme.primary : theme.colorScheme.onPrimary)
        : (overImage
              ? Colors.white
              : theme.colorScheme.onSurface.withValues(alpha: 0.88));
    final borderColor = emphasized
        ? Colors.transparent
        : (overImage
              ? Colors.white.withValues(alpha: 0.40)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          height: compact ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 13),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
            border: Border.all(color: borderColor),
            boxShadow: (!compact && overImage)
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 15.5 : 16.5, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkResponse(
          customBorder: const CircleBorder(),
          highlightShape: BoxShape.circle,
          onTap: onTap,
          radius: 22,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final updateChecker = widget.dependencies.updateChecker;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.dependencies.accountStore,
        updateChecker,
      ]),
      builder: (context, _) {
        final account = _activeAccount;
        final hasUpdate = updateChecker.hasUpdate;
        final subtitle = _buildVersionSubtitle(updateChecker);
        final isChecking = _isCheckingVersion || updateChecker.isChecking;
        final theme = Theme.of(context);
        final easedHeaderFactor = Curves.easeOutCubic.transform(
          _headerScrollFactor,
        );

        return Scaffold(
          body: Column(
            children: [
              _buildTopHeader(theme, easedHeaderFactor, account),
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context, account)),
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
                                title: '外观',
                                subtitle: '应用基础外观自定义设置',
                                heroTagPrefix: 'mine_settings_appearance',
                                onTap: _openAppearanceSettings,
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.sd_storage_outlined,
                                title: '存储空间',
                                subtitle: '应用缓存空间管理与清理',
                                heroTagPrefix: 'mine_settings_storage',
                                onTap: _openStorageSettings,
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.notifications_active_outlined,
                                title: '通知与推送',
                                subtitle: '实时横幅提醒开关',
                                heroTagPrefix:
                                    'mine_settings_notifications_push',
                                onTap: _openNotificationsPushSettings,
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.dns_outlined,
                                title: '服务器设置',
                                subtitle: '主域名与更新源',
                                heroTagPrefix: 'mine_settings_server',
                                onTap: _openServerSettings,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(title: '账号设置'),
                          _SettingsCard(
                            children: [
                              _SettingsTile(
                                icon: Icons.manage_accounts_outlined,
                                title: 'RiverSide账号设置',
                                subtitle: '账号基础信息设置',
                                heroTagPrefix:
                                    'mine_settings_riverside_account',
                                onTap: _openRiverSideAccountSettings,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(title: '其他'),
                          _SettingsCard(
                            children: [
                              _SettingsTile(
                                icon: Icons.system_update_alt_rounded,
                                title: '版本',
                                subtitle: subtitle,
                                onTap: _openVersionDialog,
                                trailing: isChecking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (hasUpdate)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.errorContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '可更新',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onErrorContainer,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          if (hasUpdate)
                                            const SizedBox(width: 6),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.grey.withValues(
                                              alpha: 0.5,
                                            ),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.feedback_outlined,
                                title: '反馈',
                                subtitle: '问题反馈与建议',
                                heroTagPrefix: 'mine_settings_feedback',
                                onTap: _openFeedbackPage,
                              ),
                              const _SettingsDivider(),
                              _SettingsTile(
                                icon: Icons.info_outline_rounded,
                                title: '关于 River',
                                subtitle: '应用信息与项目说明',
                                heroTagPrefix: 'mine_settings_about',
                                onTap: _openAboutPage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(ThemeData theme, double t, UserAccount? account) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapse = t.clamp(0.0, 1.0);
    const titleSize = 21.0;
    final subtitleVisibility = (1.0 - collapse).clamp(0.0, 1.0);
    final borderAlpha = lerpDouble(0.18, 0.26, collapse)!;
    final subtitle = account == null ? '未登录' : '@${account.username}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(
              alpha: lerpDouble(0.90, 0.96, t)!,
            ),
            theme.colorScheme.surfaceContainerLowest.withValues(
              alpha: lerpDouble(0.82, 0.92, t)!,
            ),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: borderAlpha,
            ),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: lerpDouble(7, 11, t)!,
            sigmaY: lerpDouble(7, 11, t)!,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topInset + lerpDouble(9, 8, collapse)!,
              bottom: 6,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 64),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '我的',
                              textAlign: TextAlign.left,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                fontSize: titleSize,
                              ),
                            ),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                heightFactor: subtitleVisibility,
                                child: Opacity(
                                  opacity: subtitleVisibility,
                                  child: Text(
                                    subtitle,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        onPressed: _showAccountManagerSheet,
                        tooltip: '账号管理',
                        icon: const Icon(Icons.manage_accounts_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserAccount? account) {
    final theme = Theme.of(context);
    const topPadding = 2.0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 18, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.46),
            theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          if (account != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              height: _avatarAsCardBackground ? 292 : 244,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: _avatarAsCardBackground ? 0.14 : 0.58,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.26,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  const collapsedAvatarSize = 88.0;
                  final collapsedLeft = (width - collapsedAvatarSize) / 2;
                  final expandedHeight = constraints.maxHeight;
                  final expandedInfoTop = constraints.maxHeight - 124;
                  final expandedActionsTop = constraints.maxHeight - 70;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        top: _avatarAsCardBackground ? 0 : 16,
                        left: _avatarAsCardBackground ? 0 : collapsedLeft,
                        width: _avatarAsCardBackground
                            ? width
                            : collapsedAvatarSize,
                        height: _avatarAsCardBackground
                            ? expandedHeight
                            : collapsedAvatarSize,
                        child: GestureDetector(
                          onTap: _toggleAvatarCardVisual,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                _avatarAsCardBackground ? 28 : 44,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: _avatarAsCardBackground ? 0 : 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              image: account.avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(account.avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: account.avatarUrl.isEmpty
                                  ? theme.colorScheme.surfaceContainerHighest
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: account.avatarUrl.isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: _avatarAsCardBackground ? 44 : 48,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            opacity: _avatarAsCardBackground ? 1 : 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.black.withValues(alpha: 0.22),
                                    Colors.black.withValues(alpha: 0.40),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        top: _avatarAsCardBackground ? expandedInfoTop : 118,
                        left: 16,
                        right: 16,
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          alignment: _avatarAsCardBackground
                              ? Alignment.centerLeft
                              : Alignment.center,
                          child: Column(
                            crossAxisAlignment: _avatarAsCardBackground
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                account.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _avatarAsCardBackground
                                      ? Colors.white
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${account.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _avatarAsCardBackground
                                      ? Colors.white.withValues(alpha: 0.92)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        left: 14,
                        right: 14,
                        top: _avatarAsCardBackground ? expandedActionsTop : 190,
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _avatarAsCardBackground
                                ? Container(
                                    key: const ValueKey('icon_actions'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.30,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildProfileIconActionButton(
                                          icon: Icons.person_rounded,
                                          tooltip: '个人主页',
                                          onTap: _openProfilePage,
                                        ),
                                        const SizedBox(width: 10),
                                        _buildProfileIconActionButton(
                                          icon: Icons.switch_account_rounded,
                                          tooltip: '切换账号',
                                          onTap: _showAccountManagerSheet,
                                        ),
                                        const SizedBox(width: 10),
                                        _buildProfileIconActionButton(
                                          icon: Icons.camera_alt_rounded,
                                          tooltip: '修改头像',
                                          onTap: _onEditAvatarPressed,
                                        ),
                                      ],
                                    ),
                                  )
                                : Wrap(
                                    key: const ValueKey('text_actions'),
                                    spacing: 10,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      _buildProfileActionChip(
                                        icon: Icons.person_rounded,
                                        label: '个人主页',
                                        onTap: _openProfilePage,
                                        emphasized: true,
                                        overImage: false,
                                      ),
                                      _buildProfileActionChip(
                                        icon: Icons.switch_account_rounded,
                                        label: '切换账号',
                                        onTap: _showAccountManagerSheet,
                                        emphasized: false,
                                        overImage: false,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            // 未登录状态
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
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
// 组件
// -----------------------------------------------------------------------------
