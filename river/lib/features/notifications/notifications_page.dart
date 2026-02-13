import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/navigation/river_page_route.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/features/notifications/chat_detail_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';

part 'notifications_page_actions.dart';
part 'notifications_page_view.dart';

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
  static const String _labelNeedLogin = '请先登录 RiverSide 账号';
  static const String _labelLoadFailed = '加载失败，请重试';
  static const String _labelSessionExpired = '登录态已失效，请重新登录';

  late TabController _tabController;
  final ScrollController _notificationsScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _directScrollController = ScrollController();
  final ValueNotifier<bool> _showBackToTopNotifier = ValueNotifier<bool>(false);

  List<RiverSideNotificationItem> _notifications = const [];
  List<RiverSideChatChannelItem> _channelMessages = const [];
  List<RiverSideChatChannelItem> _directMessages = const [];
  final Set<int> _deletingDirectMessageIds = <int>{};

  String _nextNotificationsPath = '';
  bool _loading = true;
  bool _loadingMoreNotifications = false;
  double _headerScrollFactor = 0;
  int _requestSerial = 0;
  String? _error;
  String? _lastActiveUsername;

  RiverSideMessageBusPoller? _messageBusPoller;
  bool _hasRealtimeNotifications = false;

  void _setState(VoidCallback fn) {
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    widget.dependencies.settingsController.addListener(
      _onRefreshBannerSettingsChanged,
    );
    _notificationsScrollController.addListener(_onNotificationsScroll);
    _channelScrollController.addListener(_onChannelScroll);
    _directScrollController.addListener(_onDirectScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _messageBusPoller?.stop();
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    widget.dependencies.settingsController.removeListener(
      _onRefreshBannerSettingsChanged,
    );
    _tabController.removeListener(_onTabChanged);
    _showBackToTopNotifier.dispose();
    _directScrollController.dispose();
    _channelScrollController.dispose();
    _notificationsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopHeader(
                theme,
                Curves.easeOutCubic.transform(_headerScrollFactor),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const PageScrollPhysics(),
                  children: [
                    _buildNotificationsList(theme),
                    _buildChatList(
                      theme,
                      _channelMessages,
                      '暂无频道消息',
                      controller: _channelScrollController,
                    ),
                    _buildChatList(
                      theme,
                      _directMessages,
                      '暂无私信消息',
                      controller: _directScrollController,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 98,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showBackToTopNotifier,
              builder: (context, visible, _) {
                return IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: visible ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      scale: visible ? 1 : 0.82,
                      child: FloatingActionButton.small(
                        heroTag: 'notifications_back_to_top_fab',
                        onPressed: visible ? _scrollActiveTabToTop : null,
                        child: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildRealtimeBanner(theme),
        ],
      ),
    );
  }
}
