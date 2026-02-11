import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_profile_models.dart';
import 'package:river/core/platform/riverside_webview_support.dart';
import 'package:river/features/mine/riverside_profile_webview_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class RiverSideProfilePage extends StatefulWidget {
  const RiverSideProfilePage({
    super.key,
    required this.dependencies,
    required this.account,
    this.cookieHeader,
  });

  final AppDependencies dependencies;
  final UserAccount account;
  final String? cookieHeader;

  @override
  State<RiverSideProfilePage> createState() => _RiverSideProfilePageState();
}

class _RiverSideProfilePageState extends State<RiverSideProfilePage> {
  late Future<RiverSideProfileOverview> _overviewFuture;
  final Map<
    RiverSideProfileActivityKind,
    Future<List<RiverSideProfileActivityItem>>
  >
  _activityFutures =
      <
        RiverSideProfileActivityKind,
        Future<List<RiverSideProfileActivityItem>>
      >{};
  Future<List<RiverSideProfileBadge>>? _badgesFuture;
  Future<List<RiverSideProfileFollowUser>>? _followingFuture;
  Future<List<RiverSideProfileFollowUser>>? _followersFuture;

  bool _openingDetailedProfile = false;

  String get _username => widget.account.username;

  String? _effectiveCookieHeader() {
    final fromWidget = widget.cookieHeader?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }

    final active = widget.dependencies.accountStore.activeRiverSideUsername;
    if (active == null || active.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(active);
  }

  String _requiredCookieHeader() {
    final cookie = _effectiveCookieHeader()?.trim() ?? '';
    if (cookie.isEmpty) {
      throw const RiverSideApiException('当前账号登录态缺失，请重新登录后查看资料');
    }
    return cookie;
  }

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
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

  void _refreshOverview() {
    setState(() {
      _overviewFuture = _loadOverview();
    });
  }

  Future<void> _refreshActivities(RiverSideProfileActivityKind kind) async {
    setState(() {
      _activityFutures[kind] = _loadActivities(kind);
    });
    await _activityFutures[kind];
  }

  Future<void> _refreshBadges() async {
    setState(() {
      _badgesFuture = _loadBadges();
    });
    await _badgesFuture;
  }

  Future<void> _refreshFollowUsers({required bool followers}) async {
    if (followers) {
      setState(() {
        _followersFuture = _loadFollowUsers(followers: true);
      });
      await _followersFuture;
      return;
    }

    setState(() {
      _followingFuture = _loadFollowUsers(followers: false);
    });
    await _followingFuture;
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
    if (_openingDetailedProfile) {
      return;
    }

    setState(() {
      _openingDetailedProfile = true;
    });

    try {
      final cookie = _requiredCookieHeader();
      final support = await RiverSideWebViewSupport.check();
      if (!mounted) {
        return;
      }

      if (!support.canUseEmbeddedWebView) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备不支持内置 WebView，无法在登录态下打开详细资料')),
        );
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _openingDetailedProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.account.displayName.isEmpty
        ? widget.account.username
        : widget.account.displayName;

    return DefaultTabController(
      length: RiverSideProfileActivityKind.values.length + 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              onPressed: _openingDetailedProfile ? null : _openDetailedProfile,
              icon: _openingDetailedProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser_outlined),
              tooltip: '查看详细资料',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final kind in RiverSideProfileActivityKind.values)
                Tab(text: kind.label),
              const Tab(text: '徽章'),
              const Tab(text: '关注中'),
              const Tab(text: '关注者'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildOverviewHeader(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in RiverSideProfileActivityKind.values)
                    _buildActivityTab(kind),
                  _buildBadgesTab(),
                  _buildFollowingTab(),
                  _buildFollowersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewHeader() {
    return FutureBuilder<RiverSideProfileOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error is RiverSideApiException
              ? (snapshot.error as RiverSideApiException).message
              : '加载个人资料失败';
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text(message)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _refreshOverview,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final overview = snapshot.data;
        if (overview == null) {
          return const SizedBox.shrink();
        }

        final account = overview.account;
        final subtitle = account.title.isEmpty
            ? '@${account.username}'
            : '@${account.username} 路 ${account.title}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: account.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(account.avatarUrl),
                        child: account.avatarUrl.isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (overview.isProfileHidden) ...[
                              const SizedBox(height: 6),
                              Text(
                                '该用户已隐藏资料',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!overview.isProfileHidden) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _StatPill(label: '信任', value: '${overview.trustLevel}'),
                        _StatPill(label: '徽章', value: '${overview.badgeCount}'),
                        _StatPill(label: '主题', value: '${overview.topicCount}'),
                        _StatPill(label: '帖子', value: '${overview.postCount}'),
                        _StatPill(
                          label: '获赞',
                          value: '${overview.likesReceived}',
                        ),
                        _StatPill(label: '点赞', value: '${overview.likesGiven}'),
                        _StatPill(
                          label: '粉丝',
                          value: '${overview.followersCount}',
                        ),
                        _StatPill(
                          label: '关注',
                          value: '${overview.followingCount}',
                        ),
                      ],
                    ),
                    if (overview.bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        overview.bio,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _MetaText(
                          icon: Icons.schedule_outlined,
                          text: '注册：${_formatDateTime(overview.createdAt)}',
                        ),
                        _MetaText(
                          icon: Icons.visibility_outlined,
                          text: '访问：${overview.profileViewCount}',
                        ),
                        _MetaText(
                          icon: Icons.access_time,
                          text: '最近在线：${_formatDateTime(overview.lastSeenAt)}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(RiverSideProfileActivityKind kind) {
    return FutureBuilder<RiverSideProfileOverview>(
      future: _overviewFuture,
      builder: (context, overviewSnapshot) {
        if (overviewSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (overviewSnapshot.data?.isProfileHidden == true) {
          return _buildProfileHiddenPlaceholder();
        }

        return FutureBuilder<List<RiverSideProfileActivityItem>>(
          future: _ensureActivityFuture(kind),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is RiverSideApiException
                  ? (snapshot.error as RiverSideApiException).message
                  : '加载动态失败';
              return _ErrorRetryView(
                message: message,
                onRetry: () => _refreshActivities(kind),
              );
            }

            final items =
                snapshot.data ?? const <RiverSideProfileActivityItem>[];
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => _refreshActivities(kind),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('暂无内容')),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _refreshActivities(kind),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openTopicDetail(item.topicId),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: item.authorAvatarUrl.isEmpty
                                      ? null
                                      : NetworkImage(item.authorAvatarUrl),
                                  child: item.authorAvatarUrl.isEmpty
                                      ? const Icon(
                                          Icons.person_outline,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.authorDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  _formatDateTime(item.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (item.excerpt.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.excerpt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _MetaText(
                                  icon: Icons.label_outline,
                                  text: item.categoryName,
                                ),
                                _MetaText(
                                  icon: Icons.chat_bubble_outline,
                                  text: '${item.replyCount}',
                                ),
                                _MetaText(
                                  icon: Icons.visibility_outlined,
                                  text: '${item.viewCount}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildBadgesTab() {
    return FutureBuilder<RiverSideProfileOverview>(
      future: _overviewFuture,
      builder: (context, overviewSnapshot) {
        if (overviewSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (overviewSnapshot.data?.isProfileHidden == true) {
          return _buildProfileHiddenPlaceholder();
        }

        return FutureBuilder<List<RiverSideProfileBadge>>(
          future: _ensureBadgesFuture(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is RiverSideApiException
                  ? (snapshot.error as RiverSideApiException).message
                  : '加载徽章失败';
              return _ErrorRetryView(message: message, onRetry: _refreshBadges);
            }

            final items = snapshot.data ?? const <RiverSideProfileBadge>[];
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshBadges,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('暂无徽章')),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshBadges,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final badge = items[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: badge.imageUrl.isEmpty
                          ? const CircleAvatar(
                              child: Icon(Icons.military_tech_outlined),
                            )
                          : CircleAvatar(
                              backgroundImage: NetworkImage(badge.imageUrl),
                            ),
                      title: Text(
                        badge.name.isEmpty ? '徽章 #${badge.id}' : badge.name,
                      ),
                      subtitle: Text(
                        badge.description.isEmpty
                            ? '${badge.badgeTypeName} · 授予 ${badge.grantCount}'
                            : '${badge.description}\n${badge.badgeTypeName} · 授予 ${badge.grantCount}',
                      ),
                      isThreeLine: badge.description.isNotEmpty,
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

  Widget _buildFollowingTab() {
    return _buildFollowUsersTab(
      future: _ensureFollowingFuture(),
      onRefresh: () => _refreshFollowUsers(followers: false),
      emptyText: '暂无关注用户',
    );
  }

  Widget _buildFollowersTab() {
    return _buildFollowUsersTab(
      future: _ensureFollowersFuture(),
      onRefresh: () => _refreshFollowUsers(followers: true),
      emptyText: '暂无关注者',
    );
  }

  Widget _buildFollowUsersTab({
    required Future<List<RiverSideProfileFollowUser>> future,
    required Future<void> Function() onRefresh,
    required String emptyText,
  }) {
    return FutureBuilder<RiverSideProfileOverview>(
      future: _overviewFuture,
      builder: (context, overviewSnapshot) {
        if (overviewSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (overviewSnapshot.data?.isProfileHidden == true) {
          return _buildProfileHiddenPlaceholder();
        }

        return FutureBuilder<List<RiverSideProfileFollowUser>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is RiverSideApiException
                  ? (snapshot.error as RiverSideApiException).message
                  : '加载用户列表失败';
              return _ErrorRetryView(message: message, onRetry: onRefresh);
            }

            final users = snapshot.data ?? const <RiverSideProfileFollowUser>[];
            if (users.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Center(child: Text(emptyText)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(user.avatarUrl),
                        child: user.avatarUrl.isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text('@${user.username}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openRelatedProfile(user),
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

  Widget _buildProfileHiddenPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 26,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text('该用户已隐藏资料，该分区内容不可见', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }
    final local = value.toLocal();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  const _ErrorRetryView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
