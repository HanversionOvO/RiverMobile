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
          if (trailing case final Widget trailingWidget) trailingWidget,
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
    this.authorAvatarHeroTag,
    this.authorNameHeroTag,
    this.bodyRevealAnimation,
    this.pendingHeroReactionId,
    this.reactionPulseToken = 0,
    this.showReplyAction = true,
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
  final String? authorAvatarHeroTag;
  final String? authorNameHeroTag;
  final Animation<double>? bodyRevealAnimation;
  final String? pendingHeroReactionId;
  final int reactionPulseToken;
  final bool showReplyAction;

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
    final theme = Theme.of(context);
    final post = widget.detail.mainPost;
    final subtitleColor = theme.colorScheme.onSurfaceVariant;
    final bodySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          pendingHeroReactionId: widget.pendingHeroReactionId,
          pulseToken: widget.reactionPulseToken,
          showReplyAction: widget.showReplyAction,
        ),
      ],
    );
    final revealAnimation = widget.bodyRevealAnimation;
    final revealedBody = revealAnimation == null
        ? bodySection
        : FadeTransition(
            opacity: revealAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(revealAnimation),
              child: bodySection,
            ),
          );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAuthorHeader(
                post: post,
                onTap: () => widget.onAuthorTap(post),
                heroTagAvatar:
                    widget.authorAvatarHeroTag ??
                    _topicPostAuthorAvatarHeroTag(post),
                heroTagName:
                    widget.authorNameHeroTag ??
                    _topicPostAuthorNameHeroTag(post),
              ),
              const SizedBox(height: 10),
              revealedBody,
            ],
          ),
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
    this.pendingHeroReactionId,
    this.reactionPulseToken = 0,
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
  final String? pendingHeroReactionId;
  final int reactionPulseToken;

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
    final hasReactionStatus = widget.post.reactions.any(
      (item) => item.count > 0,
    );

    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder: _commentCardHeroShuttleBuilder,
      transitionOnUserGestures: true,
      child: HeroMode(
        enabled: false,
        child: Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostAuthorHeader(
                    post: widget.post,
                    onTap: () => widget.onAuthorTap(widget.post),
                    heroTagAvatar: _topicPostAuthorAvatarHeroTag(widget.post),
                    heroTagName: _topicPostAuthorNameHeroTag(widget.post),
                    enableHero: false,
                    trailing: _CommentInlineActions(
                      reacting: widget.isReacting,
                      onReplyPressed: () => widget.onReplyPressed(widget.post),
                      onReactPressed: () => widget.onReactPressed(widget.post),
                    ),
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
                  if (hasReactionStatus) ...[
                    const SizedBox(height: 10),
                    _PostReactionBar(
                      post: widget.post,
                      reacting: widget.isReacting,
                      onReactPressed: () => widget.onReactPressed(widget.post),
                      onReplyPressed: () => widget.onReplyPressed(widget.post),
                      onReactionStatusPressed: (reactionId) {
                        widget.onReactionStatusPressed(widget.post, reactionId);
                      },
                      pendingHeroReactionId: widget.pendingHeroReactionId,
                      pulseToken: widget.reactionPulseToken,
                      enableReactionHero: false,
                      showPrimaryActions: false,
                    ),
                  ],
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
    required this.onReactPressed,
    required this.onReactionStatusPressed,
    required this.reacting,
    required this.onAuthorTap,
    this.onLongPress,
    this.heroTag,
    this.pendingHeroReactionId,
    this.reactionPulseToken = 0,
  });

  final RiverSideTopicPostDetail post;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final ValueChanged<RiverSideTopicPostDetail> onReplyPressed;
  final ValueChanged<RiverSideTopicPostDetail> onReactPressed;
  final void Function(RiverSideTopicPostDetail post, String reactionId)
  onReactionStatusPressed;
  final bool reacting;
  final ValueChanged<RiverSideTopicPostDetail> onAuthorTap;
  final VoidCallback? onLongPress;
  final String? heroTag;
  final String? pendingHeroReactionId;
  final int reactionPulseToken;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final hasReactionStatus = post.reactions.any((item) => item.count > 0);
    final disableInnerHero = heroTag != null && heroTag!.isNotEmpty;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAuthorHeader(
                post: post,
                onTap: () => onAuthorTap(post),
                heroTagAvatar: _topicPostAuthorAvatarHeroTag(post),
                heroTagName: _topicPostAuthorNameHeroTag(post),
                enableHero: !disableInnerHero,
                trailing: _CommentInlineActions(
                  reacting: reacting,
                  onReplyPressed: () => onReplyPressed(post),
                  onReactPressed: () => onReactPressed(post),
                ),
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
              if (hasReactionStatus) ...[
                const SizedBox(height: 10),
                _PostReactionBar(
                  post: post,
                  reacting: reacting,
                  onReactPressed: () => onReactPressed(post),
                  onReplyPressed: () => onReplyPressed(post),
                  onReactionStatusPressed: (reactionId) {
                    onReactionStatusPressed(post, reactionId);
                  },
                  pendingHeroReactionId: pendingHeroReactionId,
                  pulseToken: reactionPulseToken,
                  enableReactionHero: !disableInnerHero,
                  showPrimaryActions: false,
                ),
              ],
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
    this.pendingHeroReactionId,
    this.pulseToken = 0,
    this.enableReactionHero = true,
    this.showPrimaryActions = true,
    this.showReplyAction = true,
  });

  final RiverSideTopicPostDetail post;
  final bool reacting;
  final VoidCallback onReactPressed;
  final VoidCallback onReplyPressed;
  final ValueChanged<String> onReactionStatusPressed;
  final String? pendingHeroReactionId;
  final int pulseToken;
  final bool enableReactionHero;
  final bool showPrimaryActions;
  final bool showReplyAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reactions = post.reactions.where((item) => item.count > 0).toList();
    final pendingId = pendingHeroReactionId;
    final hasPending =
        pendingId != null &&
        pendingId.isNotEmpty &&
        reactions.every((item) => item.id != pendingId);
    final actionBg = theme.colorScheme.surfaceContainerHighest;
    final actionBorder = theme.colorScheme.outlineVariant.withOpacity(0.55);
    final actionFg = theme.colorScheme.onSurfaceVariant;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showPrimaryActions) ...[
          if (showReplyAction)
            _ActionPillButton(
              onPressed: onReplyPressed,
              backgroundColor: actionBg,
              borderColor: actionBorder,
              foregroundColor: actionFg,
              icon: const Icon(Icons.reply_outlined, size: 18),
              label: _TopicDetailPageState._labelReply,
            ),
          _ActionPillButton(
            onPressed: reacting ? null : onReactPressed,
            backgroundColor: reacting
                ? theme.colorScheme.primaryContainer.withOpacity(0.6)
                : actionBg,
            borderColor: reacting ? theme.colorScheme.primary : actionBorder,
            foregroundColor: reacting ? theme.colorScheme.primary : actionFg,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: reacting
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.add_reaction_outlined,
                      key: ValueKey('ready'),
                      size: 18,
                    ),
            ),
            label: _TopicDetailPageState._labelReact,
          ),
        ],
        if (hasPending)
          _ReactionStateChip(
            postId: post.id,
            reactionId: pendingId,
            countText: '...',
            selected: false,
            isPending: true,
            pulseToken: pulseToken,
            enableHero: enableReactionHero,
            onPressed: null,
          ),
        ...reactions.map((reaction) {
          final selected = post.currentUserReaction?.id == reaction.id;
          return _ReactionStateChip(
            postId: post.id,
            reactionId: reaction.id,
            countText: '${reaction.count}',
            selected: selected,
            pulseToken: pulseToken,
            enableHero: enableReactionHero,
            onPressed: () => onReactionStatusPressed(reaction.id),
          );
        }),
      ],
    );
  }
}

class _ReactionStateChip extends StatelessWidget {
  const _ReactionStateChip({
    required this.postId,
    required this.reactionId,
    required this.countText,
    required this.selected,
    required this.pulseToken,
    required this.onPressed,
    this.enableHero = true,
    this.isPending = false,
  });

  final int postId;
  final String reactionId;
  final String countText;
  final bool selected;
  final int pulseToken;
  final VoidCallback? onPressed;
  final bool enableHero;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = ActionChip(
      avatar: Text(
        _reactionEmoji(reactionId),
        style: const TextStyle(fontSize: 14),
      ),
      label: Text(countText),
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
      onPressed: onPressed,
    );

    final animatedChip = TweenAnimationBuilder<double>(
      key: ValueKey<String>(
        'reaction-chip-$postId-$reactionId-$selected-$isPending-$pulseToken',
      ),
      tween: Tween<double>(begin: selected ? 0.88 : 1, end: 1),
      duration: Duration(milliseconds: selected ? 280 : 180),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(
          opacity: isPending ? value.clamp(0.72, 1) : 1,
          child: child,
        ),
      ),
      child: chip,
    );

    final child = Material(color: Colors.transparent, child: animatedChip);
    if (!enableHero) {
      return child;
    }
    return Hero(
      tag: _reactionHeroTag(postId: postId, reactionId: reactionId),
      transitionOnUserGestures: true,
      child: child,
    );
  }
}

class _CommentInlineActions extends StatelessWidget {
  const _CommentInlineActions({
    required this.reacting,
    this.onReplyPressed,
    this.onReactPressed,
  });

  final bool reacting;
  final VoidCallback? onReplyPressed;
  final VoidCallback? onReactPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.68);
    final border = theme.colorScheme.outlineVariant.withOpacity(0.5);
    final fg = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommentInlineActionButton(
          tooltip: _TopicDetailPageState._labelReply,
          icon: const Icon(Icons.reply_outlined, size: 17),
          onPressed: onReplyPressed,
          backgroundColor: bg,
          borderColor: border,
          foregroundColor: fg,
        ),
        const SizedBox(width: 6),
        _CommentInlineActionButton(
          tooltip: _TopicDetailPageState._labelReact,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: reacting
                ? const SizedBox(
                    key: ValueKey('comment-like-loading'),
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add_reaction_outlined,
                    key: ValueKey('comment-like-ready'),
                    size: 17,
                  ),
          ),
          onPressed: reacting ? null : onReactPressed,
          backgroundColor: reacting
              ? theme.colorScheme.primaryContainer.withOpacity(0.62)
              : bg,
          borderColor: reacting ? theme.colorScheme.primary : border,
          foregroundColor: reacting ? theme.colorScheme.primary : fg,
        ),
      ],
    );
  }
}

class _CommentInlineActionButton extends StatelessWidget {
  const _CommentInlineActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: disabled
            ? backgroundColor.withOpacity(0.45)
            : backgroundColor.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: disabled ? borderColor.withOpacity(0.35) : borderColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: IconTheme.merge(
              data: IconThemeData(
                size: 17,
                color: disabled
                    ? foregroundColor.withOpacity(0.55)
                    : foregroundColor,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: disabled
          ? backgroundColor.withOpacity(0.45)
          : backgroundColor.withOpacity(0.9),
      shape: StadiumBorder(
        side: BorderSide(
          color: disabled ? borderColor.withOpacity(0.35) : borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: 18,
                  color: disabled
                      ? foregroundColor.withOpacity(0.55)
                      : foregroundColor,
                ),
                child: icon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: disabled
                      ? foregroundColor.withOpacity(0.55)
                      : foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
