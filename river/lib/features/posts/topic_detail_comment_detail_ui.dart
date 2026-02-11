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
        appBar: AppBar(title: const Text(_CommentDetailPageState._labelTitle)),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              const _SectionHeader(
                title: _CommentDetailPageState._labelRootComment,
              ),
              _CommentDetailPostCard(
                post: _rootPost,
                cookieHeader: _activeCookieHeader(),
                emojiUrls: _emojiUrls,
                onQuoteTap: _showQuoteBottomSheet,
                heroTag: widget.heroTag,
                onLongPress: () => _showCommentActions(_rootPost),
                onAuthorTap: _openAuthorProfileSheetForPost,
                onReplyPressed: (post) {
                  _openReplyComposer(
                    replyToPostNumber: post.postNumber,
                    quoteUsername: post.authorUsername,
                    quoteTopicId: post.topicId,
                    quoteContent: _stripQuotedMarkdown(post.contentMarkdown),
                  );
                },
              ),
              const SizedBox(height: 10),
              _SectionHeader(
                title: _CommentDetailPageState._labelReplies,
                trailing: Text('\u5171 ${_replies.length} \u6761'),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text(_CommentDetailPageState._labelReload),
                      ),
                    ],
                  ),
                )
              else if (_replies.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(_CommentDetailPageState._labelEmptyReplies),
                  ),
                )
              else
                ..._replies.map((post) {
                  final displayPost = post.copyWith(
                    contentMarkdown: _stripQuotedMarkdown(post.contentMarkdown),
                  );
                  return _CommentDetailPostCard(
                    post: displayPost,
                    cookieHeader: _activeCookieHeader(),
                    emojiUrls: _emojiUrls,
                    onQuoteTap: _showQuoteBottomSheet,
                    onLongPress: () => _showCommentActions(post),
                    onAuthorTap: _openAuthorProfileSheetForPost,
                    onReplyPressed: (target) {
                      _openReplyComposer(
                        replyToPostNumber: target.postNumber,
                        quoteUsername: target.authorUsername,
                        quoteTopicId: target.topicId,
                        quoteContent: _stripQuotedMarkdown(
                          target.contentMarkdown,
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
