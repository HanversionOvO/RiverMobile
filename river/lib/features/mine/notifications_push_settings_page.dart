import 'package:flutter/material.dart';
import 'package:river/app/app_settings_controller.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

class NotificationsPushSettingsPage extends StatelessWidget {
  const NotificationsPushSettingsPage({
    super.key,
    required this.settingsController,
  });

  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MineSettingsAppBar(
        title: '通知与推送',
        subtitle: '横幅提醒与刷新行为',
        icon: Icons.notifications_active_outlined,
        heroTagPrefix: 'mine_settings_notifications_push',
      ),
      body: AnimatedBuilder(
        animation: settingsController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _SettingsSection(
                title: '实时刷新横幅',
                subtitle: '控制各页面“有新内容，点击刷新”提示',
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.newspaper_rounded,
                      title: '帖子页新帖子横幅',
                      subtitle: '控制“有新帖子，点击刷新”是否显示',
                      value: settingsController.showPostsRealtimeRefreshBanner,
                      onChanged: settingsController
                          .updateShowPostsRealtimeRefreshBanner,
                    ),
                    const SizedBox(height: 8),
                    _SwitchTile(
                      icon: Icons.notifications_rounded,
                      title: '通知页新消息横幅',
                      subtitle: '控制“收到新消息，点击刷新”是否显示',
                      value: settingsController
                          .showNotificationsRealtimeRefreshBanner,
                      onChanged: settingsController
                          .updateShowNotificationsRealtimeRefreshBanner,
                    ),
                    const SizedBox(height: 8),
                    _SwitchTile(
                      icon: Icons.chat_bubble_rounded,
                      title: '帖子详情新评论横幅',
                      subtitle: '控制“有新评论，点击刷新”是否显示',
                      value: settingsController
                          .showTopicCommentsRealtimeRefreshBanner,
                      onChanged: settingsController
                          .updateShowTopicCommentsRealtimeRefreshBanner,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: value
            ? selectedColor.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? selectedColor.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: value
                ? selectedColor.withValues(alpha: 0.16)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: value ? selectedColor : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: value ? selectedColor : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
