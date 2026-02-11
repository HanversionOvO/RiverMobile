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
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options
                  .map((option) {
                    final isCurrent = post.currentUserReaction?.id == option.id;
                    return ChoiceChip(
                      selected: isCurrent,
                      showCheckmark: false,
                      label: Text(
                        option.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      onSelected: (_) => Navigator.of(sheetContext).pop(option),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
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
        showDragHandle: true,
        builder: (sheetContext) {
          final users = group?.users ?? const <RiverSideReactionUser>[];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_reactionEmoji(reactionId)}  ${group?.count ?? 0}',
                    style: Theme.of(sheetContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _TopicDetailPageState._labelReactionUsersEmpty,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: users.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(user.avatarUrl),
                              child: user.avatarUrl.isEmpty
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            title: Text(user.displayName),
                            subtitle: Text('@${user.username}'),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
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
