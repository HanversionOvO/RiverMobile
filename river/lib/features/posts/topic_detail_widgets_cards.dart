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
    required this.onMentionTap,
    required this.onTopicLinkTap,
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
    required this.onAiSummaryPressed,
    this.aiSummaryLoading = false,
    this.showAiSummaryMarquee = false,
    this.showReplyAction = true,
    this.isJumpHighlighted = false,
    this.jumpHighlightToken = 0,
  });

  final RiverSideTopicDetail detail;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<int> onTopicLinkTap;
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
  final VoidCallback onAiSummaryPressed;
  final bool aiSummaryLoading;
  final bool showAiSummaryMarquee;
  final bool showReplyAction;
  final bool isJumpHighlighted;
  final int jumpHighlightToken;

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
          onMentionTap: widget.onMentionTap,
          onTopicLinkTap: widget.onTopicLinkTap,
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
          leadingAction: _AiSummaryButton(
            onPressed: widget.onAiSummaryPressed,
            loading: widget.aiSummaryLoading,
          ),
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
      child: _JumpHighlightWrapper(
        highlighted: widget.isJumpHighlighted,
        token: widget.jumpHighlightToken,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: _AiMarqueeBorder(
            enabled: widget.showAiSummaryMarquee,
            borderRadius: BorderRadius.circular(20),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
          ),
        ),
      ),
    );
  }
}

class _AiSummaryButton extends StatefulWidget {
  const _AiSummaryButton({required this.onPressed, required this.loading});

  final VoidCallback onPressed;
  final bool loading;

  @override
  State<_AiSummaryButton> createState() => _AiSummaryButtonState();
}

class _AiSummaryButtonState extends State<_AiSummaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * math.pi * 2;
        final pulse = 0.55 + 0.45 * (math.sin(phase) * 0.5 + 0.5);
        final gradientBegin = Alignment(
          math.cos(phase) * 0.45,
          math.sin(phase) * 0.45,
        );
        final gradientEnd = Alignment(
          -math.cos(phase) * 0.45,
          -math.sin(phase) * 0.45,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: gradientBegin,
                  end: gradientEnd,
                  colors: [
                    const Color(
                      0xFFAED8FF,
                    ).withValues(alpha: (isDark ? 0.30 : 0.40) * pulse),
                    const Color(
                      0xFFCDB8FF,
                    ).withValues(alpha: (isDark ? 0.28 : 0.38) * pulse),
                    const Color(
                      0xFFFFCFE1,
                    ).withValues(alpha: (isDark ? 0.26 : 0.36) * pulse),
                    const Color(
                      0xFFBDEDE3,
                    ).withValues(alpha: (isDark ? 0.24 : 0.34) * pulse),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.24 : 0.42),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF9CC8FF,
                    ).withValues(alpha: (isDark ? 0.14 : 0.12) * pulse),
                    blurRadius: 14,
                    spreadRadius: 0.3,
                  ),
                ],
              ),
              child: Material(
                color: theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.22 : 0.14,
                ),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: widget.loading ? null : widget.onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.loading)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                foreground,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: foreground,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          widget.loading ? 'AI总结中...' : 'AI总结',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AiMarqueeBorder extends StatefulWidget {
  const _AiMarqueeBorder({
    required this.enabled,
    required this.borderRadius,
    required this.child,
  });

  final bool enabled;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_AiMarqueeBorder> createState() => _AiMarqueeBorderState();
}

class _AiMarqueeBorderState extends State<_AiMarqueeBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AiMarqueeBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _controller.repeat();
      return;
    }
    if (oldWidget.enabled && !widget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isDark = theme.brightness == Brightness.dark;
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AiMarqueeBorderPainter(
                    progress: _controller.value,
                    borderRadius: widget.borderRadius,
                    darkMode: isDark,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiMarqueeBorderPainter extends CustomPainter {
  _AiMarqueeBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.darkMode,
  });

  final double progress;
  final BorderRadius borderRadius;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(1.2);
    final alpha = darkMode ? 1.0 : 0.86;
    final sweep = SweepGradient(
      colors: [
        Colors.transparent,
        const Color(0xFF4CC9F0).withValues(alpha: 0.35 * alpha),
        const Color(0xFF3A86FF).withValues(alpha: 0.75 * alpha),
        const Color(0xFF7B2FF7).withValues(alpha: 0.92 * alpha),
        const Color(0xFFF72585).withValues(alpha: 0.86 * alpha),
        const Color(0xFFFF9E00).withValues(alpha: 0.62 * alpha),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0.0, 0.06, 0.13, 0.20, 0.27, 0.34, 0.42, 1.0],
      transform: GradientRotation(progress * math.pi * 2),
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.2)
      ..shader = sweep.createShader(rect);
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = sweep.createShader(rect);
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, corePaint);
  }

  @override
  bool shouldRepaint(covariant _AiMarqueeBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.darkMode != darkMode;
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    super.key,
    required this.post,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    required this.onMentionTap,
    required this.onTopicLinkTap,
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
    this.isJumpHighlighted = false,
    this.jumpHighlightToken = 0,
  });

  final RiverSideTopicPostDetail post;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<int> onTopicLinkTap;
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
  final bool isJumpHighlighted;
  final int jumpHighlightToken;

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
        child: _JumpHighlightWrapper(
          highlighted: widget.isJumpHighlighted,
          token: widget.jumpHighlightToken,
          borderRadius: BorderRadius.circular(18),
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
                        onReplyPressed: () =>
                            widget.onReplyPressed(widget.post),
                        onReactPressed: () =>
                            widget.onReactPressed(widget.post),
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
                      onMentionTap: widget.onMentionTap,
                      onTopicLinkTap: widget.onTopicLinkTap,
                      enableImageHero: false,
                      enableTextSelection: false,
                      replyToPostNumber: widget.post.replyToPostNumber,
                      replyToUsername: widget.post.replyToUsername,
                    ),
                    if (hasReactionStatus) ...[
                      const SizedBox(height: 10),
                      _PostReactionBar(
                        post: widget.post,
                        reacting: widget.isReacting,
                        onReactPressed: () =>
                            widget.onReactPressed(widget.post),
                        onReplyPressed: () =>
                            widget.onReplyPressed(widget.post),
                        onReactionStatusPressed: (reactionId) {
                          widget.onReactionStatusPressed(
                            widget.post,
                            reactionId,
                          );
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
      ),
    );
  }
}

class _JumpHighlightWrapper extends StatelessWidget {
  const _JumpHighlightWrapper({
    required this.highlighted,
    required this.token,
    required this.borderRadius,
    required this.child,
  });

  final bool highlighted;
  final int token;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!highlighted) {
      return child;
    }
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('jump-highlight-$token'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.linear,
      builder: (context, value, content) {
        final pulse = math.sin(value * math.pi * 3).clamp(0.0, 1.0);
        final envelope = (1 - value * 0.35).clamp(0.72, 1.0);
        final glowAlpha = pulse * envelope;
        final scale = 1 + 0.014 * glowAlpha;
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.22 * glowAlpha,
                  ),
                  blurRadius: 18 * glowAlpha + 2,
                  spreadRadius: 1.5 * glowAlpha,
                ),
              ],
            ),
            child: content,
          ),
        );
      },
      child: child,
    );
  }
}

class _CommentDetailPostCard extends StatelessWidget {
  const _CommentDetailPostCard({
    required this.post,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    required this.onMentionTap,
    required this.onTopicLinkTap,
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
  final ValueChanged<String> onMentionTap;
  final ValueChanged<int> onTopicLinkTap;
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
                onMentionTap: onMentionTap,
                onTopicLinkTap: onTopicLinkTap,
                enableImageHero: false,
                enableTextSelection: false,
                replyToPostNumber: post.replyToPostNumber,
                replyToUsername: post.replyToUsername,
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
    this.leadingAction,
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
  final Widget? leadingAction;

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
    final actionBorder = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    final actionFg = theme.colorScheme.onSurfaceVariant;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (leadingAction case final Widget actionWidget) actionWidget,
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
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
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
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.68,
    );
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
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
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.62)
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
            ? backgroundColor.withValues(alpha: 0.45)
            : backgroundColor.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: disabled ? borderColor.withValues(alpha: 0.35) : borderColor,
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
                    ? foregroundColor.withValues(alpha: 0.55)
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
          ? backgroundColor.withValues(alpha: 0.45)
          : backgroundColor.withValues(alpha: 0.9),
      shape: StadiumBorder(
        side: BorderSide(
          color: disabled ? borderColor.withValues(alpha: 0.35) : borderColor,
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
                      ? foregroundColor.withValues(alpha: 0.55)
                      : foregroundColor,
                ),
                child: icon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: disabled
                      ? foregroundColor.withValues(alpha: 0.55)
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
