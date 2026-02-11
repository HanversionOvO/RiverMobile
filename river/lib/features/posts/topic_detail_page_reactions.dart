part of 'topic_detail_page.dart';

extension _TopicDetailPageReactions on _TopicDetailPageState {
  List<_ReactionOption> _availableReactionOptions() {
    final valid = _detail?.validReactions ?? const <String>{};
    if (valid.isEmpty) {
      return _defaultReactionOptions;
    }
    final filtered = _defaultReactionOptions
        .where((option) => valid.contains(option.id))
        .toList(growable: false);
    return filtered.isEmpty ? _defaultReactionOptions : filtered;
  }

  Future<void> _onReactPressed(RiverSideTopicPostDetail post) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelReactionNotReady),
        ),
      );
      return;
    }

    final options = _availableReactionOptions();
    final selected = await showModalBottomSheet<_ReactionOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReactionPickerSheet(
          postId: post.id,
          options: options,
          currentReactionId: post.currentUserReaction?.id,
          onSelected: (option) {
            _mutateState(() {
              _pendingReactionHeroByPostId[post.id] = option.id;
            });
            Navigator.of(sheetContext).pop(option);
          },
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }

    await _togglePostReaction(
      post: post,
      reactionId: selected.id,
      cookieHeader: cookieHeader,
    );
  }

  Future<void> _togglePostReaction({
    required RiverSideTopicPostDetail post,
    required String reactionId,
    required String cookieHeader,
  }) async {
    _mutateState(() {
      _reactingPostIds.add(post.id);
    });

    try {
      final state = await widget.dependencies.accountStore.riverSideApiClient
          .togglePostReaction(
            postId: post.id,
            reactionId: reactionId,
            cookieHeader: cookieHeader,
          );
      if (!mounted) {
        return;
      }

      _mutateState(() {
        _applyPostReactionState(state);
      });
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _pendingReactionHeroByPostId.remove(post.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _pendingReactionHeroByPostId.remove(post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u70b9\u8d5e\u64cd\u4f5c\u5931\u8d25')),
      );
    } finally {
      _mutateState(() {
        _reactingPostIds.remove(post.id);
      });
    }
  }

  void _applyPostReactionState(RiverSidePostReactionState state) {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final clearCurrent = state.currentUserReaction == null;
    if (detail.mainPost.id == state.postId) {
      _detail = detail.copyWith(
        mainPost: detail.mainPost.copyWith(
          reactions: state.reactions,
          currentUserReaction: state.currentUserReaction,
          clearCurrentUserReaction: clearCurrent,
          reactionUsersCount: state.reactionUsersCount,
        ),
      );
    }

    final index = _comments.indexWhere((post) => post.id == state.postId);
    if (index >= 0) {
      final next = <RiverSideTopicPostDetail>[..._comments];
      final current = next[index];
      next[index] = current.copyWith(
        reactions: state.reactions,
        currentUserReaction: state.currentUserReaction,
        clearCurrentUserReaction: clearCurrent,
        reactionUsersCount: state.reactionUsersCount,
      );
      _comments = next;
    }
    _pendingReactionHeroByPostId.remove(state.postId);
    _reactionPulseTokenByPostId[state.postId] =
        (_reactionPulseTokenByPostId[state.postId] ?? 0) + 1;
  }

  Future<void> _onReactionStatusPressed({
    required RiverSideTopicPostDetail post,
    required String reactionId,
  }) async {
    try {
      final groups = await widget.dependencies.accountStore.riverSideApiClient
          .fetchPostReactionUsers(
            postId: post.id,
            reactionId: reactionId,
            cookieHeader: _activeCookieHeader(),
          );
      if (!mounted) {
        return;
      }

      RiverSidePostReactionUsersGroup? group;
      for (final item in groups) {
        if (item.id == reactionId) {
          group = item;
          break;
        }
      }
      group ??= groups.isEmpty ? null : groups.first;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return _ReactionUsersSheet(
            postId: post.id,
            reactionId: reactionId,
            group: group,
          );
        },
      );
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u52a0\u8f7d\u70b9\u8d5e\u7528\u6237\u5931\u8d25'),
        ),
      );
    }
  }
}

class _ReactionPickerSheet extends StatefulWidget {
  const _ReactionPickerSheet({
    required this.postId,
    required this.options,
    required this.currentReactionId,
    required this.onSelected,
  });

  final int postId;
  final List<_ReactionOption> options;
  final String? currentReactionId;
  final ValueChanged<_ReactionOption> onSelected;

  @override
  State<_ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<_ReactionPickerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..forward();
  String? _selectingReactionId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSelect(_ReactionOption option) async {
    if (_selectingReactionId != null) return;
    setState(() {
      _selectingReactionId = option.id;
    });
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    widget.onSelected(option);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: colors.surface.withOpacity(0.98),
            elevation: 10,
            shadowColor: colors.shadow.withOpacity(0.22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: colors.outlineVariant.withOpacity(0.45)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '\u9009\u62e9\u53cd\u5e94',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        tooltip: '\u5173\u95ed',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    '\u70b9\u51fb\u4e00\u4e2a\u8868\u60c5\u53d1\u9001\u70b9\u8d5e\u72b6\u6001',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List<Widget>.generate(widget.options.length, (
                      index,
                    ) {
                      final option = widget.options[index];
                      final isCurrent = widget.currentReactionId == option.id;
                      final start = (0.05 + index * 0.045).clamp(0.0, 0.86);
                      final end = (start + 0.24).clamp(start + 0.06, 1.0);
                      final animation = CurvedAnimation(
                        parent: _controller,
                        curve: Interval(start, end, curve: Curves.easeOutCubic),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: Hero(
                            tag: _reactionHeroTag(
                              postId: widget.postId,
                              reactionId: option.id,
                            ),
                            child: Material(
                              color: isCurrent
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _handleSelect(option),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    14,
                                    10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                        scale: _selectingReactionId == option.id
                                            ? 1.2
                                            : 1,
                                        duration: const Duration(
                                          milliseconds: 140,
                                        ),
                                        curve: Curves.easeOutBack,
                                        child: Text(
                                          option.emoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: colors.primary,
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
                    }),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      label: const Text('\u53d6\u6d88'),
                    ),
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

class _ReactionUsersSheet extends StatelessWidget {
  const _ReactionUsersSheet({
    required this.postId,
    required this.reactionId,
    required this.group,
  });

  final int postId;
  final String reactionId;
  final RiverSidePostReactionUsersGroup? group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final users = group?.users ?? const <RiverSideReactionUser>[];
    final count = group?.count ?? 0;

    return SafeArea(
      top: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: colors.surface.withOpacity(0.98),
            elevation: 10,
            shadowColor: colors.shadow.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: colors.outlineVariant.withOpacity(0.45)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withOpacity(0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Hero(
                        tag: _reactionHeroTag(
                          postId: postId,
                          reactionId: reactionId,
                        ),
                        child: Material(
                          color: colors.primaryContainer.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              _reactionEmoji(reactionId),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '点赞详情',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$count 人',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (users.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        _TopicDetailPageState._labelReactionUsersEmpty,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 460),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _ReactionUserTile(user: user, index: index);
                        },
                      ),
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

class _ReactionUserTile extends StatelessWidget {
  const _ReactionUserTile({required this.user, required this.index});

  final RiverSideReactionUser user;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1),
      duration: Duration(milliseconds: 180 + index * 30),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: Material(
        color: colors.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl.isEmpty
                ? null
                : NetworkImage(user.avatarUrl),
            child: user.avatarUrl.isEmpty
                ? const Icon(Icons.person_outline)
                : null,
          ),
          title: Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text('@${user.username}'),
        ),
      ),
    );
  }
}
