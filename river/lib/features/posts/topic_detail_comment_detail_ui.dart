part of 'topic_detail_page.dart';

extension _CommentDetailPageUi on _CommentDetailPageState {
  Widget _buildPage(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasMutations);
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(_CommentDetailPageState._labelTitle),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              const _SectionHeader(
                title: _CommentDetailPageState._labelRootComment,
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(_rootPost.id),
                tween: Tween<double>(begin: 0.98, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 10),
                      child: child,
                    ),
                  );
                },
                child: _CommentDetailPostCard(
                  post: _rootPost,
                  cookieHeader: _activeCookieHeader(),
                  emojiUrls: _emojiUrls,
                  onQuoteTap: _showQuoteBottomSheet,
                  onMentionTap: _openMentionProfileFromContent,
                  onTopicLinkTap: _openTopicFromContent,
                  heroTag: widget.heroTag,
                  reacting: _reactingPostIds.contains(_rootPost.id),
                  pendingHeroReactionId:
                      _pendingReactionHeroByPostId[_rootPost.id],
                  reactionPulseToken:
                      _reactionPulseTokenByPostId[_rootPost.id] ?? 0,
                  onLongPress: () => _showCommentActions(_rootPost),
                  onAuthorTap: _openAuthorProfileSheetForPost,
                  onReactPressed: _onReactPressed,
                  onReactionStatusPressed: (post, reactionId) =>
                      _onReactionStatusPressed(
                        post: post,
                        reactionId: reactionId,
                      ),
                  onReplyPressed: (post) {
                    _openReplyComposer(
                      replyToPostNumber: post.postNumber,
                      quoteUsername: post.authorUsername,
                      quoteTopicId: post.topicId,
                      quoteContent: _stripQuotedMarkdown(post.contentMarkdown),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _SectionHeader(
                title: _CommentDetailPageState._labelReplies,
                trailing: Text('\u5171 ${_replies.length} \u6761'),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildRepliesBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepliesBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        key: ValueKey<String>('comment-detail-loading'),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        key: const ValueKey<String>('comment-detail-error'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _loadData,
              child: const Text(_CommentDetailPageState._labelReload),
            ),
          ],
        ),
      );
    }

    if (_replies.isEmpty) {
      return const Padding(
        key: ValueKey<String>('comment-detail-empty'),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(_CommentDetailPageState._labelEmptyReplies)),
      );
    }

    return Column(
      key: const ValueKey<String>('comment-detail-list'),
      children: _replies
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final post = entry.value;
            final displayPost = post.copyWith(
              contentMarkdown: _stripQuotedMarkdown(post.contentMarkdown),
            );
            return TweenAnimationBuilder<double>(
              key: ValueKey<int>(post.id),
              tween: Tween<double>(begin: 0.98, end: 1),
              duration: Duration(
                milliseconds: 180 + (index * 28).clamp(0, 220),
              ),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 9),
                    child: child,
                  ),
                );
              },
              child: _CommentDetailPostCard(
                post: displayPost,
                cookieHeader: _activeCookieHeader(),
                emojiUrls: _emojiUrls,
                onQuoteTap: _showQuoteBottomSheet,
                onMentionTap: _openMentionProfileFromContent,
                onTopicLinkTap: _openTopicFromContent,
                reacting: _reactingPostIds.contains(post.id),
                pendingHeroReactionId: _pendingReactionHeroByPostId[post.id],
                reactionPulseToken: _reactionPulseTokenByPostId[post.id] ?? 0,
                onLongPress: () => _showCommentActions(post),
                onAuthorTap: _openAuthorProfileSheetForPost,
                onReactPressed: _onReactPressed,
                onReactionStatusPressed: (target, reactionId) =>
                    _onReactionStatusPressed(
                      post: target,
                      reactionId: reactionId,
                    ),
                onReplyPressed: (target) {
                  _openReplyComposer(
                    replyToPostNumber: target.postNumber,
                    quoteUsername: target.authorUsername,
                    quoteTopicId: target.topicId,
                    quoteContent: _stripQuotedMarkdown(target.contentMarkdown),
                  );
                },
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
