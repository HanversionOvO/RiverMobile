import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/features/notifications/chat_detail_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.dependencies,
    this.onUnreadCountChanged,
  });

  final AppDependencies dependencies;
  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // 常量与状态定义
  // ---------------------------------------------------------------------------
  static const String _labelNeedLogin = '请先登录 RiverSide 账号';
  static const String _labelLoadFailed = '加载失败，请重试';
  static const String _labelSessionExpired = '登录态已失效，请重新登录';

  late TabController _tabController;
  final ScrollController _notificationsScrollController = ScrollController();

  List<RiverSideNotificationItem> _notifications = const [];
  List<RiverSideChatChannelItem> _channelMessages = const [];
  List<RiverSideChatChannelItem> _directMessages = const [];

  String _nextNotificationsPath = '';
  int? _totalNotifications;
  bool _loading = true;
  bool _loadingMoreNotifications = false;
  int _requestSerial = 0;
  String? _error;
  String? _lastActiveUsername;

  RiverSideMessageBusPoller? _messageBusPoller;
  bool _hasRealtimeNotifications = false;

  // ---------------------------------------------------------------------------
  // 生命周期与基础逻辑
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _notificationsScrollController.addListener(_onNotificationsScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _messageBusPoller?.stop();
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _notificationsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  int get _totalUnreadCount {
    final unreadNotifications = _notifications
        .where((item) => !item.read)
        .length;
    final unreadChannels = _channelMessages.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );
    final unreadDirectMessages = _directMessages.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );
    return unreadNotifications + unreadChannels + unreadDirectMessages;
  }

  void _notifyUnreadCountChanged() {
    widget.onUnreadCountChanged?.call(_totalUnreadCount);
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) return;

    _lastActiveUsername = current;
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    if (mounted) {
      setState(() {
        _loading = true;
        _notifications = [];
        _channelMessages = [];
        _directMessages = [];
        _error = null;
        _hasRealtimeNotifications = false;
      });
    }
    _loadAll(clearExisting: true);
  }

  void _onNotificationsScroll() {
    if (_tabController.index != 0) return;

    if (_loading ||
        _loadingMoreNotifications ||
        _nextNotificationsPath.isEmpty) {
      return;
    }
    if (!_notificationsScrollController.hasClients) return;

    final position = _notificationsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) return null;
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  // ---------------------------------------------------------------------------
  // 数据加载逻辑
  // ---------------------------------------------------------------------------

  Future<void> _loadAll({
    bool showLoading = true,
    bool clearExisting = false,
  }) async {
    final serial = ++_requestSerial;
    final cookieHeader = _activeCookieHeader();

    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = _labelNeedLogin;
        if (clearExisting) {
          _notifications = [];
          _channelMessages = [];
          _directMessages = [];
        }
      });
      _notifyUnreadCountChanged();
      return;
    }

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
        if (clearExisting) {
          _notifications = [];
          _channelMessages = [];
          _directMessages = [];
        }
      });
    }

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final results = await Future.wait([
        api.fetchNotificationsPage(cookieHeader: cookieHeader),
        api.fetchMyChatChannels(cookieHeader: cookieHeader),
      ]);

      if (!mounted || serial != _requestSerial) return;

      final notificationPage = results[0] as RiverSideNotificationPage;
      final channels = results[1] as List<RiverSideChatChannelItem>;

      setState(() {
        _loading = false;
        _error = null;
        _hasRealtimeNotifications = false;
        _notifications = notificationPage.items;
        _nextNotificationsPath = notificationPage.loadMorePath;
        _totalNotifications = notificationPage.totalRows;
        _channelMessages = channels
            .where((item) => !item.isDirectMessage)
            .toList();
        _directMessages = channels
            .where((item) => item.isDirectMessage)
            .toList();
      });

      _notifyUnreadCountChanged();
      _restartRealtimePolling();
    } catch (e) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error =
            e is RiverSideApiException && e.message.contains('session expired')
            ? _labelSessionExpired
            : _labelLoadFailed;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_nextNotificationsPath.isEmpty) return;

    setState(() => _loadingMoreNotifications = true);

    try {
      final cookieHeader = _activeCookieHeader();
      if (cookieHeader == null) return;

      final api = widget.dependencies.accountStore.riverSideApiClient;
      final page = await api.fetchNotificationsPage(
        cookieHeader: cookieHeader,
        loadMorePath: _nextNotificationsPath,
      );

      if (!mounted) return;

      setState(() {
        final existingIds = _notifications.map((e) => e.id).toSet();
        final newItems = page.items.where((e) => !existingIds.contains(e.id));
        _notifications = [..._notifications, ...newItems];
        _nextNotificationsPath = page.loadMorePath;
        _loadingMoreNotifications = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMoreNotifications = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 动作逻辑
  // ---------------------------------------------------------------------------

  Future<void> _openNotificationTopic(RiverSideNotificationItem item) async {
    if (item.topicId == null || item.topicId! <= 0) return;

    if (!item.read) {
      setState(() {
        final index = _notifications.indexWhere((e) => e.id == item.id);
        if (index != -1) {
          _notifications[index] = RiverSideNotificationItem(
            id: item.id,
            type: item.type,
            read: true,
            highPriority: item.highPriority,
            createdAt: item.createdAt,
            topicId: item.topicId,
            postNumber: item.postNumber,
            slug: item.slug,
            title: item.title,
            excerpt: item.excerpt,
            username: item.username,
            actionText: item.actionText,
            badgeName: item.badgeName,
            count: item.count,
            avatarUrl: item.avatarUrl,
          );
        }
      });
      _notifyUnreadCountChanged();

      final cookie = _activeCookieHeader();
      if (cookie != null) {
        widget.dependencies.accountStore.riverSideApiClient
            .markNotificationsAsRead(
              cookieHeader: cookie,
              notificationId: item.id,
            )
            .ignore();
      }
    }

    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: item.topicId!,
        ),
      ),
    );
  }

  Future<void> _openChatDetail(RiverSideChatChannelItem channel) async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) =>
            ChatDetailPage(dependencies: widget.dependencies, channel: channel),
      ),
    );
  }

  Future<void> _consumeRealtimeNotifications() async {
    setState(() => _hasRealtimeNotifications = false);
    await _loadAll(showLoading: false);

    if (_notificationsScrollController.hasClients) {
      _notificationsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  Future<void> _restartRealtimePolling() async {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookie = _activeCookieHeader();
    if (cookie == null) return;

    var userId =
        widget.dependencies.accountStore.activeRiverSideAccount?.userId;
    if (userId == null) return;

    final channel = '/notification/$userId';
    _messageBusPoller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookie,
      channelLastIds: RiverSideMessageBusPoller.buildInitialChannels([channel]),
      onEvents: (events) {
        if (!mounted) return;
        if (events.any((e) => e.channel == channel)) {
          setState(() => _hasRealtimeNotifications = true);
        }
      },
    );
    _messageBusPoller?.start();
  }

  // ---------------------------------------------------------------------------
  // UI 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. 背景装饰 (淡雅的光晕)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // 2. 主内容区域
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  snap: true,
                  automaticallyImplyLeading: false, // 移除返回按钮位置
                  toolbarHeight: 8, // 压缩 Toolbar 高度，只留给 TabBar 空间
                  backgroundColor: backgroundColor.withOpacity(0.9),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildSegmentedTabBar(theme),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsList(theme),
                _buildChatList(theme, _channelMessages, '暂无频道消息'),
                _buildChatList(theme, _directMessages, '暂无私信消息'),
              ],
            ),
          ),

          // 3. 实时消息提示条
          _buildRealtimeBanner(theme),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          _buildTabItem('通知', _notifications.where((n) => !n.read).length),
          _buildTabItem(
            '频道',
            _channelMessages.fold(0, (sum, i) => sum + i.unreadCount),
          ),
          _buildTabItem(
            '私信',
            _directMessages.fold(0, (sum, i) => sum + i.unreadCount),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsList(ThemeData theme) {
    if (_loading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _notifications.isEmpty) {
      return _buildErrorView();
    }

    if (_notifications.isEmpty) {
      return _buildEmptyView('暂无通知', Icons.notifications_none_rounded);
    }

    return RefreshIndicator(
      onRefresh: () => _loadAll(showLoading: false),
      child: ListView.separated(
        controller: _notificationsScrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _notifications.length + (_loadingMoreNotifications ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildNotificationCard(theme, _notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    ThemeData theme,
    RiverSideNotificationItem item,
  ) {
    // 根据通知类型配置样式
    IconData typeIcon;
    Color typeColor;
    Color iconBgColor;

    switch (item.type) {
      case 6: // Private Message
        typeIcon = Icons.mail_rounded;
        typeColor = Colors.orange.shade700;
        iconBgColor = Colors.orange.shade50;
        break;
      case 5: // Like
        typeIcon = Icons.favorite_rounded;
        typeColor = Colors.pink.shade400;
        iconBgColor = Colors.pink.shade50;
        break;
      case 2: // Replied
        typeIcon = Icons.reply_rounded;
        typeColor = Colors.blue.shade600;
        iconBgColor = Colors.blue.shade50;
        break;
      case 12: // Badge
        typeIcon = Icons.military_tech_rounded;
        typeColor = Colors.amber.shade700;
        iconBgColor = Colors.amber.shade50;
        break;
      default: // Mention or others
        typeIcon = Icons.alternate_email_rounded;
        typeColor = theme.colorScheme.primary;
        iconBgColor = theme.colorScheme.primaryContainer.withOpacity(0.3);
    }

    final isUnread = !item.read;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openNotificationTopic(item),
          child: Stack(
            children: [
              // 未读指示条
              if (isUnread)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像与角标
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.surfaceContainer,
                            backgroundImage: item.avatarUrl.isNotEmpty
                                ? NetworkImage(item.avatarUrl)
                                : null,
                            child: item.avatarUrl.isEmpty
                                ? Icon(
                                    Icons.person,
                                    size: 22,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: typeColor.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Icon(typeIcon, size: 12, color: typeColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: item.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '  ${item.actionText ?? ""}',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTime(item.createdAt),
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (item.title != null && item.title!.isNotEmpty)
                            Text(
                              item.title!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.excerpt != null &&
                              item.excerpt!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.excerpt!.replaceAll('\n', ' '),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildChatList(
    ThemeData theme,
    List<RiverSideChatChannelItem> items,
    String emptyMsg,
  ) {
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return _buildEmptyView(emptyMsg, Icons.chat_bubble_outline_rounded);
    }

    return RefreshIndicator(
      onRefresh: () => _loadAll(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              onTap: () => _openChatDetail(item),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tag_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              title: Text(
                '频道 #${item.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text('点击查看详情'),
              trailing: item.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealtimeBanner(ThemeData theme) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 2),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _hasRealtimeNotifications
              ? Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FloatingActionButton.extended(
                    onPressed: _consumeRealtimeNotifications,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('收到新消息，点击刷新'),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildEmptyView(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _loadAll(showLoading: true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('刷新'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error ?? _labelLoadFailed),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: _loadAll, child: const Text('重试')),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
}
