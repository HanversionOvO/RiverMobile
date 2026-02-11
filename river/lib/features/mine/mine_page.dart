import 'package:flutter/material.dart';
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

part 'mine_page_widgets.dart';

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

  Future<void> _openCredentialAddFlow({String? detectedWebViewVersion}) async {
    setState(() {
      _addingRiverSideAccount = true;
    });

    final profile = await Navigator.of(context).push<UserAccount>(
      riverPageRoute<UserAccount>(
        builder: (_) => RiverSideExternalFallbackPage(
          dependencies: widget.dependencies,
          detectedWebViewVersion: detectedWebViewVersion,
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

  Future<void> _onAddRiverSideAccountPressed() async {
    if (_addingRiverSideAccount || _deletingMode) {
      return;
    }

    final support = await RiverSideWebViewSupport.check();
    if (!mounted) {
      return;
    }

    if (!support.canUseEmbeddedWebView) {
      await _openCredentialAddFlow(
        detectedWebViewVersion: support.detectedVersion,
      );
      return;
    }

    setState(() {
      _addingRiverSideAccount = true;
    });

    final profile = await Navigator.of(context).push<UserAccount>(
      riverPageRoute<UserAccount>(
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

    final cookieHeader = widget.dependencies.accountStore
        .riverSideCookieHeaderFor(account.username);
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      _showMessage('Current account session is missing. Please re-login it.');
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
        .join('\u3001');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete accounts'),
          content: Text('\u662f\u5426\u5220\u9664$names\uff1f'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\u53d6\u6d88'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('\u786e\u8ba4'),
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

