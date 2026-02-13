part of 'notifications_page.dart';

extension _NotificationsPageActions on _NotificationsPageState {
  bool get _showNotificationsRealtimeRefreshBanner {
    return widget
        .dependencies
        .settingsController
        .showNotificationsRealtimeRefreshBanner;
  }

  void _onRefreshBannerSettingsChanged() {
    if (!mounted) {
      return;
    }
    if (!_showNotificationsRealtimeRefreshBanner && _hasRealtimeNotifications) {
      _setState(() {
        _hasRealtimeNotifications = false;
      });
      return;
    }
    _setState(() {});
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
    if (current == _lastActiveUsername) {
      return;
    }
    _lastActiveUsername = current;
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    if (mounted) {
      _setState(() {
        _loading = true;
        _notifications = [];
        _channelMessages = [];
        _directMessages = [];
        _deletingDirectMessageIds.clear();
        _error = null;
        _hasRealtimeNotifications = false;
      });
    }
    _loadAll(clearExisting: true);
  }

  void _onNotificationsScroll() {
    if (_tabController.index != 0) {
      return;
    }
    _syncBackToTopVisibility();
    if (_loading ||
        _loadingMoreNotifications ||
        _nextNotificationsPath.isEmpty) {
      return;
    }
    if (!_notificationsScrollController.hasClients) {
      return;
    }
    final position = _notificationsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }

  void _onChannelScroll() {
    if (_tabController.index == 1) {
      _syncBackToTopVisibility();
    }
  }

  void _onDirectScroll() {
    if (_tabController.index == 2) {
      _syncBackToTopVisibility();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    if (mounted) {
      _setState(() {
        // Trigger rebuild to update tab dependent UI states.
      });
    }
    _syncBackToTopVisibility();
  }

  ScrollController? _activeScrollController() {
    switch (_tabController.index) {
      case 0:
        return _notificationsScrollController;
      case 1:
        return _channelScrollController;
      case 2:
        return _directScrollController;
    }
    return null;
  }

  void _syncBackToTopVisibility() {
    final controller = _activeScrollController();
    final currentOffset = controller != null && controller.hasClients
        ? controller.position.pixels
        : 0.0;
    final shouldShow = currentOffset >= 360;
    final nextHeaderFactor = (currentOffset / 96).clamp(0.0, 1.0);
    if ((_headerScrollFactor - nextHeaderFactor).abs() >= 0.01 && mounted) {
      _setState(() {
        _headerScrollFactor = nextHeaderFactor;
      });
    }
    if (_showBackToTopNotifier.value != shouldShow) {
      _showBackToTopNotifier.value = shouldShow;
    }
  }

  Future<void> _scrollActiveTabToTop() async {
    final controller = _activeScrollController();
    if (controller == null || !controller.hasClients) {
      return;
    }
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _syncBackToTopVisibility();
  }

  Future<void> _refreshCurrentTab() async {
    await _loadAll(showLoading: false);
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
      _setState(() {
        _loading = false;
        _error = _NotificationsPageState._labelNeedLogin;
        if (clearExisting) {
          _notifications = [];
          _channelMessages = [];
          _directMessages = [];
          _deletingDirectMessageIds.clear();
        }
      });
      _notifyUnreadCountChanged();
      return;
    }

    if (showLoading) {
      _setState(() {
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

      if (!mounted || serial != _requestSerial) {
        return;
      }

      final notificationPage = results[0] as RiverSideNotificationPage;
      final channels = results[1] as List<RiverSideChatChannelItem>;

      _setState(() {
        _loading = false;
        _error = null;
        _hasRealtimeNotifications = false;
        _notifications = notificationPage.items;
        _nextNotificationsPath = notificationPage.loadMorePath;
        _channelMessages = channels
            .where((item) => !item.isDirectMessage)
            .toList();
        _directMessages = channels
            .where((item) => item.isDirectMessage)
            .toList();
        _deletingDirectMessageIds.removeWhere(
          (id) => !_directMessages.any((item) => item.id == id),
        );
      });

      _notifyUnreadCountChanged();
      _restartRealtimePolling();
    } catch (e) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _setState(() {
        _loading = false;
        _error =
            e is RiverSideApiException && e.message.contains('session expired')
            ? _NotificationsPageState._labelSessionExpired
            : _NotificationsPageState._labelLoadFailed;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_nextNotificationsPath.isEmpty) {
      return;
    }
    _setState(() => _loadingMoreNotifications = true);

    try {
      final cookieHeader = _activeCookieHeader();
      if (cookieHeader == null) {
        return;
      }

      final api = widget.dependencies.accountStore.riverSideApiClient;
      final page = await api.fetchNotificationsPage(
        cookieHeader: cookieHeader,
        loadMorePath: _nextNotificationsPath,
      );

      if (!mounted) {
        return;
      }

      _setState(() {
        final existingIds = _notifications.map((e) => e.id).toSet();
        final newItems = page.items.where((e) => !existingIds.contains(e.id));
        _notifications = [..._notifications, ...newItems];
        _nextNotificationsPath = page.loadMorePath;
        _loadingMoreNotifications = false;
      });
    } catch (_) {
      if (mounted) {
        _setState(() => _loadingMoreNotifications = false);
      }
    }
  }

  Future<void> _openNotificationTopic(RiverSideNotificationItem item) async {
    if (item.topicId == null || item.topicId! <= 0) {
      return;
    }
    if (!item.read) {
      _setState(() {
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
    if (!mounted) {
      return;
    }
    await _loadAll(showLoading: false);
  }

  Future<bool> _confirmDeleteDirectMessage(
    RiverSideChatChannelItem item,
  ) async {
    final title = item.name.trim().isNotEmpty
        ? item.name.trim()
        : '私信 #${item.id}';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除私信'),
          content: Text('是否删除与“$title”的私信会话？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _deleteDirectMessageChannel(
    RiverSideChatChannelItem item,
  ) async {
    if (_deletingDirectMessageIds.contains(item.id)) {
      return false;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_NotificationsPageState._labelNeedLogin),
          ),
        );
      }
      return false;
    }

    _setState(() {
      _deletingDirectMessageIds.add(item.id);
    });

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .deleteDirectMessageChannel(channelId: item.id, cookieHeader: cookie);
      if (!mounted) {
        return false;
      }
      _setState(() {
        _directMessages = _directMessages
            .where((channel) => channel.id != item.id)
            .toList(growable: false);
        _deletingDirectMessageIds.remove(item.id);
      });
      _notifyUnreadCountChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('私信已删除')));
      return true;
    } on RiverSideApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除私信失败，请稍后重试')));
      }
      return false;
    } finally {
      if (mounted) {
        _setState(() {
          _deletingDirectMessageIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _consumeRealtimeNotifications() async {
    _setState(() => _hasRealtimeNotifications = false);
    await _loadAll(showLoading: false);

    if (_notificationsScrollController.hasClients) {
      _notificationsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  Future<void> _markAllNotificationItemsAsRead() async {
    final unreadCount = _notifications.where((item) => !item.read).length;
    if (unreadCount <= 0) {
      return;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_NotificationsPageState._labelNeedLogin),
          ),
        );
      }
      return;
    }

    final previous = List<RiverSideNotificationItem>.from(_notifications);
    _setState(() {
      _notifications = _notifications
          .map(
            (item) => item.read
                ? item
                : RiverSideNotificationItem(
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
                  ),
          )
          .toList(growable: false);
    });
    _notifyUnreadCountChanged();

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .markNotificationsAsRead(cookieHeader: cookie);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清除通知未读')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setState(() {
        _notifications = previous;
      });
      _notifyUnreadCountChanged();
      final message = error is RiverSideApiException
          ? error.message
          : '清除未读失败，请稍后重试';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _restartRealtimePolling() async {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookie = _activeCookieHeader();
    if (cookie == null) {
      return;
    }

    final userId = await _resolvePollingUserId(cookie: cookie);
    if (!mounted || userId == null) {
      return;
    }

    final channel = '/notification/$userId';
    _messageBusPoller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookie,
      channelLastIds: RiverSideMessageBusPoller.buildInitialChannels([channel]),
      onEvents: (events) {
        if (!mounted) {
          return;
        }
        if (events.any((e) => e.channel == channel)) {
          if (!_showNotificationsRealtimeRefreshBanner) {
            return;
          }
          _setState(() => _hasRealtimeNotifications = true);
        }
      },
    );
    _messageBusPoller?.start();
  }

  Future<int?> _resolvePollingUserId({required String cookie}) async {
    final account = widget.dependencies.accountStore.activeRiverSideAccount;
    final currentId = account?.userId;
    if (currentId != null && currentId > 0) {
      return currentId;
    }

    final activeUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    if (activeUsername == null || activeUsername.isEmpty) {
      return null;
    }

    try {
      final profile = await widget.dependencies.accountStore.riverSideApiClient
          .fetchCurrentUserByCookie(
            cookieHeader: cookie,
            fallbackLogin: activeUsername,
          );
      await widget.dependencies.accountStore.upsertRiverSideAccount(profile);
      final refreshedId = profile.userId;
      if (refreshedId != null && refreshedId > 0) {
        return refreshedId;
      }
    } catch (_) {
      // Ignore and keep polling disabled when user ID cannot be resolved.
    }

    return null;
  }
}
