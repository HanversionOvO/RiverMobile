import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_profile_models.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/mine/riverside_profile_action_bar.dart';
import 'package:river/features/mine/riverside_profile_webview_page.dart';
import 'package:river/features/notifications/chat_detail_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class RiverSideProfilePage extends StatefulWidget {
  const RiverSideProfilePage({
    super.key,
    required this.dependencies,
    required this.account,
    this.cookieHeader,
    this.heroTag, // 新增：接收头像 Hero Tag
    this.heroTagName, // 新增：接收昵称 Hero Tag
  });

  final AppDependencies dependencies;
  final UserAccount account;
  final String? cookieHeader;
  final String? heroTag;
  final String? heroTagName;

  @override
  State<RiverSideProfilePage> createState() => _RiverSideProfilePageState();
}

class _RiverSideProfilePageState extends State<RiverSideProfilePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<RiverSideProfileOverview> _overviewFuture;

  final Map<
    RiverSideProfileActivityKind,
    Future<List<RiverSideProfileActivityItem>>
  >
  _activityFutures = {};
  Future<List<RiverSideProfileBadge>>? _badgesFuture;
  Future<List<RiverSideProfileFollowUser>>? _followingFuture;
  Future<List<RiverSideProfileFollowUser>>? _followersFuture;

  bool _openingDetailedProfile = false;
  bool _followBusy = false;
  bool _messageBusy = false;
  bool _isFollowing = false;
  bool _followStateResolved = false;

  final List<_ProfileTabDef> _tabs = [
    for (final kind in RiverSideProfileActivityKind.values)
      _ProfileTabDef(title: kind.label, kind: kind),
    const _ProfileTabDef(title: '徽章'),
    const _ProfileTabDef(title: '关注中'),
    const _ProfileTabDef(title: '粉丝'),
  ];

  String get _username => widget.account.username;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _overviewFuture = _loadOverview();
    unawaited(
      _overviewFuture.then((overview) {
        if (!mounted) return;
        _syncRelationshipState(overview: overview);
      }),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _effectiveCookieHeader() {
    final fromWidget = widget.cookieHeader?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final active = widget.dependencies.accountStore.activeRiverSideUsername;
    if (active == null || active.isEmpty) return null;
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(active);
  }

  String _requiredCookieHeader() {
    final cookie = _effectiveCookieHeader()?.trim() ?? '';
    if (cookie.isEmpty) {
      throw const RiverSideApiException('当前账号登录态缺失，请重新登录后查看资料');
    }
    return cookie;
  }

  Future<RiverSideProfileOverview> _loadOverview() async {
    final cookie = _requiredCookieHeader();
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchProfileOverview(_username, cookieHeader: cookie);
  }

  Future<List<RiverSideProfileActivityItem>> _loadActivities(
    RiverSideProfileActivityKind kind,
  ) async {
    final cookie = _requiredCookieHeader();
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchProfileActivities(_username, kind: kind, cookieHeader: cookie);
  }

  Future<List<RiverSideProfileBadge>> _loadBadges() async {
    final cookie = _requiredCookieHeader();
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchProfileBadges(_username, cookieHeader: cookie);
  }

  Future<List<RiverSideProfileFollowUser>> _loadFollowUsers({
    required bool followers,
  }) async {
    final cookie = _requiredCookieHeader();
    return widget.dependencies.accountStore.riverSideApiClient
        .fetchProfileFollowUsers(
          _username,
          followers: followers,
          cookieHeader: cookie,
        );
  }

  Future<List<RiverSideProfileActivityItem>> _ensureActivityFuture(
    RiverSideProfileActivityKind kind,
  ) {
    return _activityFutures.putIfAbsent(kind, () => _loadActivities(kind));
  }

  Future<List<RiverSideProfileBadge>> _ensureBadgesFuture() {
    return _badgesFuture ??= _loadBadges();
  }

  Future<List<RiverSideProfileFollowUser>> _ensureFollowingFuture() {
    return _followingFuture ??= _loadFollowUsers(followers: false);
  }

  Future<List<RiverSideProfileFollowUser>> _ensureFollowersFuture() {
    return _followersFuture ??= _loadFollowUsers(followers: true);
  }

  Future<void> _openTopicDetail(int topicId) async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topicId,
        ),
      ),
    );
  }

  Future<void> _openRelatedProfile(RiverSideProfileFollowUser user) async {
    final account = UserAccount(
      provider: AccountProvider.riverSide,
      userId: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );

    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => RiverSideProfilePage(
          dependencies: widget.dependencies,
          account: account,
          cookieHeader: _requiredCookieHeader(),
        ),
      ),
    );
  }

  Future<void> _openDetailedProfile() async {
    if (_openingDetailedProfile) return;
    setState(() => _openingDetailedProfile = true);

    try {
      final cookie = _requiredCookieHeader();
      final support = await RiverSideWebViewSupport.check();
      if (!mounted) return;

      if (!support.canUseEmbeddedWebView) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前设备不支持内置 WebView')));
        return;
      }

      await Navigator.of(context).push(
        riverPageRoute<void>(
          builder: (_) => RiverSideProfileWebViewPage(
            username: _username,
            title: widget.account.displayName,
            cookieHeader: cookie,
          ),
        ),
      );
    } on RiverSideApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _openingDetailedProfile = false);
    }
  }

  String? _activeUsername() {
    return widget.dependencies.accountStore.activeRiverSideUsername;
  }

  bool get _isSelfProfile {
    final active = _activeUsername()?.trim().toLowerCase();
    final target = _username.trim().toLowerCase();
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

    final cookie = _effectiveCookieHeader()?.trim() ?? '';
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
            targetUsername: _username,
            cookieHeader: cookie,
          );
      if (!mounted) return;
      setState(() {
        _isFollowing = isFollowing;
        _followStateResolved = true;
      });
    } catch (_) {
      // Keep UI resilient.
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _isSelfProfile) {
      return;
    }
    final cookie = _effectiveCookieHeader()?.trim() ?? '';
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
        targetUsername: _username,
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
    final cookie = _effectiveCookieHeader()?.trim() ?? '';
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
            targetUsername: _username,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.account.displayName.isNotEmpty
        ? widget.account.displayName
        : widget.account.username;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              title: Text(
                innerBoxIsScrolled ? displayName : '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: theme.colorScheme.surface.withValues(
                alpha: 0.95,
              ),
              elevation: 0,
              scrolledUnderElevation: 2,
              actions: [
                IconButton(
                  onPressed: _openingDetailedProfile
                      ? null
                      : _openDetailedProfile,
                  icon: _openingDetailedProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_browser_rounded),
                  tooltip: '网页版详细资料',
                ),
              ],
            ),
            SliverToBoxAdapter(child: _buildProfileHeader(theme, displayName)),
            SliverPersistentHeader(
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: _tabs.map((t) => Tab(text: t.title)).toList(),
                ),
                color: theme.colorScheme.surface,
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            if (tab.kind != null) {
              return _ActivityTab(
                kind: tab.kind!,
                overviewFuture: _overviewFuture,
                activityFuture: _ensureActivityFuture(tab.kind!),
                onRefresh: () async {
                  setState(() {
                    _activityFutures[tab.kind!] = _loadActivities(tab.kind!);
                  });
                  await _activityFutures[tab.kind!];
                },
                onItemTap: (item) => _openTopicDetail(item.topicId),
              );
            } else if (tab.title == '徽章') {
              return _BadgesTab(
                overviewFuture: _overviewFuture,
                badgesFuture: _ensureBadgesFuture(),
                onRefresh: () async {
                  setState(() => _badgesFuture = _loadBadges());
                  await _badgesFuture;
                },
              );
            } else {
              final isFollowers = tab.title == '粉丝';
              return _UsersTab(
                overviewFuture: _overviewFuture,
                usersFuture: isFollowers
                    ? _ensureFollowersFuture()
                    : _ensureFollowingFuture(),
                onRefresh: () async {
                  if (isFollowers) {
                    setState(
                      () =>
                          _followersFuture = _loadFollowUsers(followers: true),
                    );
                    await _followersFuture;
                  } else {
                    setState(
                      () =>
                          _followingFuture = _loadFollowUsers(followers: false),
                    );
                    await _followingFuture;
                  }
                },
                onUserTap: _openRelatedProfile,
                emptyText: isFollowers ? '暂无粉丝' : '暂无关注',
              );
            }
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, String displayName) {
    return FutureBuilder<RiverSideProfileOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        final overview = snapshot.data!;
        final account = overview.account;
        final showFollowButton = !_isSelfProfile && overview.canFollow;
        final showMessageButton =
            !_isSelfProfile && overview.canSendPrivateMessage;

        // 使用传入的 Hero Tag，如果没有则不使用
        Widget avatarWidget = Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.surfaceContainerHighest,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: account.avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(account.avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: account.avatarUrl.isEmpty
              ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
              : null,
        );

        if (widget.heroTag != null) {
          avatarWidget = Hero(tag: widget.heroTag!, child: avatarWidget);
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatarWidget,
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final nameWidget = Text(
                              displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                            final nameHeroTag = widget.heroTagName;
                            if (nameHeroTag == null || nameHeroTag.isEmpty) {
                              return nameWidget;
                            }
                            return Hero(
                              tag: nameHeroTag,
                              child: Material(
                                color: Colors.transparent,
                                child: nameWidget,
                              ),
                            );
                          },
                        ),
                        Text(
                          '@${account.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (overview.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  overview.location,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (showFollowButton || showMessageButton) ...[
                const SizedBox(height: 16),
                RiverSideProfileActionBar(
                  showFollowButton: showFollowButton,
                  showMessageButton: showMessageButton,
                  isFollowing: _followStateResolved
                      ? _isFollowing
                      : overview.isFollowing,
                  followLoading: _followBusy,
                  messageLoading: _messageBusy,
                  onToggleFollow: _toggleFollow,
                  onStartMessage: _startPrivateMessage,
                ),
              ],

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context, '${overview.postCount}', '帖子'),
                  _buildStatItem(context, '${overview.followingCount}', '关注'),
                  _buildStatItem(context, '${overview.followersCount}', '粉丝'),
                  _buildStatItem(context, '${overview.likesReceived}', '获赞'),
                ],
              ),

              if (overview.bio.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  overview.bio,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    label: '信任等级 ${overview.trustLevel}',
                    icon: Icons.verified_user_outlined,
                    color: Colors.green,
                  ),
                  if (overview.lastSeenAt != null)
                    _MetaChip(
                      label: '最近活跃 ${_formatDateShort(overview.lastSeenAt!)}',
                      icon: Icons.access_time,
                    ),
                  if (overview.createdAt != null)
                    _MetaChip(
                      label: '加入于 ${_formatDateShort(overview.createdAt!)}',
                      icon: Icons.calendar_today_outlined,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatDateShort(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

class _ActivityTab extends StatefulWidget {
  final RiverSideProfileActivityKind kind;
  final Future<RiverSideProfileOverview> overviewFuture;
  final Future<List<RiverSideProfileActivityItem>> activityFuture;
  final Future<void> Function() onRefresh;
  final ValueChanged<RiverSideProfileActivityItem> onItemTap;

  const _ActivityTab({
    required this.kind,
    required this.overviewFuture,
    required this.activityFuture,
    required this.onRefresh,
    required this.onItemTap,
  });

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<RiverSideProfileOverview>(
      future: widget.overviewFuture,
      builder: (context, overviewSnap) {
        if (!overviewSnap.hasData) return const SizedBox();
        if (overviewSnap.data!.isProfileHidden) {
          return const _ProfileHiddenView();
        }

        return FutureBuilder<List<RiverSideProfileActivityItem>>(
          future: widget.activityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorRetryView(
                message: '加载失败',
                onRetry: widget.onRefresh,
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return _EmptyView(
                message: '暂无${widget.kind.label}动态',
                onRefresh: widget.onRefresh,
              );
            }

            return RefreshIndicator(
              onRefresh: widget.onRefresh,
              edgeOffset: 0,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ActivityCard(
                    item: item,
                    onTap: () => widget.onItemTap(item),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.onTap});

  final RiverSideProfileActivityItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(item.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.excerpt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.excerpt.replaceAll('\n', ' '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _IconStat(
                    Icons.chat_bubble_outline_rounded,
                    '${item.replyCount}',
                  ),
                  const SizedBox(width: 16),
                  _IconStat(Icons.remove_red_eye_outlined, '${item.viewCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day}';
  }
}

class _IconStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconStat(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _BadgesTab extends StatelessWidget {
  final Future<RiverSideProfileOverview> overviewFuture;
  final Future<List<RiverSideProfileBadge>> badgesFuture;
  final Future<void> Function() onRefresh;

  const _BadgesTab({
    required this.overviewFuture,
    required this.badgesFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RiverSideProfileOverview>(
      future: overviewFuture,
      builder: (context, overviewSnap) {
        if (overviewSnap.hasData && overviewSnap.data!.isProfileHidden) {
          return const _ProfileHiddenView();
        }
        return FutureBuilder<List<RiverSideProfileBadge>>(
          future: badgesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final items = snapshot.data ?? [];
            if (items.isEmpty)
              return _EmptyView(message: '暂无徽章', onRefresh: onRefresh);

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final badge = items[index];
                  return ListTile(
                    tileColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: badge.imageUrl.isNotEmpty
                        ? Image.network(badge.imageUrl, width: 40)
                        : const Icon(Icons.shield_outlined, size: 40),
                    title: Text(badge.name),
                    subtitle: Text(
                      badge.description.isNotEmpty
                          ? badge.description
                          : badge.badgeTypeName,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  final Future<RiverSideProfileOverview> overviewFuture;
  final Future<List<RiverSideProfileFollowUser>> usersFuture;
  final Future<void> Function() onRefresh;
  final ValueChanged<RiverSideProfileFollowUser> onUserTap;
  final String emptyText;

  const _UsersTab({
    required this.overviewFuture,
    required this.usersFuture,
    required this.onRefresh,
    required this.onUserTap,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RiverSideProfileOverview>(
      future: overviewFuture,
      builder: (context, overviewSnap) {
        if (overviewSnap.hasData && overviewSnap.data!.isProfileHidden) {
          return const _ProfileHiddenView();
        }
        return FutureBuilder<List<RiverSideProfileFollowUser>>(
          future: usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final items = snapshot.data ?? [];
            if (items.isEmpty)
              return _EmptyView(message: emptyText, onRefresh: onRefresh);

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final user = items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child: user.avatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user.displayName),
                    subtitle: Text('@${user.username}'),
                    onTap: () => onUserTap(user),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileHiddenView extends StatelessWidget {
  const _ProfileHiddenView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text('用户已隐藏资料', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _MetaChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: finalColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: finalColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;
  const _EmptyView({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.grey)),
          TextButton(onPressed: onRefresh, child: const Text('刷新')),
        ],
      ),
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;

  _StickyTabBarDelegate(this._tabBar, {required this.color});

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: color, child: _tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}

class _ProfileTabDef {
  final String title;
  final RiverSideProfileActivityKind? kind;
  const _ProfileTabDef({required this.title, this.kind});
}
