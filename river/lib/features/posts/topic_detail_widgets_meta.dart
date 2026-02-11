part of 'topic_detail_page.dart';

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({
    required this.post,
    this.onTap,
    this.heroTagAvatar,
    this.heroTagName,
    this.enableHero = true,
    this.trailing,
  });

  final RiverSideTopicPostDetail post;
  final VoidCallback? onTap;
  final String? heroTagAvatar;
  final String? heroTagName;
  final bool enableHero;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final onlineColor = _onlineStateColor(post.isOnline, context);

    final avatar = Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: post.authorAvatarUrl.isEmpty
              ? null
              : NetworkImage(post.authorAvatarUrl),
          child: post.authorAvatarUrl.isEmpty
              ? const Icon(Icons.person_outline)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: onlineColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
    final avatarWidget =
        !enableHero || heroTagAvatar == null || heroTagAvatar!.isEmpty
        ? avatar
        : Hero(tag: heroTagAvatar!, child: avatar);

    final displayName = Text(
      post.authorDisplayName,
      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final displayNameWidget =
        !enableHero || heroTagName == null || heroTagName!.isEmpty
        ? displayName
        : Hero(
            tag: heroTagName!,
            child: Material(color: Colors.transparent, child: displayName),
          );

    final child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 頭像 + 在線狀態指示器
        avatarWidget,
        const SizedBox(width: 10),

        // 2. 用戶信息列
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              displayNameWidget,
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 移除了單獨的在線狀態文字行，僅保留頭銜和用戶名
                  if (post.authorTitle.isNotEmpty)
                    Text(
                      post.authorTitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  Text(
                    '@${post.authorUsername}',
                    style: textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (trailing case final Widget trailingWidget) ...[
          const SizedBox(width: 8),
          trailingWidget,
        ],
      ],
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
