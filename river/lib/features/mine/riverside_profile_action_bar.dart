import 'package:flutter/material.dart';

class RiverSideProfileActionBar extends StatelessWidget {
  const RiverSideProfileActionBar({
    super.key,
    required this.showFollowButton,
    required this.showMessageButton,
    required this.isFollowing,
    required this.followLoading,
    required this.messageLoading,
    required this.onToggleFollow,
    required this.onStartMessage,
    this.compact = false,
    this.messageIconOnly = false,
  });

  final bool showFollowButton;
  final bool showMessageButton;
  final bool isFollowing;
  final bool followLoading;
  final bool messageLoading;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onStartMessage;
  final bool compact;
  final bool messageIconOnly;

  @override
  Widget build(BuildContext context) {
    if (!showFollowButton && !showMessageButton) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFollowButton) _buildFollowButton(theme, compact: true),
          if (showFollowButton && showMessageButton) const SizedBox(width: 8),
          if (showMessageButton)
            _buildMessageButton(
              theme,
              compact: true,
              iconOnly: messageIconOnly,
            ),
        ],
      );
    }

    return Row(
      children: [
        if (showFollowButton) Expanded(child: _buildFollowButton(theme)),
        if (showFollowButton && showMessageButton) const SizedBox(width: 10),
        if (showMessageButton) Expanded(child: _buildMessageButton(theme)),
      ],
    );
  }

  Widget _buildFollowButton(ThemeData theme, {bool compact = false}) {
    final radius = compact ? 10.0 : 14.0;
    final minHeight = compact ? 32.0 : 42.0;
    final iconSize = compact ? 16.0 : 18.0;

    return isFollowing
        ? FilledButton.tonalIcon(
            onPressed: followLoading ? null : onToggleFollow,
            icon: followLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.check_rounded, size: iconSize),
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text('已关注', key: const ValueKey<String>('following')),
            ),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, minHeight),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
            ),
          )
        : FilledButton.icon(
            onPressed: followLoading ? null : onToggleFollow,
            icon: followLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Icon(Icons.person_add_alt_1_rounded, size: iconSize),
            label: const Text('关注'),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, minHeight),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
            ),
          );
  }

  Widget _buildMessageButton(
    ThemeData theme, {
    bool compact = false,
    bool iconOnly = false,
  }) {
    final radius = compact ? 10.0 : 14.0;
    final minHeight = compact ? 32.0 : 42.0;
    final icon = messageLoading
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(Icons.mark_chat_unread_rounded, size: compact ? 17 : 18);

    if (iconOnly) {
      return FilledButton.tonal(
        onPressed: messageLoading ? null : onStartMessage,
        style: FilledButton.styleFrom(
          minimumSize: Size(minHeight, minHeight),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
        ),
        child: icon,
      );
    }

    return FilledButton.tonalIcon(
      onPressed: messageLoading ? null : onStartMessage,
      icon: icon,
      label: const Text('开始私信'),
      style: FilledButton.styleFrom(
        minimumSize: Size(0, minHeight),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      ),
    );
  }
}
