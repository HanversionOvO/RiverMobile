part of 'notifications_page.dart';

extension _NotificationsPageView on _NotificationsPageState {
  Widget _buildModeBody() {
    switch (_mode) {
      case _NotificationsMode.notifications:
        if (_notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _loadAll(showLoading: false),
            child: ListView(
              controller: _notificationsScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(
                  child: Text(_NotificationsPageState._labelNoNotifications),
                ),
              ],
            ),
          );
        }
        final showFooter =
            _loadingMoreNotifications || _nextNotificationsPath.isEmpty;
        return RefreshIndicator(
          onRefresh: () => _loadAll(showLoading: false),
          child: ListView.separated(
            controller: _notificationsScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            itemCount: _notifications.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= _notifications.length) {
                if (_loadingMoreNotifications) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _NotificationsPageState._labelNoMoreNotifications,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              }
              if (index == _notifications.length - 1 &&
                  !_loading &&
                  !_loadingMoreNotifications &&
                  _nextNotificationsPath.trim().isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      _loading ||
                      _loadingMoreNotifications ||
                      _mode != _NotificationsMode.notifications) {
                    return;
                  }
                  _loadMoreNotifications();
                });
              }
              final item = _notifications[index];
              final subtitleColor = Theme.of(
                context,
              ).colorScheme.onSurfaceVariant;
              final actionLine = item.actionText.isEmpty
                  ? item.excerpt
                  : item.actionText;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _openNotificationTopic(item),
                  leading: CircleAvatar(
                    backgroundImage: item.avatarUrl.isEmpty
                        ? null
                        : NetworkImage(item.avatarUrl),
                    child: item.avatarUrl.isEmpty
                        ? Icon(_notificationIcon(item.type))
                        : null,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: item.read
                        ? null
                        : const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (actionLine.isNotEmpty)
                        Text(
                          actionLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (item.excerpt.isNotEmpty && item.excerpt != actionLine)
                        Text(
                          item.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _notificationMeta(item),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                  trailing: item.read
                      ? (item.highPriority
                            ? const Icon(
                                Icons.priority_high,
                                size: 18,
                                color: Colors.orangeAccent,
                              )
                            : null)
                      : const Icon(Icons.circle, size: 10, color: Colors.blue),
                ),
              );
            },
          ),
        );
      case _NotificationsMode.channels:
        return _buildChatList(
          items: _channelMessages,
          emptyLabel: _NotificationsPageState._labelNoChannels,
        );
      case _NotificationsMode.directMessages:
        return _buildChatList(
          items: _directMessages,
          emptyLabel: _NotificationsPageState._labelNoDirectMessages,
        );
    }
  }

  Widget _buildChatList({
    required List<RiverSideChatChannelItem> items,
    required String emptyLabel,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadAll(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(child: Text(emptyLabel)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAll(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => _openChatDetail(item),
              leading: CircleAvatar(
                backgroundImage: item.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(item.avatarUrl),
                child: item.avatarUrl.isEmpty
                    ? Icon(
                        item.isDirectMessage
                            ? Icons.person_outline
                            : Icons.forum_outlined,
                      )
                    : null,
              ),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.lastMessage.isNotEmpty)
                    Text(
                      item.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.description.isNotEmpty && item.lastMessage.isEmpty)
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(item.lastMessageAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ),
              trailing: item.unreadCount > 0
                  ? CircleAvatar(
                      radius: 11,
                      child: Text(
                        item.unreadCount > 99
                            ? '99+'
                            : item.unreadCount.toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    )
                  : const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  String _notificationMeta(RiverSideNotificationItem item) {
    final parts = <String>[];
    parts.add(_notificationTypeLabel(item.type));
    if (item.postNumber != null && item.postNumber! > 0) {
      parts.add('#${item.postNumber}');
    }
    parts.add(_formatDateTime(item.createdAt));
    return parts.join(' \u00b7 ');
  }

  IconData _notificationIcon(int type) {
    switch (type) {
      case 1:
      case 18:
        return Icons.alternate_email;
      case 2:
      case 3:
      case 9:
      case 10:
      case 801:
        return Icons.forum_outlined;
      case 5:
        return Icons.favorite_border;
      case 6:
      case 7:
      case 8:
        return Icons.mail_outline;
      case 12:
      case 15:
        return Icons.workspace_premium_outlined;
      case 36:
        return Icons.campaign_outlined;
      case 800:
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _notificationTypeLabel(int type) {
    switch (type) {
      case 1:
        return '\u63d0\u53ca';
      case 2:
        return '\u56de\u590d';
      case 3:
        return '\u5f15\u7528';
      case 4:
        return '\u7f16\u8f91';
      case 5:
        return '\u70b9\u8d5e';
      case 6:
        return '\u79c1\u4fe1';
      case 9:
        return '\u53d1\u5e16';
      case 10:
        return '\u5173\u6ce8\u5206\u7c7b';
      case 12:
      case 15:
        return '\u5fbd\u7ae0';
      case 13:
      case 16:
        return '\u9080\u8bf7';
      case 14:
        return '\u94fe\u63a5';
      case 18:
        return '\u7ec4\u63d0\u53ca';
      case 36:
        return '\u7cfb\u7edf';
      case 800:
        return '\u5173\u6ce8';
      case 801:
        return '\u8ba2\u9605';
      default:
        return '\u901a\u77e5';
    }
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
