import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/login/riverside_login_flow_mode.dart';
import 'package:river/features/login/riverside_login_webview_page.dart';
import 'package:river/features/mine/about_page.dart';
import 'package:river/features/mine/appearance_settings_page.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  bool _addingRiverSideAccount = false;
  bool _switchingAccount = false;
  bool _deletingMode = false;
  bool _deletingAccounts = false;
  final Set<String> _selectedDeleteUsernames = <String>{};

  Future<void> _onAddRiverSideAccountPressed() async {
    if (_addingRiverSideAccount || _deletingMode) {
      return;
    }

    final support = await RiverSideWebViewSupport.check();
    if (!mounted) {
      return;
    }

    if (!support.canUseEmbeddedWebView) {
      final version = support.detectedVersion;
      final suffix = version == null || version.isEmpty
          ? '.'
          : ' (WebView: $version).';
      _showMessage(
        'Current device WebView is too old to add account in-app$suffix',
      );
      return;
    }

    setState(() {
      _addingRiverSideAccount = true;
    });

    final profile = await Navigator.of(context).push<UserAccount>(
      MaterialPageRoute<UserAccount>(
        builder: (_) => RiverSideLoginWebViewPage(
          dependencies: widget.dependencies,
          flowMode: RiverSideLoginFlowMode.addAccount,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _addingRiverSideAccount = false;
    });

    if (profile != null) {
      _showMessage('Added RiverSide account: ${profile.displayName}');
    }
  }

  Future<void> _onSwitchRiverSideAccount(UserAccount account) async {
    if (_switchingAccount ||
        _deletingMode ||
        widget.dependencies.accountStore.isActiveRiverSideAccount(
          account.username,
        )) {
      return;
    }

    setState(() {
      _switchingAccount = true;
    });

    final success = await widget.dependencies.accountStore
        .switchActiveRiverSideAccount(account.username);

    if (!mounted) {
      return;
    }

    setState(() {
      _switchingAccount = false;
    });

    if (!success) {
      _showMessage('Switch failed, please retry.');
      return;
    }

    _showMessage('Current RiverSide account: ${account.displayName}');
  }

  Future<void> _openRiverSideProfile(UserAccount account) async {
    if (_deletingMode || _switchingAccount) {
      return;
    }

    setState(() {
      _switchingAccount = true;
    });

    final switched = await widget.dependencies.accountStore
        .switchActiveRiverSideAccount(account.username);
    if (!mounted) {
      return;
    }
    setState(() {
      _switchingAccount = false;
    });

    if (!switched) {
      _showMessage('Unable to switch current account.');
      return;
    }

    final support = await RiverSideWebViewSupport.check();
    if (!mounted) {
      return;
    }

    final cookieHeader = widget.dependencies.accountStore
        .riverSideCookieHeaderFor(account.username);
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _showMessage('Current account session is missing. Please re-login it.');
      return;
    }

    if (support.canUseEmbeddedWebView) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RiverSideProfilePage(
            account: account,
            cookieHeader: cookieHeader,
          ),
        ),
      );
      return;
    }

    final profileUrl = Uri.parse(
      '$riverSideBaseUrl/u/${Uri.encodeComponent(account.username)}',
    );
    final launched = await launchUrl(
      profileUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showMessage('Unable to open profile page.');
    }
  }

  void _onToggleDeleteMode(List<UserAccount> accounts) {
    if (_deletingAccounts) {
      return;
    }
    if (accounts.isEmpty) {
      _showMessage('No RiverSide account can be removed.');
      return;
    }

    setState(() {
      _deletingMode = !_deletingMode;
      if (!_deletingMode) {
        _selectedDeleteUsernames.clear();
      }
    });
  }

  void _onCancelDeleteMode() {
    if (_deletingAccounts) {
      return;
    }

    setState(() {
      _deletingMode = false;
      _selectedDeleteUsernames.clear();
    });
  }

  void _onLongPressRiverSideAccount(
    UserAccount account,
    List<UserAccount> accounts,
  ) {
    if (_deletingAccounts || accounts.isEmpty) {
      return;
    }

    setState(() {
      _deletingMode = true;
      _selectedDeleteUsernames
        ..clear()
        ..add(_normalizeUsername(account.username));
    });
  }

  void _onToggleDeleteSelection(UserAccount account) {
    final key = _normalizeUsername(account.username);
    if (key.isEmpty) {
      return;
    }

    setState(() {
      if (_selectedDeleteUsernames.contains(key)) {
        _selectedDeleteUsernames.remove(key);
      } else {
        _selectedDeleteUsernames.add(key);
      }
    });
  }

  Future<void> _onDeleteSelectedPressed(List<UserAccount> accounts) async {
    if (_deletingAccounts) {
      return;
    }

    final selected = accounts
        .where(
          (account) => _selectedDeleteUsernames.contains(
            _normalizeUsername(account.username),
          ),
        )
        .toList();
    if (selected.isEmpty) {
      _showMessage('Please select accounts first.');
      return;
    }

    final names = selected
        .map(
          (account) => account.displayName.isEmpty
              ? account.username
              : account.displayName,
        )
        .join('、');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete accounts'),
          content: Text('是否删除$names？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingAccounts = true;
    });

    await widget.dependencies.accountStore.removeRiverSideAccounts(
      selected.map((account) => account.username),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _deletingAccounts = false;
      _deletingMode = false;
      _selectedDeleteUsernames.clear();
    });

    _showMessage('Deleted ${selected.length} account(s).');
  }

  void _showQingPlaceholder() {
    _showMessage('QingShuiHePan account module is not implemented yet.');
  }

  void _openAppearanceSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppearanceSettingsPage(
          settingsController: widget.dependencies.settingsController,
        ),
      ),
    );
  }

  void _openAboutPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
  }

  String _normalizeUsername(String username) {
    return username.trim().toLowerCase();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.dependencies.accountStore,
      builder: (context, _) {
        final riverSideAccounts = widget.dependencies.accountStore.accountsOf(
          AccountProvider.riverSide,
        );
        final qingAccounts = widget.dependencies.accountStore.accountsOf(
          AccountProvider.qingShuiHePan,
        );
        final activeRiverSide =
            widget.dependencies.accountStore.activeRiverSideUsername;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _ModuleHeader(title: '\u8d26\u53f7\u6a21\u5757'),
            _RiverSideAccountSectionCard(
              accounts: riverSideAccounts,
              activeUsername: activeRiverSide,
              deletingMode: _deletingMode,
              selectedDeleteUsernames: _selectedDeleteUsernames,
              onAddPressed: _addingRiverSideAccount
                  ? null
                  : _onAddRiverSideAccountPressed,
              onToggleDeleteMode: () => _onToggleDeleteMode(riverSideAccounts),
              onCancelDeleteMode: _onCancelDeleteMode,
              onDeleteSelectedPressed: () =>
                  _onDeleteSelectedPressed(riverSideAccounts),
              onDeleteSelectChanged: _onToggleDeleteSelection,
              onLongPressAccount: (account) =>
                  _onLongPressRiverSideAccount(account, riverSideAccounts),
              onOpenProfile: _openRiverSideProfile,
              onSwitchActive: _onSwitchRiverSideAccount,
              isBusy:
                  _addingRiverSideAccount ||
                  _switchingAccount ||
                  _deletingAccounts,
            ),
            const SizedBox(height: 12),
            _SimpleAccountSectionCard(
              title: '\u6e05\u6c34\u6cb3\u7554 \u8d26\u53f7',
              accounts: qingAccounts,
              emptySubtitle:
                  '\u6682\u672a\u63a5\u5165\uff0c\u656c\u8bf7\u671f\u5f85',
              onAddPressed: _showQingPlaceholder,
            ),
            const SizedBox(height: 20),
            const _ModuleHeader(title: '\u5e94\u7528\u4e0e\u5916\u89c2'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('\u5916\u89c2\u8bbe\u7f6e'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAppearanceSettings,
              ),
            ),
            const SizedBox(height: 20),
            const _ModuleHeader(title: '\u5176\u4ed6'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('\u5173\u4e8e'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAboutPage,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _RiverSideAccountSectionCard extends StatelessWidget {
  const _RiverSideAccountSectionCard({
    required this.accounts,
    required this.activeUsername,
    required this.deletingMode,
    required this.selectedDeleteUsernames,
    required this.onAddPressed,
    required this.onToggleDeleteMode,
    required this.onCancelDeleteMode,
    required this.onDeleteSelectedPressed,
    required this.onDeleteSelectChanged,
    required this.onLongPressAccount,
    required this.onOpenProfile,
    required this.onSwitchActive,
    this.isBusy = false,
  });

  final List<UserAccount> accounts;
  final String? activeUsername;
  final bool deletingMode;
  final Set<String> selectedDeleteUsernames;
  final VoidCallback? onAddPressed;
  final VoidCallback onToggleDeleteMode;
  final VoidCallback onCancelDeleteMode;
  final VoidCallback onDeleteSelectedPressed;
  final ValueChanged<UserAccount> onDeleteSelectChanged;
  final ValueChanged<UserAccount> onLongPressAccount;
  final ValueChanged<UserAccount> onOpenProfile;
  final ValueChanged<UserAccount> onSwitchActive;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      ListTile(
        title: const Text('RiverSide \u8d26\u53f7'),
        subtitle: Text(
          activeUsername == null || activeUsername!.isEmpty
              ? '\u6682\u65e0\u5f53\u524d\u8d26\u53f7'
              : '\u5f53\u524d\u8d26\u53f7\uff1a$activeUsername',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deletingMode) ...[
              TextButton(
                onPressed: isBusy ? null : onCancelDeleteMode,
                child: const Text('\u53d6\u6d88\u5220\u9664'),
              ),
              IconButton(
                onPressed: isBusy ? null : onDeleteSelectedPressed,
                icon: const Icon(Icons.delete_outline),
                tooltip: '\u5220\u9664\u6240\u9009',
              ),
            ] else ...[
              IconButton(
                onPressed: isBusy ? null : onToggleDeleteMode,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '\u7f16\u8f91\u5220\u9664',
              ),
              IconButton(
                onPressed: onAddPressed,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                tooltip: '\u6dfb\u52a0\u8d26\u53f7',
              ),
            ],
          ],
        ),
      ),
    ];

    if (accounts.isEmpty) {
      tiles.add(
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
          title: const Text('\u6dfb\u52a0\u8d26\u53f7'),
          subtitle: const Text(
            '\u8bf7\u70b9\u51fb\u53f3\u4e0a\u89d2 + \u5e76\u5b8c\u6210 RiverSide \u767b\u5f55',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: deletingMode ? null : onAddPressed,
        ),
      );
    } else {
      for (var index = 0; index < accounts.length; index++) {
        final account = accounts[index];
        final isActive =
            account.username.toLowerCase() == activeUsername?.toLowerCase();
        final subtitle = account.title.isEmpty
            ? account.username
            : '${account.username} · ${account.title}';
        final activeSuffix = isActive ? '  (\u5f53\u524d)' : '';
        final selected = selectedDeleteUsernames.contains(
          account.username.toLowerCase(),
        );

        if (index > 0) {
          tiles.add(const Divider(height: 1));
        }

        if (deletingMode) {
          tiles.add(
            ListTile(
              leading: Checkbox(
                value: selected,
                onChanged: (_) => onDeleteSelectChanged(account),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: account.avatarUrl.isEmpty
                        ? null
                        : NetworkImage(account.avatarUrl),
                    child: account.avatarUrl.isEmpty
                        ? const Icon(Icons.person_outline, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(account.displayName)),
                ],
              ),
              subtitle: Text('$subtitle$activeSuffix'),
              onTap: () => onDeleteSelectChanged(account),
            ),
          );
        } else {
          tiles.add(
            ListTile(
              leading: CircleAvatar(
                backgroundImage: account.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(account.avatarUrl),
                child: account.avatarUrl.isEmpty
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(account.displayName),
              subtitle: Text('$subtitle$activeSuffix'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(value: account.username),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => onOpenProfile(account),
              onLongPress: () => onLongPressAccount(account),
            ),
          );
        }
      }
    }

    UserAccount? findAccountByUsername(String? username) {
      if (username == null || username.isEmpty) {
        return null;
      }
      for (final account in accounts) {
        if (account.username.toLowerCase() == username.toLowerCase()) {
          return account;
        }
      }
      return null;
    }

    if (deletingMode) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: tiles),
      );
    }

    return RadioGroup<String>(
      groupValue: activeUsername,
      onChanged: (value) {
        final account = findAccountByUsername(value);
        if (account != null) {
          onSwitchActive(account);
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: tiles),
      ),
    );
  }
}

class _SimpleAccountSectionCard extends StatelessWidget {
  const _SimpleAccountSectionCard({
    required this.title,
    required this.accounts,
    required this.emptySubtitle,
    required this.onAddPressed,
  });

  final String title;
  final List<UserAccount> accounts;
  final String emptySubtitle;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      ListTile(
        title: Text(title),
        trailing: IconButton(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          tooltip: '\u6dfb\u52a0\u8d26\u53f7',
        ),
      ),
    ];

    if (accounts.isEmpty) {
      tiles.add(
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
          title: const Text('\u6dfb\u52a0\u8d26\u53f7'),
          subtitle: Text(emptySubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onAddPressed,
        ),
      );
    } else {
      for (var index = 0; index < accounts.length; index++) {
        final account = accounts[index];
        if (index > 0) {
          tiles.add(const Divider(height: 1));
        }

        final subtitle = account.title.isEmpty
            ? account.username
            : '${account.username} · ${account.title}';

        tiles.add(
          ListTile(
            leading: CircleAvatar(
              backgroundImage: account.avatarUrl.isEmpty
                  ? null
                  : NetworkImage(account.avatarUrl),
              child: account.avatarUrl.isEmpty
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            title: Text(account.displayName),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAddPressed,
          ),
        );
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }
}
