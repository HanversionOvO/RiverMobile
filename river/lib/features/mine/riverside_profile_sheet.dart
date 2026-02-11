import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_profile_models.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

Future<void> showRiverSideUserProfileSheet({
  required BuildContext context,
  required AppDependencies dependencies,
  required String username,
  String? displayName,
  String? avatarUrl,
  String? heroTagAvatar, // 新增：接收 Hero Tag
  String? heroTagName, // 新增：接收 Hero Tag
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

  // 显示弹窗
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    // 允许内容拖拽
    enableDrag: true,
    builder: (_) {
      return _RiverSideUserProfileSheet(
        dependencies: dependencies,
        username: normalizedUsername,
        initialAccount: initialAccount,
        cookieHeader: cookieHeader,
        heroTagAvatar: heroTagAvatar,
        heroTagName: heroTagName,
      );
    },
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

class _RiverSideUserProfileSheet extends StatefulWidget {
  const _RiverSideUserProfileSheet({
    required this.dependencies,
    required this.username,
    required this.initialAccount,
    required this.cookieHeader,
    this.heroTagAvatar,
    this.heroTagName,
  });

  final AppDependencies dependencies;
  final String username;
  final UserAccount initialAccount;
  final String? cookieHeader;
  final String? heroTagAvatar;
  final String? heroTagName;

  @override
  State<_RiverSideUserProfileSheet> createState() =>
      _RiverSideUserProfileSheetState();
}

class _RiverSideUserProfileSheetState
    extends State<_RiverSideUserProfileSheet> {
  late Future<RiverSideProfileOverview> _future;
  late UserAccount _resolvedAccount;

  // 用于控制 Sheet 的滚动
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _resolvedAccount = widget.initialAccount;
    _future = _loadOverview();

    // 监听拖拽进度，实现无缝跳转
    _sheetController.addListener(_onSheetScrolled);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetScrolled);
    _sheetController.dispose();
    super.dispose();
  }

  void _onSheetScrolled() {
    if (_isNavigating) return;
    // 当 Sheet 接近顶部时（0.92 是一个经验值，既不太早也不太晚）
    // 自动跳转到全屏页面，给用户一种“弹窗变成了页面”的错觉
    if (_sheetController.size >= 0.92) {
      _navigateToFullProfile();
    }
  }

  Future<void> _navigateToFullProfile() async {
    if (_isNavigating) return;
    _isNavigating = true;

    // 关闭当前 Sheet (使用无动画关闭，或者直接让新页面覆盖它)
    // 为了连贯性，我们直接 Push 新页面，新页面背景是实色的，会覆盖 Sheet
    // 并且因为使用了 Hero，头像会飞过去

    // 1. 获取当前上下文的 Navigator，防止 context 失效
    final navigator = Navigator.of(context);

    // 2. 跳转到详情页
    // 使用 FadeTransition 或 SlideTransition 可以让效果更像“融合”
    // 这里使用标准的 route，但因为 Hero 的存在，视觉焦点会保持
    await navigator.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return RiverSideProfilePage(
            dependencies: widget.dependencies,
            account: _resolvedAccount,
            cookieHeader: widget.cookieHeader,
            heroTag: widget.heroTagAvatar, // 传递 Hero Tag
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // 3. 页面返回后，如果还在 mounted 状态，可以重置标志位
    // 或者通常如果是“融合”效果，回来时可以直接关闭 Sheet
    if (mounted) {
      Navigator.pop(context); // 回来后直接关闭 Sheet，避免显示两层
    }
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

  void _onExpandButtonPressed() {
    // 点击按钮时，先动画滚动到顶部，触发 _onSheetScrolled 中的跳转逻辑
    _sheetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.45, // 初始高度
      minChildSize: 0.3,
      maxChildSize: 1.0, // 允许拖满全屏
      snap: true, // 允许吸附
      snapSizes: const [0.45, 1.0],
      builder: (context, scrollController) {
        return Material(
          clipBehavior: Clip.antiAlias,
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '用户资料',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.outline,
                  ),
                ),
              ),

              // 内容区域
              Expanded(
                child: FutureBuilder<RiverSideProfileOverview>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _resolvedAccount = snapshot.data!.account;
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const SizedBox(height: 10),
                        _buildBody(snapshot),
                        const SizedBox(height: 24),
                        FilledButton.tonalIcon(
                          onPressed: _onExpandButtonPressed,
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                          ),
                          label: const Text('展开完整资料'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
            // 头像部分
            Hero(
              tag: widget.heroTagAvatar ?? 'default_avatar',
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: account.avatarUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(account.avatarUrl))
                      : null,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: account.avatarUrl.isEmpty
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 昵称部分
                  // 注意：如果需要名字也飞过去，可以给 Text 包裹 Material 再包裹 Hero
                  // 这里为了简单和效果稳定，仅演示头像 Hero
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!overview.isProfileHidden) ...[
          const SizedBox(height: 16),
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
        ],
        if (!overview.isProfileHidden && overview.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
