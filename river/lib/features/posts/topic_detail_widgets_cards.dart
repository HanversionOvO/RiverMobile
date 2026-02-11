part of 'topic_detail_page.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _MainPostCard extends StatefulWidget {
  const _MainPostCard({
    super.key,
    required this.detail,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    required this.isReacting,
    required this.onReactPressed,
    required this.onReplyPressed,
    required this.onReactionStatusPressed,
    required this.onAuthorTap,
  });

  final RiverSideTopicDetail detail;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final bool isReacting;
  final ValueChanged<RiverSideTopicPostDetail> onReactPressed;
  final ValueChanged<RiverSideTopicPostDetail> onReplyPressed;
  final void Function(RiverSideTopicPostDetail post, String reactionId)
  onReactionStatusPressed;
  final ValueChanged<RiverSideTopicPostDetail> onAuthorTap;

  @override
  State<_MainPostCard> createState() => _MainPostCardState();
}

class _MainPostCardState extends State<_MainPostCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final post = widget.detail.mainPost;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostAuthorHeader(
              post: post,
              onTap: () => widget.onAuthorTap(post),
              heroTagAvatar: _topicPostAuthorAvatarHeroTag(post),
              heroTagName: _topicPostAuthorNameHeroTag(post),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaItem(
                  icon: Icons.schedule_outlined,
                  text: _formatDateTime(post.createdAt),
                  color: subtitleColor,
                ),
                _MetaItem(
                  icon: Icons.edit_note,
                  text: '\u7f16\u8f91 ${post.editCount}',
                  color: subtitleColor,
                ),
                _MetaItem(
                  icon: Icons.visibility_outlined,
                  text: '\u6d4f\u89c8 ${widget.detail.viewCount}',
                  color: subtitleColor,
                ),
                _MetaItem(
                  icon: Icons.thumb_up_alt_outlined,
                  text: '\u70b9\u8d5e ${post.likeCount}',
                  color: subtitleColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PostContent(
              markdown: post.contentMarkdown,
              topicId: post.topicId,
              cookieHeader: widget.cookieHeader,
              emojiUrls: widget.emojiUrls,
              onQuoteTap: widget.onQuoteTap,
            ),
            const SizedBox(height: 12),
            _PostReactionBar(
              post: post,
              reacting: widget.isReacting,
              onReactPressed: () => widget.onReactPressed(post),
              onReplyPressed: () => widget.onReplyPressed(post),
              onReactionStatusPressed: (reactionId) {
                widget.onReactionStatusPressed(post, reactionId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    super.key,
    required this.post,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    required this.isReacting,
    required this.onReactPressed,
    required this.onReplyPressed,
    required this.heroTag,
    this.onTap,
    this.onLongPress,
    required this.onReactionStatusPressed,
    required this.onAuthorTap,
  });

  final RiverSideTopicPostDetail post;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final bool isReacting;
  final ValueChanged<RiverSideTopicPostDetail> onReactPressed;
  final ValueChanged<RiverSideTopicPostDetail> onReplyPressed;
  final String heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(RiverSideTopicPostDetail post, String reactionId)
  onReactionStatusPressed;
  final ValueChanged<RiverSideTopicPostDetail> onAuthorTap;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder: _commentCardHeroShuttleBuilder,
      transitionOnUserGestures: true,
      child: HeroMode(
        enabled: false,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostAuthorHeader(
                    post: widget.post,
                    onTap: () => widget.onAuthorTap(widget.post),
                    heroTagAvatar: _topicPostAuthorAvatarHeroTag(widget.post),
                    heroTagName: _topicPostAuthorNameHeroTag(widget.post),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MetaItem(
                        icon: Icons.schedule_outlined,
                        text: _formatDateTime(widget.post.createdAt),
                        color: subtitleColor,
                      ),
                      _MetaItem(
                        icon: Icons.thumb_up_alt_outlined,
                        text: '\u70b9\u8d5e ${widget.post.likeCount}',
                        color: subtitleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PostContent(
                    markdown: widget.post.contentMarkdown,
                    topicId: widget.post.topicId,
                    cookieHeader: widget.cookieHeader,
                    emojiUrls: widget.emojiUrls,
                    onQuoteTap: widget.onQuoteTap,
                    enableImageHero: false,
                  ),
                  const SizedBox(height: 10),
                  _PostReactionBar(
                    post: widget.post,
                    reacting: widget.isReacting,
                    onReactPressed: () => widget.onReactPressed(widget.post),
                    onReplyPressed: () => widget.onReplyPressed(widget.post),
                    onReactionStatusPressed: (reactionId) {
                      widget.onReactionStatusPressed(widget.post, reactionId);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentDetailPostCard extends StatelessWidget {
  const _CommentDetailPostCard({
    required this.post,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    required this.onReplyPressed,
    required this.onAuthorTap,
    this.onLongPress,
    this.heroTag,
  });

  final RiverSideTopicPostDetail post;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final ValueChanged<RiverSideTopicPostDetail> onReplyPressed;
  final ValueChanged<RiverSideTopicPostDetail> onAuthorTap;
  final VoidCallback? onLongPress;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAuthorHeader(
                post: post,
                onTap: () => onAuthorTap(post),
                heroTagAvatar: _topicPostAuthorAvatarHeroTag(post),
                heroTagName: _topicPostAuthorNameHeroTag(post),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _MetaItem(
                    icon: Icons.schedule_outlined,
                    text: _formatDateTime(post.createdAt),
                    color: subtitleColor,
                  ),
                  _MetaItem(
                    icon: Icons.thumb_up_alt_outlined,
                    text: '\u70b9\u8d5e ${post.likeCount}',
                    color: subtitleColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _PostContent(
                markdown: post.contentMarkdown,
                topicId: post.topicId,
                cookieHeader: cookieHeader,
                emojiUrls: emojiUrls,
                onQuoteTap: onQuoteTap,
                enableImageHero: false,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => onReplyPressed(post),
                  icon: const Icon(Icons.reply_outlined, size: 18),
                  label: const Text(_TopicDetailPageState._labelReply),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (heroTag == null || heroTag!.isEmpty) {
      return card;
    }
    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: _commentCardHeroShuttleBuilder,
      transitionOnUserGestures: true,
      child: HeroMode(enabled: false, child: card),
    );
  }
}

class _PostReactionBar extends StatelessWidget {
  const _PostReactionBar({
    required this.post,
    required this.reacting,
    required this.onReactPressed,
    required this.onReplyPressed,
    required this.onReactionStatusPressed,
  });

  final RiverSideTopicPostDetail post;
  final bool reacting;
  final VoidCallback onReactPressed;
  final VoidCallback onReplyPressed;
  final ValueChanged<String> onReactionStatusPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reactions = post.reactions.where((item) => item.count > 0).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onReplyPressed,
          icon: const Icon(Icons.reply_outlined, size: 18),
          label: const Text(_TopicDetailPageState._labelReply),
        ),
        OutlinedButton.icon(
          onPressed: reacting ? null : onReactPressed,
          icon: reacting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_reaction_outlined, size: 18),
          label: const Text(_TopicDetailPageState._labelReact),
        ),
        ...reactions.map((reaction) {
          final selected = post.currentUserReaction?.id == reaction.id;
          return ActionChip(
            avatar: Text(
              _reactionEmoji(reaction.id),
              style: const TextStyle(fontSize: 14),
            ),
            label: Text('${reaction.count}'),
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            backgroundColor: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            onPressed: () => onReactionStatusPressed(reaction.id),
          );
        }),
      ],
    );
  }
}
