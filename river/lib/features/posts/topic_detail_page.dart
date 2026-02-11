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
// 甯搁噺鑸囧伐鍏峰嚱鏁?
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

String _formatTimeRelative(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${time.month}/${time.day}';
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
// 涓婚爜闈?
// -----------------------------------------------------------------------------

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
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};

  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasRealtimeCommentUpdate = false;
  RiverSideMessageBusPoller? _messageBusPoller;
  final ValueNotifier<bool> _showBackToTopButtonNotifier = ValueNotifier<bool>(
    false,
  );
  String? _error;

  // 鍏ュ牬鍕曠暙鎺у埗鍣?
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    // 鍒濆鍖栧嫊鐣帶鍒跺櫒
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scrollController.addListener(_onScroll);
    _restartRealtimePolling();
    _loadInitial();
  }

  @override
  void dispose() {
    _entranceController.dispose();
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
                  '鍥炲京 @${quote.ref.username} 鐨?#${quote.ref.postNumber}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 閷铏曠悊
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

    // Loading 鐙€鎱?
    if (_loadingInitial && _detail == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    // 瑙哥櫦鍏ュ牬鍕曠暙
    if (!_loadingInitial &&
        _entranceController.status == AnimationStatus.dismissed) {
      _entranceController.forward();
    }

    final cookieHeader = _activeCookieHeader();
    final avatarHeroTag =
        'avatar_${detail.topicId}_${detail.mainPost.authorUsername}';
    final titleHeroTag = 'title_${detail.topicId}';

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
                // 1. 娌夋蹈寮?Header (璨犺铂灞曠ず妯欓鍜屼綔鑰?
                SliverAppBar(
                  expandedHeight: 160.0, // 澧炲姞楂樺害浠ュ绱嶅琛屾椤?
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.colorScheme.surface,
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withOpacity(
                        0.6,
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    centerTitle: false, // 妯欓灞呭乏鏇寸鍚堥柋璁€缈掓叄
                    titlePadding: const EdgeInsetsDirectional.only(
                      start: 56, // 閬块枊杩斿洖鎸夐垥
                      bottom: 16,
                      end: 16,
                    ),
                    // 鏀惰捣鏅傜殑妯欓
                    title: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        detail.title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 鑳屾櫙瑁濋＞ (闋傞儴婕歌畩)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.08),
                                theme.colorScheme.surface,
                              ],
                            ),
                          ),
                        ),

                        // Hero 妯欓 (灞曢枊鏅傞’绀虹殑澶ф椤?
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 60, // 鐣欏嚭绌洪枔绲﹂牠鍍忚
                          child: Hero(
                            tag: titleHeroTag,
                            child: Material(
                              color: Colors.transparent,
                              child: SelectableText(
                                // 鍏佽ū瑜囪＝妯欓
                                detail.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  height: 1.3,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 3,
                              ),
                            ),
                          ),
                        ),

                        // Hero 闋儚鍜屼綔鑰呬俊鎭?(灞曢枊鏅傞’绀?
                        Positioned(
                          left: 20,
                          bottom: 20,
                          child: InkWell(
                            onTap: () =>
                                _openAuthorProfileSheetForPost(detail.mainPost),
                            borderRadius: BorderRadius.circular(20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Hero(
                                  tag: avatarHeroTag,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundImage:
                                        detail
                                            .mainPost
                                            .authorAvatarUrl
                                            .isNotEmpty
                                        ? NetworkImage(
                                            detail.mainPost.authorAvatarUrl,
                                          )
                                        : null,
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    child:
                                        detail.mainPost.authorAvatarUrl.isEmpty
                                        ? Text(
                                            detail.mainPost.authorDisplayName
                                                .substring(0, 1),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      detail.mainPost.authorDisplayName,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                    Text(
                                      _formatTimeRelative(detail.createdAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. 涓昏布姝ｆ枃 (鍘婚噸锛氶€欒！涓嶅啀灞曠ず妯欓鍜岄牠鍍?
                SliverToBoxAdapter(
                  child: _SlideFadeTransition(
                    animation: _entranceController,
                    delay: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                      ), // 鍏ㄥ锛屽収閮ㄦ帶鍒禤adding
                      child: _MainPostCard(
                        // 閲嶅懡鍚嶄甫閲嶆
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
                      ),
                    ),
                  ),
                ),

                // 3. 瑭曡珫鍗€ Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SectionHeaderDelegate(
                    title: _labelReplies,
                    count: detail.replyCount,
                    theme: theme,
                  ),
                ),

                // 4. 瑭曡珫鍒楄〃
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

                      return _SlideFadeTransition(
                        animation: _entranceController,
                        delay: 100 + delay,
                        child: Column(
                          children: [
                            _CommentCard(
                              // 閲嶆寰岀殑瑭曡珫琛?
                              key: _keyForPostNumber(post.postNumber),
                              post: post,
                              cookieHeader: cookieHeader,
                              emojiUrls: _emojiUrls,
                              onQuoteTap: _showQuoteBottomSheet,
                              isReacting: _reactingPostIds.contains(post.id),
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
                            ),
                            // 鍒嗗壊绶?
                            if (index != _comments.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 60,
                                ), // 灏嶉綂鏂囧瓧
                                child: Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: theme.colorScheme.outlineVariant
                                      .withOpacity(0.4),
                                ),
                              ),
                          ],
                        ),
                      );
                    }, childCount: _comments.length),
                  ),

                // 5. 搴曢儴 Loader
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

          // 鎳告诞鎸夐垥 - 鍥炲埌闋傞儴 (甯跺嫊鐣?
          ValueListenableBuilder<bool>(
            valueListenable: _showBackToTopButtonNotifier,
            builder: (context, visible, _) {
              final extraBottom = _hasRealtimeCommentUpdate ? 72.0 : 0.0;
              return Positioned(
                right: 16,
                bottom: 32 + extraBottom,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: visible ? 1 : 0,
                  curve: Curves.easeOutBack,
                  child: FloatingActionButton.small(
                    heroTag: 'back_to_top_fab',
                    onPressed: _scrollToTop,
                    elevation: 4,
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              );
            },
          ),

          // 鏂版秷鎭彁閱?
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                ignoring: !_hasRealtimeCommentUpdate,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  offset: _hasRealtimeCommentUpdate
                      ? Offset.zero
                      : const Offset(0, 1.5),
                  child: Card(
                    elevation: 8,
                    shadowColor: Colors.black12,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mark_chat_unread_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '有新评论，点击刷新',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _consumeRealtimeCommentUpdate,
                            child: const Text('刷新'),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: _dismissRealtimeCommentHint,
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
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

// -----------------------------------------------------------------------------
// 鍎寲寰岀殑涓昏布绲勪欢 (娌夋蹈寮忥紝鐒℃椤岄噸瑜?
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
        // 瑷堢畻鐣跺墠鍏冪礌鐨勫嫊鐣€插害
        // 鍕曠暙绺芥檪闀?800ms锛屾垜鍊戝皣鍏舵槧灏勫埌 0.0 - 1.0
        // 姣忓€嬪厓绱犳湁鍥哄畾鐨勫欢閬?(delay ms)
        final double controllerValue = animation.value;
        final double delayInSeconds = delay / 1000.0;
        final double animationDurationInSeconds =
            animation.duration!.inMilliseconds / 1000.0;

        // 鍏冪礌鐨勫嫊鐣枊濮嬫檪闁撻粸 (0.0 - 1.0)
        final double start = (delayInSeconds / animationDurationInSeconds)
            .clamp(0.0, 0.8);
        // 鍏冪礌鐨勫嫊鐣寔绾屾檪闁?(浣旂附鏅傞暦鐨勬瘮渚?锛岄€欒！瑷偤 0.4 (鍗?30% ~ 40% 鐨勬檪闁撶敤渚嗗畬鎴愭贰鍏?
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
    // 瑷堢畻鑳屾櫙閫忔槑搴?(鍚搁爞鏅傛洿涓嶉€忔槑)
    final double opacity = (shrinkOffset / 10).clamp(0.95, 1.0);

    return Container(
      color: theme.colorScheme.surface.withOpacity(opacity),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
