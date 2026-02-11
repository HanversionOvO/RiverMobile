part of 'topic_detail_page.dart';

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({required this.post});

  final RiverSideTopicPostDetail post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final onlineState = _onlineStateText(post.isOnline);
    final onlineColor = _onlineStateColor(post.isOnline, context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorDisplayName,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 9, color: onlineColor),
                      const SizedBox(width: 4),
                      Text(
                        onlineState,
                        style: textTheme.bodySmall?.copyWith(
                          color: onlineColor,
                        ),
                      ),
                    ],
                  ),
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
      ],
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
