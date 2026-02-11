part of 'mine_page.dart';

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
