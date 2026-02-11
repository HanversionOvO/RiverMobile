import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_profile_models.dart';
import 'package:river/features/mine/riverside_profile_page.dart';

Future<void> showRiverSideUserProfileSheet({
  required BuildContext context,
  required AppDependencies dependencies,
  required String username,
  String? displayName,
  String? avatarUrl,
}) async {
  final normalizedUsername = username.trim();
  if (normalizedUsername.isEmpty) {
    return;
  }

  final cookieHeader = _activeCookieHeader(dependencies);
  final initialAccount = _resolveAccount(
    dependencies: dependencies,
    username: normalizedUsername,
    displayName: displayName,
    avatarUrl: avatarUrl,
  );

  final result = await showModalBottomSheet<_ProfileSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _RiverSideUserProfileSheet(
        dependencies: dependencies,
        username: normalizedUsername,
        initialAccount: initialAccount,
        cookieHeader: cookieHeader,
      );
    },
  );

  if (result == null || !result.openFull) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RiverSideProfilePage(
        dependencies: dependencies,
        account: result.account,
        cookieHeader: cookieHeader,
      ),
    ),
  );
}

String? _activeCookieHeader(AppDependencies dependencies) {
  final active = dependencies.accountStore.activeRiverSideUsername;
  if (active == null || active.isEmpty) {
    return null;
  }
  return dependencies.accountStore.riverSideCookieHeaderFor(active);
}

UserAccount _resolveAccount({
  required AppDependencies dependencies,
  required String username,
  String? displayName,
  String? avatarUrl,
}) {
  for (final account in dependencies.accountStore.accountsOf(
    AccountProvider.riverSide,
  )) {
    if (account.username.toLowerCase() == username.toLowerCase()) {
      return account;
    }
  }

  final trimmedName = (displayName ?? '').trim();
  return UserAccount(
    provider: AccountProvider.riverSide,
    username: username,
    displayName: trimmedName.isEmpty ? username : trimmedName,
    avatarUrl: (avatarUrl ?? '').trim(),
  );
}

class _ProfileSheetResult {
  const _ProfileSheetResult({required this.openFull, required this.account});

  final bool openFull;
  final UserAccount account;
}

class _RiverSideUserProfileSheet extends StatefulWidget {
  const _RiverSideUserProfileSheet({
    required this.dependencies,
    required this.username,
    required this.initialAccount,
    required this.cookieHeader,
  });

  final AppDependencies dependencies;
  final String username;
  final UserAccount initialAccount;
  final String? cookieHeader;

  @override
  State<_RiverSideUserProfileSheet> createState() =>
      _RiverSideUserProfileSheetState();
}

class _RiverSideUserProfileSheetState
    extends State<_RiverSideUserProfileSheet> {
  static const double _expandToFullThreshold = 0.92;

  late Future<RiverSideProfileOverview> _future;
  late UserAccount _resolvedAccount;
  bool _openingFull = false;

  @override
  void initState() {
    super.initState();
    _resolvedAccount = widget.initialAccount;
    _future = _loadOverview();
  }

  Future<RiverSideProfileOverview> _loadOverview() {
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchProfileOverview(
          widget.username,
          cookieHeader: widget.cookieHeader,
        );
  }

  void _retry() {
    setState(() {
      _future = _loadOverview();
    });
  }

  void _openFullProfile() {
    if (_openingFull) {
      return;
    }
    _openingFull = true;
    Navigator.of(
      context,
    ).pop(_ProfileSheetResult(openFull: true, account: _resolvedAccount));
  }

  bool _onDraggableNotification(DraggableScrollableNotification notification) {
    if (notification.extent >= _expandToFullThreshold) {
      _openFullProfile();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onDraggableNotification,
      child: DraggableScrollableSheet(
        initialChildSize: 0.46,
        minChildSize: 0.32,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: FutureBuilder<RiverSideProfileOverview>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _resolvedAccount = snapshot.data!.account;
                }
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '用户资料',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _buildBody(snapshot),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _openFullProfile,
                      icon: const Icon(Icons.open_in_full_outlined, size: 18),
                      label: const Text('展开完整资料'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<RiverSideProfileOverview> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      final message = snapshot.error is RiverSideApiException
          ? (snapshot.error! as RiverSideApiException).message
          : '资料加载失败，请稍后重试';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      );
    }

    final overview = snapshot.data;
    if (overview == null) {
      return const Text('暂无资料');
    }

    final account = overview.account;
    final name = account.displayName.trim().isEmpty
        ? account.username
        : account.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: account.avatarUrl.isEmpty
                  ? null
                  : NetworkImage(account.avatarUrl),
              child: account.avatarUrl.isEmpty
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${account.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (account.title.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      account.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: '主题', value: overview.topicCount),
            _StatChip(label: '帖子', value: overview.postCount),
            _StatChip(label: '获赞', value: overview.likesReceived),
            _StatChip(label: '关注', value: overview.followingCount),
            _StatChip(label: '粉丝', value: overview.followersCount),
          ],
        ),
        if (overview.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            overview.bio.trim(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
