part of 'notifications_page.dart';

extension _NotificationsPageView on _NotificationsPageState {
  Widget _buildTopHeader(ThemeData theme, double t) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapse = t.clamp(0.0, 1.0);
    final unreadNotifications = _notifications
        .where((item) => !item.read)
        .length;
    final subtitle = unreadNotifications > 0
        ? '未读 $unreadNotifications 条'
        : '全部已读';
    const titleSize = 21.0;
    final subtitleVisibility = (1.0 - collapse).clamp(0.0, 1.0);
    final borderAlpha = lerpDouble(0.18, 0.26, collapse)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(
              alpha: lerpDouble(0.90, 0.96, t)!,
            ),
            theme.colorScheme.surfaceContainerLowest.withValues(
              alpha: lerpDouble(0.82, 0.92, t)!,
            ),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: borderAlpha,
            ),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: lerpDouble(7, 11, t)!,
            sigmaY: lerpDouble(7, 11, t)!,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topInset + lerpDouble(9, 8, collapse)!,
              bottom: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 64),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '通知',
                                  textAlign: TextAlign.left,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    fontSize: titleSize,
                                  ),
                                ),
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    heightFactor: subtitleVisibility,
                                    child: Opacity(
                                      opacity: subtitleVisibility,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            subtitle,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            onPressed: unreadNotifications > 0
                                ? _markAllNotificationItemsAsRead
                                : null,
                            tooltip: '全部已读',
                            icon: const Icon(Icons.done_all_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSegmentedTabBar(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
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

  Widget _buildRefreshPlaceholder({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList(ThemeData theme) {
    if (_loading && _notifications.isEmpty) {
      return _buildRefreshPlaceholder(
        onRefresh: _refreshCurrentTab,
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null && _notifications.isEmpty) {
      return _buildRefreshPlaceholder(
        onRefresh: _refreshCurrentTab,
        child: _buildErrorView(),
      );
    }

    if (_notifications.isEmpty) {
      return _buildRefreshPlaceholder(
        onRefresh: _refreshCurrentTab,
        child: _buildEmptyView('暂无通知', Icons.notifications_none_rounded),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView.separated(
        controller: _notificationsScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
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
    // Resolve visual style by notification type.
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
        iconBgColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
    }

    final isUnread = !item.read;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              // Unread indicator strip.
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
                    // 澶村儚涓庤鏍?
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
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
                                  color: typeColor.withValues(alpha: 0.1),
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
                    // 鍐呭
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
                                        text: '  ${item.actionText}',
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
                          if (item.title.isNotEmpty)
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.excerpt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.excerpt.replaceAll('\n', ' '),
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
    String emptyMsg, {
    required ScrollController controller,
  }) {
    if (_loading && items.isEmpty) {
      return _buildRefreshPlaceholder(
        onRefresh: _refreshCurrentTab,
        child: const CircularProgressIndicator(),
      );
    }

    if (items.isEmpty) {
      return _buildRefreshPlaceholder(
        onRefresh: _refreshCurrentTab,
        child: _buildEmptyView(emptyMsg, Icons.chat_bubble_outline_rounded),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView.separated(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final title = item.name.trim().isNotEmpty
              ? item.name.trim()
              : (item.isDirectMessage ? '私信 #${item.id}' : '频道 #${item.id}');
          final subtitle = item.lastMessage.trim().isNotEmpty
              ? item.lastMessage.trim().replaceAll('\n', ' ')
              : (item.description.trim().isNotEmpty
                    ? item.description.trim().replaceAll('\n', ' ')
                    : '暂无最新消息');
          final isUnread = item.unreadCount > 0;
          final directAvatar = item.avatarUrl.trim();
          final isDeletingDirect = _deletingDirectMessageIds.contains(item.id);
          final card = Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              onTap: isDeletingDirect ? null : () => _openChatDetail(item),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: item.isDirectMessage
                    ? CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        backgroundImage: directAvatar.isNotEmpty
                            ? NetworkImage(directAvatar)
                            : null,
                        child: directAvatar.isEmpty
                            ? Icon(
                                Icons.person_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tag_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
              ),
              title: Row(
                children: [
                  if (isUnread) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isUnread
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnread
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isDeletingDirect
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : item.unreadCount > 0
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
          final slidableCard = Padding(
            padding: const EdgeInsets.only(right: 8),
            child: card,
          );
          final canSwipeDelete =
              item.isDirectMessage && item.canDeleteSelf && !isDeletingDirect;
          if (!item.isDirectMessage) {
            return card;
          }
          return Slidable(
            key: ValueKey<String>('direct-channel-${item.id}'),
            enabled: canSwipeDelete,
            closeOnScroll: true,
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.30,
              children: [
                CustomSlidableAction(
                  autoClose: true,
                  borderRadius: BorderRadius.circular(16),
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  onPressed: (_) async {
                    if (!canSwipeDelete) {
                      return;
                    }
                    final confirmed = await _confirmDeleteDirectMessage(item);
                    if (!confirmed) {
                      return;
                    }
                    await _deleteDirectMessageChannel(item);
                  },
                  child: isDeletingDirect
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded),
                            SizedBox(height: 4),
                            Text(
                              '删除',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            child: slidableCard,
          );
        },
      ),
    );
  }

  Widget _buildRealtimeBanner(ThemeData theme) {
    if (!_showNotificationsRealtimeRefreshBanner) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.18),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: _hasRealtimeNotifications
              ? Material(
                  key: const ValueKey<String>('notifications-realtime-hint'),
                  color: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.38,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _consumeRealtimeNotifications,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                10,
                                10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '有新通知，点击查看',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _setState(
                            () => _hasRealtimeNotifications = false,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
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
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          Text(_error ?? _NotificationsPageState._labelLoadFailed),
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
