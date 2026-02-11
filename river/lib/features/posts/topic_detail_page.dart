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
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
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

// -----------------------------------------------------------------------------
// 鐢悂鍣洪懜鍥т紣閸忓嘲鍤遍弫?
// -----------------------------------------------------------------------------

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

String _topicPostAuthorAvatarHeroTag(RiverSideTopicPostDetail post) {
  return 'author_avatar_${post.topicId}_${post.id}_${post.authorUsername}';
}

String _topicPostAuthorNameHeroTag(RiverSideTopicPostDetail post) {
  return 'author_name_${post.topicId}_${post.id}_${post.authorUsername}';
}

String _reactionHeroTag({required int postId, required String reactionId}) {
  return 'post_reaction_${postId}_$reactionId';
}

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

// -----------------------------------------------------------------------------
// 娑撳鐖滈棃?
// -----------------------------------------------------------------------------

class TopicDetailPreview {
  const TopicDetailPreview({
    required this.title,
    required this.authorDisplayName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.titleHeroTag,
    required this.authorAvatarHeroTag,
    required this.authorNameHeroTag,
  });

  final String title;
  final String authorDisplayName;
  final String authorUsername;
  final String authorAvatarUrl;
  final String titleHeroTag;
  final String authorAvatarHeroTag;
  final String authorNameHeroTag;
}

class TopicDetailPage extends StatefulWidget {
  const TopicDetailPage({
    super.key,
    required this.dependencies,
    required this.topicId,
    this.preview,
  });

  final AppDependencies dependencies;
  final int topicId;
  final TopicDetailPreview? preview;

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage>
    with TickerProviderStateMixin {
  static const int _loadMoreBatchSize = 20;
  static const double _loadMoreTriggerOffset = 280;
  static const double _showBackToTopOffset = 420;

  // 页面文案常量
  static const String _labelTopicDetail = '帖子详情';
  static const String _labelReplies = '评论';
  static const String _labelRetry = '重试';
  static const String _labelNoComments = '暂无评论，快来抢沙发~';
  static const String _labelNoMoreReplies = '没有更多评论了';
  static const String _labelReply = '回复';
  static const String _labelReplyEditorTitle = '编写回复';
  static const String _labelReplySuccess = '回复发布成功';
  static const String _labelReplyNeedLogin = '请先登录 RiverSide 账号';
  static const String _labelEditCommentTitle = '编辑评论';
  static const String _labelEditCommentSuccess = '评论已更新';
  static const String _labelDeleteCommentTitle = '删除评论';
  static const String _labelDeleteCommentHint = '确定要删除这条评论吗？';
  static const String _labelDeleteCommentSuccess = '评论已删除';
  static const String _labelActionCopyContent = '复制内容';
  static const String _labelActionEditComment = '编辑评论';
  static const String _labelActionDeleteComment = '删除评论';
  static const String _labelSave = '保存';
  static const String _labelCancel = '取消';
  static const String _labelDelete = '删除';
  static const String _labelTargetFloorMissing = '目标楼层尚未加载';
  static const String _labelQuoteLoading = '正在加载被回复内容...';
  static const String _labelQuoteLoadFailed = '被回复内容加载失败，已展示引用片段';
  static const String _labelReplyContent = '回复内容';
  static const String _labelJumpToFloor = '跳转至被回复楼层';
  static const String _labelInvalidQuoteFloor = '无法识别被回复楼层';
  static const String _labelCrossTopicQuote = '跨帖引用暂不支持跳转';
  static const String _labelUnknownUser = '未知用户';
  static const String _labelUnknownState = '状态未知';
  static const String _labelOnline = '在线';
  static const String _labelOffline = '离线';
  static const String _labelEmpty = '暂无内容';
  static const String _labelReact = '点赞';
  static const String _labelReactionNotReady = '请先登录 RiverSide 账号';
  static const String _labelReactionUsersEmpty = '暂无用户';

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _postItemKeys = <int, GlobalKey>{};

  RiverSideTopicDetail? _detail;
  List<RiverSideTopicPostDetail> _comments = const <RiverSideTopicPostDetail>[];
  final Set<int> _loadedPostIds = <int>{};
  final Set<int> _reactingPostIds = <int>{};
  final Map<int, String> _pendingReactionHeroByPostId = <int, String>{};
  final Map<int, int> _reactionPulseTokenByPostId = <int, int>{};
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};

  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasRealtimeCommentUpdate = false;
  bool _skipNextEntranceAnimation = false;
  RiverSideMessageBusPoller? _messageBusPoller;
  final ValueNotifier<bool> _showBackToTopButtonNotifier = ValueNotifier<bool>(
    false,
  );
  String? _error;

  // 閸忋儱鐗崟鏇犳殭閹貉冨煑閸?
  late AnimationController _entranceController;
  late AnimationController _contentRevealController;

  @override
  void initState() {
    super.initState();
    // 閸掓繂顫愰崠鏍у珚閻ｎ偅甯堕崚璺烘珤
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );

    _scrollController.addListener(_onScroll);
    _restartRealtimePolling();
    _loadInitial();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _contentRevealController.dispose();
    _messageBusPoller?.stop();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showBackToTopButtonNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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
    if (username == null || username.isEmpty) return null;
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  void _mutateState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  bool get _hasMoreComments {
    final detail = _detail;
    if (detail == null) return false;
    for (final postId in detail.streamPostIds) {
      if (!_loadedPostIds.contains(postId)) return true;
    }
    return false;
  }

  bool _hasLoadedPostNumber(int postNumber) {
    if (postNumber == 1 && _detail != null) return true;
    return _comments.any((post) => post.postNumber == postNumber);
  }

  GlobalKey _keyForPostNumber(int postNumber) {
    return _postItemKeys.putIfAbsent(postNumber, GlobalKey.new);
  }

  List<int> _nextPostIdsToLoad() {
    final detail = _detail;
    if (detail == null) return const <int>[];

    final next = <int>[];
    for (final postId in detail.streamPostIds) {
      if (_loadedPostIds.contains(postId)) continue;
      next.add(postId);
      if (next.length >= _loadMoreBatchSize) break;
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
                  '閸ョ偛浜?@${quote.ref.username} 閻?#${quote.ref.postNumber}',
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
    _entranceController.reset();
    _contentRevealController.value = 1;
    await _loadInitial();
    if (mounted && _detail != null) {
      _entranceController.forward();
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _dismissRealtimeCommentHint() {
    if (!_hasRealtimeCommentUpdate) return;
    _mutateState(() {
      _hasRealtimeCommentUpdate = false;
    });
  }

  Animation<double> _mainContentRevealAnimation() {
    return CurvedAnimation(
      parent: _contentRevealController,
      curve: Curves.easeOutCubic,
    );
  }

  Animation<double> _commentRevealAnimation(int index) {
    final start = (0.08 + index * 0.03).clamp(0.0, 0.82).toDouble();
    final end = (start + 0.24).clamp(start + 0.08, 1.0).toDouble();
    return CurvedAnimation(
      parent: _contentRevealController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
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
    if (!mounted) return;
    if (hasMutations == true) {
      await _loadInitial();
      if (mounted) {
        _entranceController.forward(from: 1.0);
      }
    }
  }

  String get _titleHeroTag =>
      widget.preview?.titleHeroTag ?? 'title_${widget.topicId}';

  String? _mainAuthorAvatarHeroTag(RiverSideTopicDetail? detail) {
    final preview = widget.preview;
    if (preview != null) {
      return preview.authorAvatarHeroTag;
    }
    if (detail != null) {
      return _topicPostAuthorAvatarHeroTag(detail.mainPost);
    }
    return null;
  }

  String? _mainAuthorNameHeroTag(RiverSideTopicDetail? detail) {
    final preview = widget.preview;
    if (preview != null) {
      return preview.authorNameHeroTag;
    }
    if (detail != null) {
      return _topicPostAuthorNameHeroTag(detail.mainPost);
    }
    return null;
  }

  Widget _buildInitialLoadingView(ThemeData theme) {
    final preview = widget.preview;
    final title = preview?.title ?? _labelTopicDetail;
    final avatarHeroTag = preview?.authorAvatarHeroTag;
    final nameHeroTag = preview?.authorNameHeroTag;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 126,
            pinned: true,
            stretch: true,
            scrolledUnderElevation: 4,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface.withOpacity(0.88),
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: 0,
                bottom: 14,
                end: 12,
              ),
              title: Hero(
                tag: _titleHeroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.10),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (preview != null &&
                            avatarHeroTag != null &&
                            avatarHeroTag.isNotEmpty)
                          Hero(
                            tag: avatarHeroTag,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: preview.authorAvatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(preview.authorAvatarUrl),
                              child: preview.authorAvatarUrl.isEmpty
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                          )
                        else
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.person_outline),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (preview != null &&
                                  nameHeroTag != null &&
                                  nameHeroTag.isNotEmpty)
                                Hero(
                                  tag: nameHeroTag,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      preview.authorDisplayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                )
                              else
                                _SkeletonBox(width: 120, height: 14, radius: 7),
                              const SizedBox(height: 6),
                              _SkeletonBox(width: 96, height: 11, radius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SkeletonBox(width: double.infinity, height: 13, radius: 6),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: double.infinity, height: 13, radius: 6),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: 220, height: 13, radius: 6),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        _SkeletonBox(width: 76, height: 30, radius: 15),
                        SizedBox(width: 8),
                        _SkeletonBox(width: 76, height: 30, radius: 15),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SkeletonBox(width: 40, height: 40, radius: 20),
                          SizedBox(width: 10),
                          _SkeletonBox(width: 90, height: 12, radius: 6),
                        ],
                      ),
                      SizedBox(height: 12),
                      _SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 6,
                      ),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 240, height: 12, radius: 6),
                    ],
                  ),
                ),
              );
            }, childCount: 3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 闁奉垵顎冮搹鏇犳倞
    if (_error != null && _detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(_labelTopicDetail)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadInitial,
                  child: const Text(_labelRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading 閻欌偓閹?
    if (_loadingInitial && _detail == null) {
      return _buildInitialLoadingView(theme);
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    // 鐟欏摜娅﹂崗銉ョ壃閸曟洜鏆?
    if (!_loadingInitial &&
        _entranceController.status == AnimationStatus.dismissed) {
      if (_skipNextEntranceAnimation) {
        _skipNextEntranceAnimation = false;
        _entranceController.value = 1;
      } else {
        _entranceController.forward();
      }
    }

    final cookieHeader = _activeCookieHeader();
    final titleHeroTag = _titleHeroTag;
    final mainAuthorAvatarHeroTag = _mainAuthorAvatarHeroTag(detail);
    final mainAuthorNameHeroTag = _mainAuthorNameHeroTag(detail);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            edgeOffset: 140,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 126,
                  pinned: true,
                  stretch: true,
                  scrolledUnderElevation: 4,
                  elevation: 0,
                  backgroundColor: theme.colorScheme.surface,
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withOpacity(
                        0.88,
                      ),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    centerTitle: false,
                    titlePadding: const EdgeInsetsDirectional.only(
                      start: 0,
                      bottom: 14,
                      end: 12,
                    ),
                    title: AnimatedBuilder(
                      animation: _scrollController,
                      child: Hero(
                        tag: titleHeroTag,
                        flightShuttleBuilder:
                            (
                              flightContext,
                              animation,
                              flightDirection,
                              fromHeroContext,
                              toHeroContext,
                            ) {
                              return DefaultTextStyle.merge(
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ) ??
                                    const TextStyle(),
                                child: (toHeroContext.widget as Hero).child,
                              );
                            },
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            detail.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ),
                      builder: (context, child) {
                        final offset = _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                        final t = (offset / 84).clamp(0.0, 1.0);
                        final left = 8.0 + 48.0 * t;
                        return Padding(
                          padding: EdgeInsets.only(left: left),
                          child: child,
                        );
                      },
                    ),
                    background: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.10),
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _TopicMetaPill(
                                  icon: Icons.mode_comment_outlined,
                                  text: '${detail.replyCount}',
                                ),
                                _TopicMetaPill(
                                  icon: Icons.visibility_outlined,
                                  text: '${detail.viewCount}',
                                ),
                                _TopicMetaPill(
                                  icon: Icons.thumb_up_alt_outlined,
                                  text: '${detail.likeCount}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. 娑撴槒甯冨锝嗘瀮 (閸樺鍣搁敍姘垛偓娆掞紒娑撳秴鍟€鐏炴洜銇氬Ο娆擃攽閸滃矂鐗犻崓?
                SliverToBoxAdapter(
                  child: _SlideFadeTransition(
                    animation: _entranceController,
                    delay: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                      ), // 閸忋劌顕￠敍灞藉弾闁劍甯堕崚绂dding
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _showBackToTopButtonNotifier,
                        builder: (context, showFloatingReply, _) {
                          return _MainPostCard(
                            key: _keyForPostNumber(1),
                            detail: detail,
                            cookieHeader: cookieHeader,
                            emojiUrls: _emojiUrls,
                            onQuoteTap: _showQuoteBottomSheet,
                            isReacting: _reactingPostIds.contains(
                              detail.mainPost.id,
                            ),
                            onReactPressed: _onReactPressed,
                            onReplyPressed: (post) =>
                                _openReplyComposer(topicId: post.topicId),
                            onReactionStatusPressed: (post, reactionId) =>
                                _onReactionStatusPressed(
                                  post: post,
                                  reactionId: reactionId,
                                ),
                            onAuthorTap: _openAuthorProfileSheetForPost,
                            authorAvatarHeroTag: mainAuthorAvatarHeroTag,
                            authorNameHeroTag: mainAuthorNameHeroTag,
                            bodyRevealAnimation: _mainContentRevealAnimation(),
                            pendingHeroReactionId:
                                _pendingReactionHeroByPostId[detail
                                    .mainPost
                                    .id],
                            reactionPulseToken:
                                _reactionPulseTokenByPostId[detail
                                    .mainPost
                                    .id] ??
                                0,
                            showReplyAction: !showFloatingReply,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 3. 鐟洝鐝崡鈧?Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SectionHeaderDelegate(
                    title: _labelReplies,
                    count: detail.replyCount,
                    theme: theme,
                  ),
                ),

                // 4. 鐟洝鐝崚妤勩€?
                if (_comments.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.black12,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _labelNoComments,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = _comments[index];
                      final delay = (index * 30).clamp(0, 400);
                      final reveal = _commentRevealAnimation(index);

                      return FadeTransition(
                        opacity: reveal,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(reveal),
                          child: _SlideFadeTransition(
                            animation: _entranceController,
                            delay: 100 + delay,
                            child: Column(
                              children: [
                                _CommentCard(
                                  // 闁插秵顫愬宀€娈戠懎鏇＄彨鐞?
                                  key: _keyForPostNumber(post.postNumber),
                                  post: post,
                                  cookieHeader: cookieHeader,
                                  emojiUrls: _emojiUrls,
                                  onQuoteTap: _showQuoteBottomSheet,
                                  isReacting: _reactingPostIds.contains(
                                    post.id,
                                  ),
                                  onReactPressed: _onReactPressed,
                                  onTap: () => _openCommentDetail(post),
                                  onLongPress: () => _showCommentActions(post),
                                  onAuthorTap: _openAuthorProfileSheetForPost,
                                  onReplyPressed: (target) {
                                    _openReplyComposer(
                                      topicId: target.topicId,
                                      replyToPostNumber: target.postNumber,
                                      quoteUsername: target.authorUsername,
                                      quoteTopicId: target.topicId,
                                      quoteContent: _stripQuotedMarkdown(
                                        target.contentMarkdown,
                                      ),
                                    );
                                  },
                                  onReactionStatusPressed: (post, reactionId) =>
                                      _onReactionStatusPressed(
                                        post: post,
                                        reactionId: reactionId,
                                      ),
                                  heroTag: _commentHeroTag(post.id),
                                  pendingHeroReactionId:
                                      _pendingReactionHeroByPostId[post.id],
                                  reactionPulseToken:
                                      _reactionPulseTokenByPostId[post.id] ?? 0,
                                ),
                                // 閸掑棗澹婄欢?
                                if (index != _comments.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 60,
                                    ), // 鐏忓秹缍傞弬鍥х摟
                                    child: Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: theme.colorScheme.outlineVariant
                                          .withOpacity(0.4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: _comments.length),
                  ),

                // 5. 鎼存洟鍎?Loader
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator.adaptive()
                          : Text(
                              _hasMoreComments ? '' : _labelNoMoreReplies,
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 杩斿洖椤堕儴鎸夐挳
          ValueListenableBuilder<bool>(
            valueListenable: _showBackToTopButtonNotifier,
            builder: (context, visible, _) {
              return Positioned(
                right: 16,
                bottom: 28,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: visible ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: visible ? 1 : 0.84,
                    curve: Curves.easeOutBack,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visible) ...[
                          FloatingActionButton.small(
                            heroTag: 'reply_topic_fab_${detail.topicId}',
                            onPressed: () =>
                                _openReplyComposer(topicId: detail.topicId),
                            elevation: 2,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                            child: const Icon(Icons.reply_rounded),
                          ),
                          const SizedBox(height: 10),
                        ],
                        FloatingActionButton.small(
                          heroTag: 'back_to_top_fab',
                          onPressed: visible ? _scrollToTop : null,
                          elevation: 2,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 鏂拌瘎璁烘彁绀烘诞绐?
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: !_hasRealtimeCommentUpdate,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hasRealtimeCommentUpdate ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    offset: _hasRealtimeCommentUpdate
                        ? Offset.zero
                        : const Offset(0, -0.24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Material(
                          color: Colors.transparent,
                          child: Ink(
                            decoration: ShapeDecoration(
                              color: theme.colorScheme.surface.withOpacity(
                                0.78,
                              ),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withOpacity(0.45),
                                ),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withOpacity(
                                    0.08,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () async {
                                await _scrollToTop();
                                await _consumeRealtimeCommentUpdate();
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  6,
                                  10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mark_chat_unread_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '鏈夋柊璇勮',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '鐐瑰嚮鍒锋柊',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(width: 2),
                                    IconButton(
                                      tooltip: '鍏抽棴',
                                      onPressed: _dismissRealtimeCommentHint,
                                      icon: const Icon(Icons.close, size: 17),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicMetaPill extends StatelessWidget {
  const _TopicMetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.42),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 閸庮亜瀵插宀€娈戞稉鏄忓竷缁插嫪娆?(濞屽韫堝蹇ョ礉閻掆剝顬挎い宀勫櫢鐟?
// -----------------------------------------------------------------------------
class _SlideFadeTransition extends StatelessWidget {
  final AnimationController animation;
  final int delay;
  final Widget child;

  const _SlideFadeTransition({
    required this.animation,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 鐟峰牏鐣婚悾璺哄閸忓啰绀岄惃鍕珚閻ｎ偊鈧彃瀹?
        // 閸曟洜鏆欑缓鑺ユ闂€?800ms閿涘本鍨滈崐鎴濈殻閸忚埖妲х亸鍕煂 0.0 - 1.0
        // 濮ｅ繐鈧鍘撶槐鐘虫箒閸ュ搫鐣鹃惃鍕闁?(delay ms)
        final double delayInSeconds = delay / 1000.0;
        final double animationDurationInSeconds =
            animation.duration!.inMilliseconds / 1000.0;

        // 閸忓啰绀岄惃鍕珚閻ｎ偊鏋婃慨瀣闂佹捇绮?(0.0 - 1.0)
        final double start = (delayInSeconds / animationDurationInSeconds)
            .clamp(0.0, 0.8);
        // 閸忓啰绀岄惃鍕珚閻ｎ偅瀵旂痪灞炬闂?(娴ｆ梻闄勯弲鍌炴殾閻ㄥ嫭鐦笟?閿涘矂鈧瑨锛佺懛顓犲仱 0.4 (閸?30% ~ 40% 閻ㄥ嫭妾梺鎾舵暏娓氬棗鐣幋鎰窗閸?
        final double end = (start + 0.4).clamp(0.0, 1.0);

        final curve = CurvedAnimation(
          parent: animation,
          curve: Interval(start, end, curve: Curves.easeOutQuad),
        );

        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;
  final ThemeData theme;

  _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final opacity = (shrinkOffset / 12).clamp(0.92, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(opacity),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.title != title ||
        oldDelegate.theme != theme;
  }
}
