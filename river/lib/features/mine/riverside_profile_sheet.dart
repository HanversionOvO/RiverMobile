import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_profile_models.dart';
import 'package:river/core/navigation/river_page_route.dart';
import 'package:river/features/mine/riverside_profile_action_bar.dart';
import 'package:river/features/mine/riverside_profile_page.dart';
import 'package:river/features/notifications/chat_detail_page.dart';

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

  // 使用 PageRouteBuilder 而非 showModalBottomSheet，确保 Hero 转场可用
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        return _RiverSideUserProfileSheet(
          dependencies: dependencies,
          username: normalizedUsername,
          initialAccount: initialAccount,
          cookieHeader: cookieHeader,
          heroTagAvatar: heroTagAvatar,
          heroTagName: heroTagName,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
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
  final trimmedName = (displayName ?? '').trim();
  final trimmedAvatar = (avatarUrl ?? '').trim();

  for (final account in dependencies.accountStore.accountsOf(
    AccountProvider.riverSide,
  )) {
    if (account.username.toLowerCase() == username.toLowerCase()) {
      return account.copyWith(
        displayName: trimmedName.isEmpty ? account.displayName : trimmedName,
        avatarUrl: trimmedAvatar.isEmpty ? account.avatarUrl : trimmedAvatar,
      );
    }
  }

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
  static const double _kInitialSheetSize = 0.45;
  static const double _kMinSheetSize = 0.3;
  static const double _kOpenFullSize = 0.92;
  static const double _kCloseEpsilon = 0.005;

  late Future<RiverSideProfileOverview> _future;
  late UserAccount _resolvedAccount;

  // 用于控制 Sheet 的滚动
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isNavigating = false;
  bool _isClosing = false;
  bool _followBusy = false;
  bool _messageBusy = false;
  bool _isFollowing = false;
  bool _followStateResolved = false;

  @override
  void initState() {
    super.initState();
    _resolvedAccount = widget.initialAccount;
    _future = _loadOverview();
    unawaited(
      _future.then((overview) {
        if (!mounted) return;
        _syncRelationshipState(overview: overview);
      }),
    );

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
    if (_isNavigating || _isClosing) return;
    if (_sheetController.size <= _kMinSheetSize + _kCloseEpsilon) {
      _closeBySwipe();
      return;
    }
    // 当 Sheet 接近顶部时（0.92 是一个经验值，既不太早也不太晚）
    // 自动跳转到全屏页面，给用户一种“弹窗变成了页面”的错觉
    if (_sheetController.size >= _kOpenFullSize) {
      _navigateToFullProfile();
    }
  }

  void _closeBySwipe() {
    if (!mounted || _isClosing) return;
    _isClosing = true;
    Navigator.of(context).maybePop();
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
            heroTag: widget.heroTagAvatar, // 传递头像 Hero Tag
            heroTagName: widget.heroTagName, // 传递昵称 Hero Tag
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
      _followStateResolved = false;
      _future = _loadOverview();
    });
    unawaited(
      _future.then((overview) {
        if (!mounted) return;
        _syncRelationshipState(overview: overview);
      }),
    );
  }

  String? _activeUsername() {
    return widget.dependencies.accountStore.activeRiverSideUsername;
  }

  bool get _isSelfProfile {
    final active = _activeUsername()?.trim().toLowerCase();
    final target = widget.username.trim().toLowerCase();
    if (active == null || active.isEmpty || target.isEmpty) {
      return false;
    }
    return active == target;
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _syncRelationshipState({
    RiverSideProfileOverview? overview,
  }) async {
    if (_isSelfProfile) {
      if (!mounted) return;
      setState(() {
        _followStateResolved = true;
        _isFollowing = false;
      });
      return;
    }

    final initial = overview?.isFollowing;
    if (initial != null && mounted) {
      setState(() {
        _isFollowing = initial;
        _followStateResolved = true;
      });
    }

    final cookie = widget.cookieHeader?.trim() ?? '';
    final active = _activeUsername()?.trim() ?? '';
    if (cookie.isEmpty || active.isEmpty) {
      return;
    }

    try {
      final isFollowing = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .isFollowingUser(
            currentUsername: active,
            targetUsername: widget.username,
            cookieHeader: cookie,
          );
      if (!mounted) return;
      setState(() {
        _isFollowing = isFollowing;
        _followStateResolved = true;
      });
    } catch (_) {
      // Keep UI resilient; fallback to overview-based value.
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _isSelfProfile) {
      return;
    }
    final cookie = widget.cookieHeader?.trim() ?? '';
    final active = _activeUsername()?.trim() ?? '';
    if (cookie.isEmpty || active.isEmpty) {
      _showErrorSnack('请先登录 RiverSide 账号');
      return;
    }

    final nextFollowState = !_isFollowing;
    setState(() {
      _followBusy = true;
    });
    try {
      await widget.dependencies.accountStore.riverSideApiClient.setFollowState(
        targetUsername: widget.username,
        follow: nextFollowState,
        cookieHeader: cookie,
      );
      if (!mounted) return;
      setState(() {
        _isFollowing = nextFollowState;
        _followStateResolved = true;
      });
      _showErrorSnack(nextFollowState ? '关注成功' : '已取消关注');
      unawaited(_syncRelationshipState());
    } on RiverSideApiException catch (error) {
      _showErrorSnack(error.message);
    } catch (_) {
      _showErrorSnack(nextFollowState ? '关注失败，请稍后重试' : '取消关注失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      }
    }
  }

  Future<void> _startPrivateMessage() async {
    if (_messageBusy || _isSelfProfile) {
      return;
    }
    final cookie = widget.cookieHeader?.trim() ?? '';
    if (cookie.isEmpty) {
      _showErrorSnack('请先登录 RiverSide 账号');
      return;
    }

    setState(() {
      _messageBusy = true;
    });
    try {
      final channel = await widget.dependencies.accountStore.riverSideApiClient
          .createOrOpenDirectMessageChannel(
            targetUsername: widget.username,
            cookieHeader: cookie,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        riverPageRoute<void>(
          builder: (_) => ChatDetailPage(
            dependencies: widget.dependencies,
            channel: channel,
          ),
        ),
      );
    } on RiverSideApiException catch (error) {
      _showErrorSnack(error.message);
    } catch (_) {
      _showErrorSnack('发起私信失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _messageBusy = false;
        });
      }
    }
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
      initialChildSize: _kInitialSheetSize, // 初始高度
      minChildSize: _kMinSheetSize,
      maxChildSize: 1.0, // 允许拖满全屏
      snap: true, // 允许吸附
      snapSizes: const [_kInitialSheetSize, 1.0],
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
    if (snapshot.hasData) {
      _resolvedAccount = snapshot.data!.account;
    }

    final account = widget.initialAccount;
    final name = account.displayName.trim().isEmpty
        ? account.username
        : account.displayName;
    final overview = snapshot.data;
    final showFollowButton = !_isSelfProfile && (overview?.canFollow ?? true);
    final showMessageButton =
        !_isSelfProfile && (overview?.canSendPrivateMessage ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          account: account,
          name: name,
          showFollowButton: showFollowButton,
          showMessageButton: showMessageButton,
          isFollowing: _followStateResolved
              ? _isFollowing
              : (overview?.isFollowing ?? false),
        ),
        const SizedBox(height: 16),
        if (snapshot.connectionState == ConnectionState.waiting &&
            overview == null)
          _buildOverviewSkeleton()
        else if (snapshot.hasError && overview == null)
          _buildOverviewError(snapshot.error)
        else if (overview == null)
          const Text('暂无资料')
        else ...[
          if (!overview.isProfileHidden)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(label: '主题', value: overview.topicCount),
                _StatChip(label: '帖子', value: overview.topicCount),
                _StatChip(label: '获赞', value: overview.likesReceived),
                _StatChip(label: '关注', value: overview.followingCount),
                _StatChip(label: '粉丝', value: overview.followersCount),
              ],
            ),
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
      ],
    );
  }

  Widget _buildHeader({
    required UserAccount account,
    required String name,
    required bool showFollowButton,
    required bool showMessageButton,
    required bool isFollowing,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: widget.heroTagAvatar ?? 'profile-avatar-${account.username}',
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: account.avatarUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(account.avatarUrl))
                  : null,
              color: theme.colorScheme.surfaceContainerHighest,
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
              Hero(
                tag: widget.heroTagName ?? 'profile-name-${account.username}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${account.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (account.title.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  account.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showFollowButton || showMessageButton) ...[
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: RiverSideProfileActionBar(
              showFollowButton: showFollowButton,
              showMessageButton: showMessageButton,
              isFollowing: isFollowing,
              followLoading: _followBusy,
              messageLoading: _messageBusy,
              onToggleFollow: _toggleFollow,
              onStartMessage: _startPrivateMessage,
              compact: true,
              messageIconOnly: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewError(Object? error) {
    final message = error is RiverSideApiException
        ? error.message
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

  Widget _buildOverviewSkeleton() {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(
            5,
            (_) => Container(
              width: 64,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSkeletonLine(widthFactor: 0.9),
        const SizedBox(height: 8),
        _buildSkeletonLine(widthFactor: 0.82),
        const SizedBox(height: 8),
        _buildSkeletonLine(widthFactor: 0.72),
      ],
    );
  }

  Widget _buildSkeletonLine({required double widthFactor}) {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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
