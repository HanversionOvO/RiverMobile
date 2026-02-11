// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/widgets/river_image_viewer.dart';
import 'package:river/core/widgets/river_markdown_editor.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
import 'package:river/core/navigation/river_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

part 'topic_detail_comment_detail_page.dart';
part 'topic_detail_comment_detail_actions.dart';
part 'topic_detail_comment_detail_ui.dart';
part 'topic_detail_widgets_cards.dart';
part 'topic_detail_widgets_content.dart';
part 'topic_detail_widgets_images.dart';
part 'topic_detail_widgets_meta.dart';
part 'topic_detail_content_utils.dart';
part 'topic_detail_page_actions.dart';
part 'topic_detail_page_reactions.dart';
part 'topic_detail_page_loading.dart';

class _ReactionOption {
  const _ReactionOption({required this.id, required this.emoji});

  final String id;
  final String emoji;
}

const List<_ReactionOption> _defaultReactionOptions = <_ReactionOption>[
  _ReactionOption(id: '+1', emoji: '\u{1F44D}'),
  _ReactionOption(id: 'laughing', emoji: '\u{1F606}'),
  _ReactionOption(id: 'heart', emoji: '\u2764\uFE0F'),
  _ReactionOption(id: 'open_mouth', emoji: '\u{1F62E}'),
  _ReactionOption(id: 'thinking', emoji: '\u{1F914}'),
  _ReactionOption(id: 'anxious_face_with_sweat', emoji: '\u{1F605}'),
  _ReactionOption(id: 'distorted_face', emoji: '\u{1F635}'),
  _ReactionOption(id: 'saluting_face', emoji: '\u{1FAE1}'),
  _ReactionOption(id: 'sob', emoji: '\u{1F62D}'),
  _ReactionOption(id: '-1', emoji: '\u{1F44E}'),
];

String _reactionEmoji(String reactionId) {
  for (final option in _defaultReactionOptions) {
    if (option.id == reactionId) {
      return option.emoji;
    }
  }
  return '\u2753';
}

String _commentHeroTag(int postId) => 'comment-card-$postId';

Widget _commentCardHeroShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  final heroChild = flightDirection == HeroFlightDirection.push
      ? fromHero.child
      : toHero.child;

  return Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: heroChild,
            ),
          ),
        );
      },
    ),
  );
}

class TopicDetailPage extends StatefulWidget {
  const TopicDetailPage({
    super.key,
    required this.dependencies,
    required this.topicId,
  });

  final AppDependencies dependencies;
  final int topicId;

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage> {
  static const int _loadMoreBatchSize = 20;
  static const double _loadMoreTriggerOffset = 280;
  static const double _showBackToTopOffset = 420;

  static const String _labelTopicDetail = '\u5e16\u5b50\u8be6\u60c5';
  static const String _labelMainPost = '\u4e3b\u8d34\u5185\u5bb9';
  static const String _labelReplies = '\u8bc4\u8bba\u5185\u5bb9';
  static const String _labelRetry = '\u91cd\u8bd5';
  static const String _labelNoComments = '\u6682\u65e0\u8bc4\u8bba';
  static const String _labelNoMoreReplies =
      '\u6ca1\u6709\u66f4\u591a\u8bc4\u8bba\u4e86';
  static const String _labelReply = '\u56de\u590d';
  static const String _labelReplyEditorTitle = '\u53d1\u5e03\u56de\u590d';
  static const String _labelReplySuccess =
      '\u56de\u590d\u53d1\u5e03\u6210\u529f';
  static const String _labelReplyNeedLogin =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';
  static const String _labelEditCommentTitle = '\u7f16\u8f91\u8bc4\u8bba';
  static const String _labelEditCommentSuccess =
      '\u8bc4\u8bba\u5df2\u66f4\u65b0';
  static const String _labelDeleteCommentTitle = '\u5220\u9664\u8bc4\u8bba';
  static const String _labelDeleteCommentHint =
      '\u786e\u5b9a\u8981\u5220\u9664\u8fd9\u6761\u8bc4\u8bba\u5417\uff1f';
  static const String _labelDeleteCommentSuccess =
      '\u8bc4\u8bba\u5df2\u5220\u9664';
  static const String _labelActionCopyContent = '\u590d\u5236\u5185\u5bb9';
  static const String _labelActionEditComment = '\u7f16\u8f91\u8bc4\u8bba';
  static const String _labelActionDeleteComment = '\u5220\u9664\u8bc4\u8bba';
  static const String _labelSave = '\u4fdd\u5b58';
  static const String _labelCancel = '\u53d6\u6d88';
  static const String _labelDelete = '\u5220\u9664';
  static const String _labelTargetFloorMissing =
      '\u76ee\u6807\u697c\u5c42\u5c1a\u672a\u52a0\u8f7d';
  static const String _labelQuoteLoading =
      '\u6b63\u5728\u52a0\u8f7d\u88ab\u56de\u590d\u5185\u5bb9...';
  static const String _labelQuoteLoadFailed =
      '\u88ab\u56de\u590d\u5185\u5bb9\u52a0\u8f7d\u5931\u8d25\uff0c\u5df2\u663e\u793a\u5f15\u7528\u7247\u6bb5';
  static const String _labelReplyContent = '\u56de\u590d\u8be5\u5185\u5bb9';
  static const String _labelJumpToFloor =
      '\u8df3\u8f6c\u81f3\u88ab\u56de\u590d\u697c\u5c42';
  static const String _labelInvalidQuoteFloor =
      '\u65e0\u6cd5\u8bc6\u522b\u88ab\u56de\u590d\u697c\u5c42';
  static const String _labelCrossTopicQuote =
      '\u8de8\u5e16\u5f15\u7528\u6682\u4e0d\u652f\u6301\u8df3\u8f6c';
  static const String _labelUnknownUser = '\u672a\u77e5\u7528\u6237';
  static const String _labelUnknownState = '\u72b6\u6001\u672a\u77e5';
  static const String _labelOnline = '\u5728\u7ebf';
  static const String _labelOffline = '\u79bb\u7ebf';
  static const String _labelEmpty = '\u6682\u65e0\u5185\u5bb9';
  static const String _labelReact = '\u70b9\u8d5e';
  static const String _labelReactionNotReady =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';
  static const String _labelReactionUsersEmpty = '\u6682\u65e0\u7528\u6237';

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _postItemKeys = <int, GlobalKey>{};

  RiverSideTopicDetail? _detail;
  List<RiverSideTopicPostDetail> _comments = const <RiverSideTopicPostDetail>[];
  final Set<int> _loadedPostIds = <int>{};
  final Set<int> _reactingPostIds = <int>{};
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};

  bool _loadingInitial = true;
  bool _loadingMore = false;
  final ValueNotifier<bool> _showBackToTopButtonNotifier = ValueNotifier<bool>(
    false,
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showBackToTopButtonNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final offset = position.pixels;
    if (offset >= position.maxScrollExtent - _loadMoreTriggerOffset) {
      _loadMoreComments();
    }

    final nextShow = offset >= _showBackToTopOffset;
    if (_showBackToTopButtonNotifier.value != nextShow) {
      _showBackToTopButtonNotifier.value = nextShow;
    }
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  void _mutateState(VoidCallback action) {
    if (!mounted) {
      return;
    }
    setState(action);
  }

  bool get _hasMoreComments {
    final detail = _detail;
    if (detail == null) {
      return false;
    }
    for (final postId in detail.streamPostIds) {
      if (!_loadedPostIds.contains(postId)) {
        return true;
      }
    }
    return false;
  }

  bool _hasLoadedPostNumber(int postNumber) {
    if (postNumber == 1 && _detail != null) {
      return true;
    }
    return _comments.any((post) => post.postNumber == postNumber);
  }

  GlobalKey _keyForPostNumber(int postNumber) {
    return _postItemKeys.putIfAbsent(postNumber, GlobalKey.new);
  }

  List<int> _nextPostIdsToLoad() {
    final detail = _detail;
    if (detail == null) {
      return const <int>[];
    }

    final next = <int>[];
    for (final postId in detail.streamPostIds) {
      if (_loadedPostIds.contains(postId)) {
        continue;
      }
      next.add(postId);
      if (next.length >= _loadMoreBatchSize) {
        break;
      }
    }
    return next;
  }

  Future<void> _showQuoteBottomSheet(_QuoteBlock quote) async {
    final cookieHeader = _activeCookieHeader();
    final Future<RiverSideTopicPostDetail>? quotedPostFuture =
        quote.ref.postNumber > 0
        ? widget.dependencies.accountStore.riverSideApiClient
              .fetchTopicPostByNumber(
                topicId: quote.ref.topicId,
                postNumber: quote.ref.postNumber,
                cookieHeader: cookieHeader,
              )
        : null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u56de\u590d @${quote.ref.username} 闂?#${quote.ref.postNumber}',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: quotedPostFuture == null
                      ? SingleChildScrollView(
                          child: _MarkdownContent(
                            markdown: quote.contentMarkdown,
                            cookieHeader: cookieHeader,
                            emojiUrls: _emojiUrls,
                          ),
                        )
                      : FutureBuilder<RiverSideTopicPostDetail>(
                          future: quotedPostFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(_labelQuoteLoading),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _labelQuoteLoadFailed,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    _MarkdownContent(
                                      markdown: quote.contentMarkdown,
                                      cookieHeader: cookieHeader,
                                      emojiUrls: _emojiUrls,
                                    ),
                                  ],
                                ),
                              );
                            }

                            final markdown =
                                snapshot.data?.contentMarkdown ??
                                quote.contentMarkdown;
                            return SingleChildScrollView(
                              child: _MarkdownContent(
                                markdown: markdown,
                                cookieHeader: cookieHeader,
                                emojiUrls: _emojiUrls,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _jumpToPostNumber(
                            postNumber: quote.ref.postNumber,
                            topicId: quote.ref.topicId,
                          );
                        },
                        child: const Text(_labelJumpToFloor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final detailTopicId = _detail?.topicId;
                          if (detailTopicId == null ||
                              quote.ref.topicId != detailTopicId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(_labelCrossTopicQuote),
                              ),
                            );
                            return;
                          }
                          await _openReplyComposer(
                            topicId: quote.ref.topicId,
                            replyToPostNumber: quote.ref.postNumber,
                            quoteUsername: quote.ref.username,
                            quoteTopicId: quote.ref.topicId,
                            quoteContent: _stripQuotedMarkdown(
                              quote.contentMarkdown,
                            ),
                          );
                        },
                        child: const Text(_labelReplyContent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    await _loadInitial();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openCommentDetail(RiverSideTopicPostDetail post) async {
    final hasMutations = await Navigator.of(context).push<bool>(
      riverPageRoute<bool>(
        builder: (_) => CommentDetailPage(
          dependencies: widget.dependencies,
          rootPost: post,
          heroTag: _commentHeroTag(post.id),
          initialEmojiUrls: _emojiUrls,
          initialEmojiGroups: _emojiGroups,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (hasMutations == true) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.title;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title == null || title.isEmpty ? _labelTopicDetail : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showBackToTopButtonNotifier,
        builder: (context, visible, _) {
          return AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: visible ? 1 : 0,
            child: visible
                ? FloatingActionButton.small(
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.vertical_align_top),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingInitial && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadInitial,
                child: const Text(_labelRetry),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const SizedBox.shrink();
    }
    final cookieHeader = _activeCookieHeader();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      notificationPredicate: (notification) => notification.depth == 0,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          const _SectionHeader(title: _labelMainPost),
          _MainPostCard(
            key: _keyForPostNumber(1),
            detail: detail,
            cookieHeader: cookieHeader,
            emojiUrls: _emojiUrls,
            onQuoteTap: _showQuoteBottomSheet,
            isReacting: _reactingPostIds.contains(detail.mainPost.id),
            onReactPressed: _onReactPressed,
            onReplyPressed: (post) {
              _openReplyComposer(topicId: post.topicId);
            },
            onReactionStatusPressed: (post, reactionId) {
              _onReactionStatusPressed(post: post, reactionId: reactionId);
            },
            onAuthorTap: _openAuthorProfileSheetForPost,
          ),
          const SizedBox(height: 10),
          _SectionHeader(
            title: _labelReplies,
            trailing: Text('\u5171 ${detail.replyCount} \u6761\u56de\u590d'),
          ),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text(_labelNoComments)),
            )
          else
            ..._comments.map(
              (post) => _CommentCard(
                key: _keyForPostNumber(post.postNumber),
                post: post,
                cookieHeader: cookieHeader,
                emojiUrls: _emojiUrls,
                onQuoteTap: _showQuoteBottomSheet,
                isReacting: _reactingPostIds.contains(post.id),
                onReactPressed: _onReactPressed,
                heroTag: _commentHeroTag(post.id),
                onTap: () => _openCommentDetail(post),
                onLongPress: () => _showCommentActions(post),
                onAuthorTap: _openAuthorProfileSheetForPost,
                onReplyPressed: (target) {
                  _openReplyComposer(
                    topicId: target.topicId,
                    replyToPostNumber: target.postNumber,
                    quoteUsername: target.authorUsername,
                    quoteTopicId: target.topicId,
                    quoteContent: _stripQuotedMarkdown(target.contentMarkdown),
                  );
                },
                onReactionStatusPressed: (selectedPost, reactionId) {
                  _onReactionStatusPressed(
                    post: selectedPost,
                    reactionId: reactionId,
                  );
                },
              ),
            ),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!_hasMoreComments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  _labelNoMoreReplies,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            const SizedBox(height: 36),
        ],
      ),
    );
  }
}

