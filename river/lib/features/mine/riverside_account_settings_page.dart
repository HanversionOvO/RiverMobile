import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_account_settings_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_search_models.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

part 'riverside_account_settings_page_widgets.dart';

class RiverSideAccountSettingsPage extends StatefulWidget {
  const RiverSideAccountSettingsPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<RiverSideAccountSettingsPage> createState() =>
      _RiverSideAccountSettingsPageState();
}

class _RiverSideAccountSettingsPageState
    extends State<RiverSideAccountSettingsPage> {
  RiverSideAccountSettingsSnapshot? _snapshot;
  List<RiverSideTitleBadgeOption> _titleOptions =
      const <RiverSideTitleBadgeOption>[];

  bool _loading = true;
  bool _saving = false;
  bool _loadingTitleOptions = false;
  bool _showAllDevices = false;
  String? _errorText;

  RiverSideApiClient get _apiClient =>
      widget.dependencies.accountStore.riverSideApiClient;

  UserAccount? get _activeAccount =>
      widget.dependencies.accountStore.activeRiverSideAccount;

  String? _activeCookieHeader() {
    final account = _activeAccount;
    if (account == null) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(
      account.username,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    await _refreshSnapshot(showLoading: false);
    await _loadTitleOptions();
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _refreshSnapshot({required bool showLoading}) async {
    final account = _activeAccount;
    final cookie = _activeCookieHeader()?.trim() ?? '';

    if (account == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = null;
        _errorText = '暂无可用账号，请先登录 RiverSide 账号。';
        if (showLoading) {
          _loading = false;
        }
      });
      return;
    }

    if (cookie.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = null;
        _errorText = '当前账号登录状态已失效，请重新登录。';
        if (showLoading) {
          _loading = false;
        }
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final next = await _apiClient.fetchAccountSettingsSnapshot(
        username: account.username,
        cookieHeader: cookie,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = next;
        _errorText = null;
        if (showLoading) {
          _loading = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
        if (showLoading) {
          _loading = false;
        }
      });
    }
  }

  Future<void> _loadTitleOptions() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }

    setState(() => _loadingTitleOptions = true);
    try {
      final items = await _apiClient.fetchTitleBadgeOptions(
        username: snapshot.username,
        cookieHeader: cookie,
      );
      if (!mounted) {
        return;
      }
      setState(() => _titleOptions = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _titleOptions = const <RiverSideTitleBadgeOption>[]);
    } finally {
      if (mounted) {
        setState(() => _loadingTitleOptions = false);
      }
    }
  }

  Future<void> _runSaving(
    Future<void> Function() task, {
    String? successMessage,
  }) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await task();
      if (successMessage != null && mounted) {
        _showMessage(successMessage);
      }
    } on RiverSideApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _safeCloseDialog(BuildContext dialogContext, [Object? result]) {
    // Delay pop to next frame to avoid teardown race with focused TextField.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!dialogContext.mounted) {
        return;
      }
      final navigator = Navigator.of(dialogContext, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop(result);
      }
    });
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String labelText,
    String? hintText,
    String? initialValue,
    int minLines = 1,
    int maxLines = 1,
    String confirmText = '确认',
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: minLines,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _safeCloseDialog(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () =>
                    _safeCloseDialog(dialogContext, controller.text.trim()),
                child: Text(confirmText),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _changePrimaryEmail() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    final input = await _showTextInputDialog(
      title: '更改电子邮件',
      labelText: '新邮箱',
      hintText: 'name@example.com',
      initialValue: snapshot.emailState.primaryEmail,
      confirmText: '保存',
    );
    if (input == null || input.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.updateUserEmail(
        username: snapshot.username,
        email: input,
        cookieHeader: cookie,
      );
      final emailState = await _apiClient.fetchUserEmails(
        username: snapshot.username,
        cookieHeader: cookie,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() {
        _snapshot = _snapshot!.copyWith(emailState: emailState);
      });
    }, successMessage: '电子邮件更新成功');
  }

  Future<void> _addSecondaryEmail() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    final input = await _showTextInputDialog(
      title: '设置备用电子邮件',
      labelText: '备用邮箱',
      hintText: 'name@example.com',
      confirmText: '添加',
    );
    if (input == null || input.isEmpty) {
      return;
    }

    await _runSaving(() async {
      await _apiClient.addSecondaryEmail(
        username: snapshot.username,
        email: input,
        cookieHeader: cookie,
      );
      final emailState = await _apiClient.fetchUserEmails(
        username: snapshot.username,
        cookieHeader: cookie,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() {
        _snapshot = _snapshot!.copyWith(emailState: emailState);
      });
    }, successMessage: '已提交备用邮箱，请前往邮箱完成验证');
  }

  Future<void> _editDisplayName() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    final input = await _showTextInputDialog(
      title: '别名设置',
      labelText: '显示名称',
      hintText: '输入新的显示名称',
      initialValue: snapshot.displayName,
      confirmText: '保存',
    );
    if (input == null || input.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.updateUserProfileSettings(
        username: snapshot.username,
        cookieHeader: cookie,
        displayName: input,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() {
        _snapshot = _snapshot!.copyWith(displayName: input);
      });
    }, successMessage: '别名已更新');
  }

  Future<void> _editBio() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    final input = await _showTextInputDialog(
      title: '自我介绍设置',
      labelText: '个人简介',
      hintText: '介绍一下你自己',
      initialValue: snapshot.bioRaw,
      minLines: 5,
      maxLines: 10,
      confirmText: '保存',
    );
    if (input == null) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.updateUserProfileSettings(
        username: snapshot.username,
        cookieHeader: cookie,
        bioRaw: input,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() {
        _snapshot = _snapshot!.copyWith(bioRaw: input);
      });
    }, successMessage: '自我介绍已更新');
  }

  Future<void> _pickTitleBadge() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    if (_titleOptions.isEmpty) {
      _showMessage('暂无可用头衔，请先获取可用徽章');
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        return _TitleBadgePickerSheet(
          currentTitle: snapshot.title.trim(),
          options: _titleOptions,
        );
      },
    );
    if (selectedId == null) {
      return;
    }

    await _runSaving(() async {
      await _apiClient.updateBadgeTitle(
        username: snapshot.username,
        cookieHeader: cookie,
        userBadgeId: selectedId,
      );
      await _refreshSnapshot(showLoading: false);
      await _loadTitleOptions();
    }, successMessage: '头衔已更新');
  }

  Future<void> _toggleHideProfile(bool next) async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.updateUserProfileSettings(
        username: snapshot.username,
        cookieHeader: cookie,
        hideProfile: next,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() => _snapshot = _snapshot!.copyWith(hideProfile: next));
    });
  }

  Future<void> _toggleHidePresence(bool next) async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.updateUserProfileSettings(
        username: snapshot.username,
        cookieHeader: cookie,
        hidePresence: next,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      setState(() => _snapshot = _snapshot!.copyWith(hidePresence: next));
    });
  }

  Future<void> _requestPasswordReset() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.requestPasswordReset(
        login: snapshot.username,
        cookieHeader: cookie,
      );
    }, successMessage: '重置密码邮件已发送，请前往邮箱查看');
  }

  Future<void> _revokeDeviceToken(int? tokenId) async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }

    final title = tokenId == null ? '全部设备下线' : '移除设备';
    final content = tokenId == null ? '确定让当前账号在其他设备全部下线吗？' : '确定移除该设备登录状态吗？';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _runSaving(() async {
      await _apiClient.revokeAuthToken(
        username: snapshot.username,
        cookieHeader: cookie,
        tokenId: tokenId,
      );
      await _refreshSnapshot(showLoading: false);
    }, successMessage: tokenId == null ? '已下线全部设备' : '已移除设备');
  }

  Future<void> _addIgnoredUser() async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<RiverSideUserSearchItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        return _IgnoreUserPickerSheet(
          apiClient: _apiClient,
          cookieHeader: cookie,
          selfUsername: snapshot.username,
          ignoredUsernames: snapshot.ignoredUsernames.toSet(),
        );
      },
    );
    if (selected == null) {
      return;
    }

    await _runSaving(() async {
      await _apiClient.setIgnoredUserState(
        targetUsername: selected.username,
        ignore: true,
        cookieHeader: cookie,
        actingUserId: snapshot.userId,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      final set = _snapshot!.ignoredUsernames.toSet();
      set.add(selected.username);
      final next = set.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => _snapshot = _snapshot!.copyWith(ignoredUsernames: next));
    }, successMessage: '已忽略 @${selected.username}');
  }

  Future<void> _removeIgnoredUser(String username) async {
    final snapshot = _snapshot;
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (snapshot == null || cookie.isEmpty) {
      return;
    }
    await _runSaving(() async {
      await _apiClient.setIgnoredUserState(
        targetUsername: username,
        ignore: false,
        cookieHeader: cookie,
        actingUserId: snapshot.userId,
      );
      if (!mounted || _snapshot == null) {
        return;
      }
      final next = _snapshot!.ignoredUsernames
          .where((name) => name.toLowerCase() != username.toLowerCase())
          .toList();
      setState(() => _snapshot = _snapshot!.copyWith(ignoredUsernames: next));
    }, successMessage: '已取消忽略 @$username');
  }

  String _deviceTitle(RiverSideUserAuthToken token) {
    final device = token.device.trim();
    final browser = token.browser.trim();
    if (device.isEmpty && browser.isEmpty) {
      return '未知设备';
    }
    if (device.isEmpty) {
      return browser;
    }
    if (browser.isEmpty) {
      return device;
    }
    return '$device · $browser';
  }

  String _deviceSubtitle(RiverSideUserAuthToken token) {
    final location = token.location.trim().isEmpty ? '未知地区' : token.location;
    final ip = token.clientIp.trim().isEmpty ? '未知 IP' : token.clientIp.trim();
    final seen = token.seenAt ?? token.createdAt;
    final time = seen == null ? '未知时间' : _formatDateTime(seen);
    return '$location · $ip · $time';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: MineSettingsAppBar(
        title: 'RiverSide 账号设置',
        subtitle: _activeAccount == null
            ? '未登录'
            : '@${_activeAccount!.username}',
        icon: Icons.manage_accounts_rounded,
        heroTagPrefix: 'mine_settings_riverside_account',
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _saving ? null : () => _loadInitial(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
          ? _ErrorStateCard(text: _errorText!, onRetry: _loadInitial)
          : _snapshot == null
          ? _ErrorStateCard(text: '未读取到账号信息。', onRetry: _loadInitial)
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _SettingsSectionCard(
                    title: '账户基础',
                    subtitle: '电子邮件、别名与头衔',
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.person_outline_rounded,
                          title: '别名设置',
                          subtitle: _snapshot!.displayName.trim().isEmpty
                              ? '点击设置显示名称'
                              : _snapshot!.displayName,
                          onTap: _snapshot!.canEditName && !_saving
                              ? _editDisplayName
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _ActionTile(
                          icon: Icons.alternate_email_rounded,
                          title: '头衔设置',
                          subtitle: _loadingTitleOptions
                              ? '正在加载可选头衔...'
                              : (_snapshot!.title.trim().isEmpty
                                    ? '未设置，点击选择头衔'
                                    : _snapshot!.title),
                          onTap: _saving || _loadingTitleOptions
                              ? null
                              : _pickTitleBadge,
                        ),
                        const SizedBox(height: 8),
                        _ActionTile(
                          icon: Icons.mail_outline_rounded,
                          title: '更改电子邮件',
                          subtitle: _snapshot!.emailState.primaryEmail.isEmpty
                              ? '未读取到主邮箱，点击设置'
                              : _snapshot!.emailState.primaryEmail,
                          onTap: _snapshot!.canEditEmail && !_saving
                              ? _changePrimaryEmail
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _ActionTile(
                          icon: Icons.forward_to_inbox_outlined,
                          title: '设置备用电子邮件',
                          subtitle: '添加用于接收通知和找回账号的备用邮箱',
                          onTap: _snapshot!.canEditEmail && !_saving
                              ? _addSecondaryEmail
                              : null,
                        ),
                        if (_snapshot!.emailState.secondaryEmails.isNotEmpty ||
                            _snapshot!.emailState.unconfirmedEmails.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final email
                                      in _snapshot!.emailState.secondaryEmails)
                                    _InfoChip(
                                      icon: Icons.mark_email_read_rounded,
                                      text: email,
                                      color: theme.colorScheme.primary,
                                    ),
                                  for (final email
                                      in _snapshot!
                                          .emailState
                                          .unconfirmedEmails)
                                    _InfoChip(
                                      icon: Icons.mark_email_unread_rounded,
                                      text: '$email（待验证）',
                                      color: theme.colorScheme.tertiary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: '隐私与在线',
                    subtitle: '个人资料显示与在线状态',
                    child: Column(
                      children: [
                        _SwitchExplainTile(
                          icon: Icons.visibility_off_outlined,
                          title: '个人资料显示/隐藏',
                          subtitle: _snapshot!.hideProfile
                              ? '当前为“隐藏”：其他用户将无法查看你的完整个人资料'
                              : '当前为“显示”：其他用户可以查看你的个人资料',
                          value: _snapshot!.hideProfile,
                          onChanged: _saving ? null : _toggleHideProfile,
                        ),
                        const SizedBox(height: 8),
                        _SwitchExplainTile(
                          icon: Icons.circle_notifications_outlined,
                          title: '在线/隐身设置',
                          subtitle: _snapshot!.hidePresence
                              ? '当前为“隐身”：不会显示在线状态与最近在线信息'
                              : '当前为“在线可见”：会显示在线状态与最近在线信息',
                          value: _snapshot!.hidePresence,
                          onChanged: _saving ? null : _toggleHidePresence,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: '资料内容',
                    subtitle: '编辑自我介绍',
                    child: _ActionTile(
                      icon: Icons.notes_rounded,
                      title: '自我介绍设置',
                      subtitle: _snapshot!.bioRaw.trim().isEmpty
                          ? '暂无简介，点击补充'
                          : _snapshot!.bioRaw,
                      maxSubtitleLines: 3,
                      onTap: _snapshot!.canChangeBio && !_saving
                          ? _editBio
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: '安全与设备',
                    subtitle: '密码与最近登录设备',
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _requestPasswordReset,
                          icon: const Icon(Icons.password_rounded, size: 16),
                          label: const Text('密码设置'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving || _snapshot!.authTokens.isEmpty
                              ? null
                              : () => _revokeDeviceToken(null),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('全部下线'),
                        ),
                      ],
                    ),
                    child: _buildDevicePanel(theme),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: '关系管理',
                    subtitle: '忽略用户管理',
                    trailing: FilledButton.tonalIcon(
                      onPressed:
                          !_saving && _snapshot!.canIgnoreUsers && !_loading
                          ? _addIgnoredUser
                          : null,
                      icon: const Icon(Icons.person_add_disabled_rounded),
                      label: const Text('添加忽略'),
                    ),
                    child: _buildIgnoredUsersPanel(theme),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDevicePanel(ThemeData theme) {
    final tokens = _snapshot!.authTokens;
    if (tokens.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          '暂无设备记录',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final showExpand = tokens.length > 3;
    final visible = _showAllDevices ? tokens : tokens.take(3).toList();

    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _DeviceTile(
            title: _deviceTitle(visible[i]),
            subtitle: _deviceSubtitle(visible[i]),
            active: visible[i].isActive,
            onRemove: _saving ? null : () => _revokeDeviceToken(visible[i].id),
          ),
          if (i != visible.length - 1) const SizedBox(height: 8),
        ],
        if (showExpand) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() => _showAllDevices = !_showAllDevices),
              icon: Icon(
                _showAllDevices
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showAllDevices ? '收起设备列表' : '展开全部设备（${tokens.length}）',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIgnoredUsersPanel(ThemeData theme) {
    final names = _snapshot!.ignoredUsernames;
    if (names.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.centerLeft,
        child: Text(
          '暂无忽略用户',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < names.length; i++) ...[
          _IgnoredUserTile(
            username: names[i],
            onUnignore: _saving ? null : () => _removeIgnoredUser(names[i]),
          ),
          if (i != names.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
