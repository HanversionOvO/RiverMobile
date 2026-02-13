part of 'mine_page.dart';

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 0,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.2),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.heroTagPrefix,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? heroTagPrefix;
  final VoidCallback onTap;
  final Widget? trailing;

  String? _tag(String suffix) {
    if (heroTagPrefix == null || heroTagPrefix!.isEmpty) {
      return null;
    }
    return '${heroTagPrefix!}__$suffix';
  }

  Widget _maybeHero({required String? tag, required Widget child}) {
    if (tag == null) {
      return child;
    }
    return Hero(tag: tag, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: _maybeHero(
        tag: _tag('icon'),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
      ),
      title: _maybeHero(
        tag: _tag('title'),
        child: Material(
          type: MaterialType.transparency,
          child: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      subtitle: subtitle != null
          ? _maybeHero(
              tag: _tag('subtitle'),
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          : null,
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.withValues(alpha: 0.5),
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
  final Future<bool> Function(UserAccount) onDelete;

  @override
  State<_AccountManagerSheet> createState() => _AccountManagerSheetState();
}

class _AccountManagerSheetState extends State<_AccountManagerSheet> {
  bool _isEditing = false;
  late List<UserAccount> _accounts;
  String? _activeUsername;

  @override
  void initState() {
    super.initState();
    _accounts = List<UserAccount>.from(widget.accounts);
    _activeUsername = widget.activeAccount?.username;
  }

  void _toggleEditing() {
    HapticFeedback.selectionClick();
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerSubtitle = _isEditing ? '选择要删除的账号' : '点击账号可切换登录状态';
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
              theme.colorScheme.surface,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.manage_accounts_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '账号管理',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: Text(
                              headerSubtitle,
                              key: ValueKey(headerSubtitle),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_accounts.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _toggleEditing,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: _isEditing
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isEditing
                                    ? Icons.done_rounded
                                    : Icons.edit_outlined,
                                size: 16,
                                color: _isEditing
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  _isEditing ? '完成' : '编辑',
                                  key: ValueKey(_isEditing),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _isEditing
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '暂无登录账号',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                    itemCount: _accounts.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final isActive = account.username == _activeUsername;
                      return _buildAccountItem(
                        context: context,
                        account: account,
                        isActive: isActive,
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    _buildBottomAction(
                      icon: Icons.add_circle_outline_rounded,
                      title: '添加 RiverSide 账号',
                      subtitle: '支持 WebView 与账号密码登录',
                      onTap: widget.onAdd,
                      enabled: true,
                    ),
                    const SizedBox(height: 8),
                    _buildBottomAction(
                      icon: Icons.school_outlined,
                      title: '添加 清水河畔 账号',
                      subtitle: '即将上线',
                      onTap: null,
                      enabled: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem({
    required BuildContext context,
    required UserAccount account,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final canSwitch = !_isEditing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canSwitch
            ? () {
                setState(() {
                  _activeUsername = account.username;
                });
                widget.onSwitch(account);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.20)
                : theme.colorScheme.surface.withValues(alpha: 0.72),
            border: Border.all(
              color: isActive && !_isEditing
                  ? theme.colorScheme.primary.withValues(alpha: 0.52)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.8)
                        : Colors.transparent,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: account.avatarUrl.isNotEmpty
                      ? NetworkImage(account.avatarUrl)
                      : null,
                  child: account.avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 19)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${account.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _isEditing
                    ? IconButton.filledTonal(
                        key: const ValueKey('delete'),
                        tooltip: '删除账号',
                        onPressed: () async {
                          final deleted = await widget.onDelete(account);
                          if (!mounted || !deleted) {
                            return;
                          }
                          setState(() {
                            _accounts.removeWhere(
                              (item) =>
                                  item.username.toLowerCase() ==
                                  account.username.toLowerCase(),
                            );
                            if (_activeUsername?.toLowerCase() ==
                                account.username.toLowerCase()) {
                              _activeUsername = _accounts.isNotEmpty
                                  ? _accounts.first.username
                                  : null;
                            }
                            if (_accounts.isEmpty) {
                              _isEditing = false;
                            }
                          });
                        },
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          backgroundColor: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.7),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                      )
                    : isActive
                    ? Container(
                        key: const ValueKey('active'),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      )
                    : Icon(
                        key: const ValueKey('switch'),
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: enabled
                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.78)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.52,
                  ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
