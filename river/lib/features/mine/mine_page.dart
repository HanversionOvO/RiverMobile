import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/features/mine/about_page.dart';
import 'package:river/features/mine/appearance_settings_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  bool _addingRiverSideAccount = false;

  Future<void> _promptAddRiverSideAccount() async {
    var inputValue = '';
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('添加 RiverSide 账号'),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              inputValue = value;
            },
            decoration: const InputDecoration(
              labelText: 'RiverSide 用户名',
              hintText: 'MikannOvO',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = inputValue.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (username == null || username.isEmpty) {
      return;
    }

    setState(() {
      _addingRiverSideAccount = true;
    });

    final result = await widget.dependencies.accountStore.addRiverSideAccount(
      username,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _addingRiverSideAccount = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _showQingPlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('清水河畔账号功能暂未实现')));
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _ModuleHeader(title: '账号模块'),
            _AccountSectionCard(
              title: 'RiverSide 账号',
              accounts: riverSideAccounts,
              emptySubtitle: '登录后会自动获取并保存账号信息',
              onAddPressed: _addingRiverSideAccount
                  ? null
                  : _promptAddRiverSideAccount,
              isBusy: _addingRiverSideAccount,
            ),
            const SizedBox(height: 12),
            _AccountSectionCard(
              title: '清水河畔 账号',
              accounts: qingAccounts,
              emptySubtitle: '暂未接入，敬请期待',
              onAddPressed: _showQingPlaceholder,
            ),
            const SizedBox(height: 20),
            const _ModuleHeader(title: '应用与外观'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('外观设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAppearanceSettings,
              ),
            ),
            const SizedBox(height: 20),
            const _ModuleHeader(title: '其他'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
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

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({
    required this.title,
    required this.accounts,
    required this.emptySubtitle,
    required this.onAddPressed,
    this.isBusy = false,
  });

  final String title;
  final List<UserAccount> accounts;
  final String emptySubtitle;
  final VoidCallback? onAddPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      ListTile(
        title: Text(title),
        trailing: IconButton(
          onPressed: onAddPressed,
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          tooltip: '添加账号',
        ),
      ),
    ];

    if (accounts.isEmpty) {
      tiles.add(
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
          title: const Text('添加账号'),
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
            onTap: () {},
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
