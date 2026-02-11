import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/features/notifications/chat_detail_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

part 'notifications_page_view.dart';

enum _NotificationsMode { notifications, channels, directMessages }

extension on _NotificationsMode {
  String get label {
    switch (this) {
      case _NotificationsMode.notifications:
        return '\u901a\u77e5';
      case _NotificationsMode.channels:
        return '\u9891\u9053\u6d88\u606f';
      case _NotificationsMode.directMessages:
        return '\u76f4\u63a5\u6d88\u606f';
    }
  }
}

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

class _NotificationsPageState extends State<NotificationsPage> {
  static const String _labelNeedLogin =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';
  static const String _labelLoadFailed =
      '\u901a\u77e5\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  static const String _labelSessionExpired =
      '\u8be5\u8d26\u53f7\u767b\u5f55\u6001\u5df2\u5931\u6548\uff0c\u8bf7\u91cd\u65b0\u767b\u5f55';
  static const String _labelRetry = '\u91cd\u8bd5';
  static const String _labelNoNotifications = '\u6682\u65e0\u901a\u77e5';
  static const String _labelNoChannels = '\u6682\u65e0\u9891\u9053\u6d88\u606f';
  static const String _labelNoDirectMessages =
      '\u6682\u65e0\u76f4\u63a5\u6d88\u606f';
  static const String _labelNoMoreNotifications =
      '\u6ca1\u6709\u66f4\u591a\u901a\u77e5\u4e86';

  _NotificationsMode _mode = _NotificationsMode.notifications;
  final ScrollController _notificationsScrollController = ScrollController();
  List<RiverSideNotificationItem> _notifications =
      const <RiverSideNotificationItem>[];
  List<RiverSideChatChannelItem> _channelMessages =
      const <RiverSideChatChannelItem>[];
  List<RiverSideChatChannelItem> _directMessages =
      const <RiverSideChatChannelItem>[];
  String _nextNotificationsPath = '';
  int? _totalNotifications;
  bool _loading = true;
  bool _loadingMoreNotifications = false;
  int _requestSerial = 0;
  String? _error;
  String? _lastActiveUsername;
  RiverSideMessageBusPoller? _messageBusPoller;
  bool _hasRealtimeNotifications = false;

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

  @override
  void initState() {
    super.initState();
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
    _notificationsScrollController
      ..removeListener(_onNotificationsScroll)
      ..dispose();
    super.dispose();
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    final previous = _lastActiveUsername;
    if (current == previous) {
      return;
    }
    _lastActiveUsername = current;
    _messageBusPoller?.stop();
    _messageBusPoller = null;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMoreNotifications = false;
        _error = null;
        _notifications = const <RiverSideNotificationItem>[];
        _channelMessages = const <RiverSideChatChannelItem>[];
        _directMessages = const <RiverSideChatChannelItem>[];
        _nextNotificationsPath = '';
        _totalNotifications = null;
        _hasRealtimeNotifications = false;
      });
    }
    if (_notificationsScrollController.hasClients) {
      _notificationsScrollController.jumpTo(0);
    }
    _notifyUnreadCountChanged();
    _loadAll(clearExisting: true);
    _restartRealtimePolling();
  }

  void _onNotificationsScroll() {
    if (_mode != _NotificationsMode.notifications) {
      return;
    }
    if (_loading ||
        _loadingMoreNotifications ||
        _nextNotificationsPath.isEmpty) {
      return;
    }
    if (!_notificationsScrollController.hasClients) {
      return;
    }
    final position = _notificationsScrollController.position;
    if (position.pixels < position.maxScrollExtent - 260) {
      return;
    }
    _loadMoreNotifications();
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  Future<void> _loadAll({
    bool showLoading = true,
    bool clearExisting = false,
  }) async {
    final serial = ++_requestSerial;
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _labelNeedLogin;
        _notifications = const <RiverSideNotificationItem>[];
        _channelMessages = const <RiverSideChatChannelItem>[];
        _directMessages = const <RiverSideChatChannelItem>[];
        _nextNotificationsPath = '';
        _totalNotifications = null;
        _loadingMoreNotifications = false;
      });
      _notifyUnreadCountChanged();
      return;
    }

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
        if (clearExisting) {
          _notifications = const <RiverSideNotificationItem>[];
          _channelMessages = const <RiverSideChatChannelItem>[];
          _directMessages = const <RiverSideChatChannelItem>[];
          _nextNotificationsPath = '';
          _totalNotifications = null;
        }
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final results = await Future.wait<dynamic>([
        api.fetchNotificationsPage(cookieHeader: cookieHeader),
        api.fetchMyChatChannels(cookieHeader: cookieHeader),
      ]);
      if (!mounted || serial != _requestSerial) {
        return;
      }

      final notificationPage =
          results[0] as RiverSideNotificationPage? ??
          const RiverSideNotificationPage(
            items: <RiverSideNotificationItem>[],
            totalRows: null,
            seenNotificationId: null,
            loadMorePath: '',
          );
      final channels =
          results[1] as List<RiverSideChatChannelItem>? ??
          const <RiverSideChatChannelItem>[];

      setState(() {
        _loading = false;
        _error = null;
        _loadingMoreNotifications = false;
        _hasRealtimeNotifications = false;
        _notifications = notificationPage.items;
        _nextNotificationsPath = notificationPage.loadMorePath;
        _totalNotifications = notificationPage.totalRows;
        _channelMessages = channels
            .where((item) => !item.isDirectMessage)
            .toList(growable: false);
        _directMessages = channels
            .where((item) => item.isDirectMessage)
            .toList(growable: false);
      });
      _notifyUnreadCountChanged();
      _restartRealtimePolling();
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      final isExpired = error.message.toLowerCase().contains(
        'login session expired',
      );
      setState(() {
        _loading = false;
        _loadingMoreNotifications = false;
        _error = isExpired ? _labelSessionExpired : error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMoreNotifications = false;
        _error = _labelLoadFailed;
      });
    }
  }

  Future<void> _openNotificationTopic(RiverSideNotificationItem item) async {
    final topicId = item.topicId;
    if (topicId == null || topicId <= 0) {
      return;
    }

    if (!item.read) {
      var markedRemotely = false;
      final cookieHeader = _activeCookieHeader();
      if (cookieHeader != null && cookieHeader.trim().isNotEmpty) {
        try {
          await widget.dependencies.accountStore.riverSideApiClient
              .markNotificationsAsRead(
                cookieHeader: cookieHeader,
                notificationId: item.id,
              );
          markedRemotely = true;
        } on RiverSideApiException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message)));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('通知已读状态同步失败')));
          }
        }
      }

      if (mounted && markedRemotely) {
        setState(() {
          _notifications = _notifications
              .map((value) {
                if (value.id != item.id) {
                  return value;
                }
                return RiverSideNotificationItem(
                  id: value.id,
                  type: value.type,
                  read: true,
                  highPriority: value.highPriority,
                  createdAt: value.createdAt,
                  topicId: value.topicId,
                  postNumber: value.postNumber,
                  slug: value.slug,
                  title: value.title,
                  excerpt: value.excerpt,
                  username: value.username,
                  actionText: value.actionText,
                  badgeName: value.badgeName,
                  count: value.count,
                  avatarUrl: value.avatarUrl,
                );
              })
              .toList(growable: false);
        });
        _notifyUnreadCountChanged();
      }
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topicId,
        ),
      ),
    );
  }

  Future<void> _restartRealtimePolling() async {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return;
    }

    var userId =
        widget.dependencies.accountStore.activeRiverSideAccount?.userId;
    if (userId == null || userId <= 0) {
      try {
        final current = await widget
            .dependencies
            .accountStore
            .riverSideApiClient
            .fetchCurrentUserByCookie(cookieHeader: cookieHeader);
        userId = current.userId;
      } catch (_) {
        userId = null;
      }
    }

    if (!mounted || userId == null || userId <= 0) {
      return;
    }

    final channel = '/notification/$userId';
    final poller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookieHeader,
      channelLastIds: RiverSideMessageBusPoller.buildInitialChannels(<String>[
        channel,
      ]),
      onEvents: (events) {
        if (!mounted || events.isEmpty) {
          return;
        }
        final hasNewNotification = events.any(
          (event) => event.channel == channel,
        );
        if (!hasNewNotification || _hasRealtimeNotifications) {
          return;
        }
        setState(() {
          _hasRealtimeNotifications = true;
        });
      },
    );
    _messageBusPoller = poller;
    poller.start();
  }

  Future<void> _consumeRealtimeNotifications() async {
    if (_hasRealtimeNotifications) {
      setState(() {
        _hasRealtimeNotifications = false;
      });
    }
    await _loadAll(showLoading: false);
    _notifyUnreadCountChanged();
  }

  void _dismissRealtimeNotificationsHint() {
    if (!_hasRealtimeNotifications) {
      return;
    }
    setState(() {
      _hasRealtimeNotifications = false;
    });
  }

  Future<void> _loadMoreNotifications() async {
    final serial = _requestSerial;
    final usernameAtStart =
        widget.dependencies.accountStore.activeRiverSideUsername;
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return;
    }
    final path = _nextNotificationsPath.trim();
    if (path.isEmpty) {
      return;
    }

    setState(() {
      _loadingMoreNotifications = true;
    });

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final page = await api.fetchNotificationsPage(
        cookieHeader: cookieHeader,
        loadMorePath: path,
      );
      final currentUsername =
          widget.dependencies.accountStore.activeRiverSideUsername;
      if (!mounted ||
          serial != _requestSerial ||
          currentUsername != usernameAtStart) {
        return;
      }

      final mergedById = <int, RiverSideNotificationItem>{
        for (final item in _notifications) item.id: item,
      };
      for (final item in page.items) {
        mergedById[item.id] = item;
      }
      final merged = mergedById.values.toList(growable: false)
        ..sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });

      setState(() {
        _notifications = merged;
        _nextNotificationsPath = page.loadMorePath;
        _totalNotifications = page.totalRows ?? _totalNotifications;
        _loadingMoreNotifications = false;
      });
      _notifyUnreadCountChanged();
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingMoreNotifications = false;
      });
      final isExpired = error.message.toLowerCase().contains(
        'login session expired',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isExpired ? _labelSessionExpired : error.message),
        ),
      );
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingMoreNotifications = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_labelLoadFailed)));
    }
  }

  Future<void> _openChatDetail(RiverSideChatChannelItem channel) async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) =>
            ChatDetailPage(dependencies: widget.dependencies, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading &&
        _notifications.isEmpty &&
        _channelMessages.isEmpty &&
        _directMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null &&
        _notifications.isEmpty &&
        _channelMessages.isEmpty &&
        _directMessages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadAll, child: const Text(_labelRetry)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_NotificationsMode>(
                    segments: _NotificationsMode.values
                        .map(
                          (mode) => ButtonSegment<_NotificationsMode>(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: <_NotificationsMode>{_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        _mode = selection.first;
                      });
                    },
                  ),
                ),
              ),
            ),
            if (_mode == _NotificationsMode.notifications &&
                _totalNotifications != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '\u5171 $_totalNotifications \u6761\u901a\u77e5',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(child: _buildModeBody()),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              ignoring: !_hasRealtimeNotifications,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: _hasRealtimeNotifications
                    ? Offset.zero
                    : const Offset(0, 1.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hasRealtimeNotifications ? 1 : 0,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('有新通知，点击刷新')),
                          FilledButton.tonal(
                            onPressed: _consumeRealtimeNotifications,
                            child: const Text('刷新'),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: _dismissRealtimeNotificationsHint,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
