// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_message_bus_models.dart';
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
// 閻㈩垱鎮傞崳娲嚋閸パ傜矗闁稿繐鍢查崵閬嶅极?
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
// 濞戞挸顭烽悥婊堟?
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
  int? _jumpHighlightPostNumber;
  int _jumpHighlightToken = 0;
  Timer? _jumpHighlightClearTimer;
  bool _skipNextEntranceAnimation = false;
  RiverSideMessageBusPoller? _messageBusPoller;
  int _pollingBootstrapSerial = 0;
  final ValueNotifier<bool> _showBackToTopButtonNotifier = ValueNotifier<bool>(
    false,
  );
  String? _error;
  bool _presenceReady = false;
  final Set<int> _onlineUserIds = <int>{};
  final Set<String> _onlineUsernames = <String>{};
  final Map<int, String> _knownOnlineUsernameById = <int, String>{};

  // 闁稿繈鍎遍悧顒勫礋閺囩姵娈柟璨夊啫鐓戦柛?
  late AnimationController _entranceController;
  late AnimationController _contentRevealController;

  @override
  void initState() {
    super.initState();
    // 闁告帗绻傞～鎰板礌閺嵮冪彋闁伙綆鍋呯敮鍫曞礆鐠虹儤鐝?
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );

    widget.dependencies.settingsController.addListener(
      _onRefreshBannerSettingsChanged,
    );
    _scrollController.addListener(_onScroll);
    _restartRealtimePolling();
    _loadInitial();
  }

  @override
  void dispose() {
    _jumpHighlightClearTimer?.cancel();
    _entranceController.dispose();
    _contentRevealController.dispose();
    _messageBusPoller?.stop();
    widget.dependencies.settingsController.removeListener(
      _onRefreshBannerSettingsChanged,
    );
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showBackToTopButtonNotifier.dispose();
    super.dispose();
  }

  bool get _showTopicCommentsRealtimeRefreshBanner {
    return widget
        .dependencies
        .settingsController
        .showTopicCommentsRealtimeRefreshBanner;
  }

  void _onRefreshBannerSettingsChanged() {
    if (!mounted) {
      return;
    }
    if (!_showTopicCommentsRealtimeRefreshBanner && _hasRealtimeCommentUpdate) {
      _mutateState(() {
        _hasRealtimeCommentUpdate = false;
      });
      return;
    }
    _mutateState(() {});
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.97, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.98),
                elevation: 14,
                shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.format_quote_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '回复 @${quote.ref.username} 的 #${quote.ref.postNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '查看完整被回复内容',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                SizedBox(width: 10),
                                                Text(_labelQuoteLoading),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      if (snapshot.hasError) {
                                        return SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _labelQuoteLoadFailed,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .error,
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(sheetContext).pop();
                                await _jumpToPostNumber(
                                  postNumber: quote.ref.postNumber,
                                  topicId: quote.ref.topicId,
                                );
                              },
                              icon: const Icon(Icons.numbers_rounded, size: 18),
                              label: const Text(_labelJumpToFloor),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
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
                              icon: const Icon(Icons.reply_rounded, size: 18),
                              label: const Text(_labelReplyContent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

  void _triggerJumpHighlight(int postNumber) {
    _jumpHighlightClearTimer?.cancel();
    _mutateState(() {
      _jumpHighlightPostNumber = postNumber;
      _jumpHighlightToken++;
    });
    _jumpHighlightClearTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _jumpHighlightPostNumber != postNumber) {
        return;
      }
      _mutateState(() {
        _jumpHighlightPostNumber = null;
      });
    });
  }

  Future<void> _onRealtimeCommentHintTap() async {
    await _consumeRealtimeCommentUpdate();
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
                backgroundColor: theme.colorScheme.surface.withValues(
                  alpha: 0.88,
                ),
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
                      theme.colorScheme.primary.withValues(alpha: 0.10),
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

    // 闂佸鍨甸鍐惞閺囩姵鍊?
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

    // Loading 闁绘瑢鍋撻柟?
    if (_loadingInitial && _detail == null) {
      return _buildInitialLoadingView(theme);
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    // 閻熸瑥鎽滃▍锕傚礂閵夈儳澹冮柛鏇熸礈閺?
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
                      backgroundColor: theme.colorScheme.surface.withValues(
                        alpha: 0.88,
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
                            theme.colorScheme.primary.withValues(alpha: 0.10),
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

                // Main post section.
                SliverToBoxAdapter(
                  child: _SlideFadeTransition(
                    animation: _entranceController,
                    delay: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
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
                            isJumpHighlighted: _jumpHighlightPostNumber == 1,
                            jumpHighlightToken: _jumpHighlightPostNumber == 1
                                ? _jumpHighlightToken
                                : 0,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 3. 閻燁厽娲濋悵顐﹀础閳?Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SectionHeaderDelegate(
                    title: _labelReplies,
                    count: detail.replyCount,
                    theme: theme,
                    showRealtimeHint:
                        _showTopicCommentsRealtimeRefreshBanner &&
                        _hasRealtimeCommentUpdate,
                    onRealtimeHintTap: _onRealtimeCommentHintTap,
                    onRealtimeHintClose: _dismissRealtimeCommentHint,
                  ),
                ),

                // 4. 閻燁厽娲濋悵顐﹀礆濡ゅ嫨鈧?
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
                                  // 闂佹彃绉甸～鎰嚗瀹€鈧▓鎴犳噹閺囷紕褰ㄩ悶?
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
                                  isJumpHighlighted:
                                      _jumpHighlightPostNumber ==
                                      post.postNumber,
                                  jumpHighlightToken:
                                      _jumpHighlightPostNumber ==
                                          post.postNumber
                                      ? _jumpHighlightToken
                                      : 0,
                                ),
                                // 闁告帒妫楁竟濠勬?
                                if (index != _comments.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 60,
                                    ), // 閻忓繐绉圭紞鍌炲棘閸パ呮憻
                                    child: Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: _comments.length),
                  ),

                // 5. 底部加载/结束提示（空评论时不重复显示“没有更多评论了”）
                if (_comments.isNotEmpty || _loadingMore)
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

          // Floating actions.
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
        color: theme.colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Simple slide + fade transition wrapper.
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
        // Delay-aware normalized progress for staggered animations.
        final double delayInSeconds = delay / 1000.0;
        final double animationDurationInSeconds =
            animation.duration!.inMilliseconds / 1000.0;

        // 闁稿繐鍟扮粈宀勬儍閸曨偄鐝氶柣锝庡亰閺嬪﹥鎱ㄧ€ｎ偅顎夐梻浣规崌缁?(0.0 - 1.0)
        final double start = (delayInSeconds / animationDurationInSeconds)
            .clamp(0.0, 0.8);
        // 闁稿繐鍟扮粈宀勬儍閸曨偄鐝氶柣锝庡亝鐎垫梻鐥仦鐐€夐梻?(濞达絾姊婚梽鍕疾閸岀偞娈鹃柣銊ュ閻︻喗绗?闁挎稑鐭傞埀顒佺懆閿涗胶鎳涢鐘蹭槐 0.4 (闁?30% ~ 40% 闁汇劌瀚顏堟⒑閹捐埖鏆忓〒姘閻ｎ剟骞嬮幇顓＄獥闁?
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
  final bool showRealtimeHint;
  final VoidCallback? onRealtimeHintTap;
  final VoidCallback? onRealtimeHintClose;

  _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.theme,
    this.showRealtimeHint = false,
    this.onRealtimeHintTap,
    this.onRealtimeHintClose,
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
        color: theme.colorScheme.surface.withValues(alpha: opacity),
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
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.5,
              ),
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
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: showRealtimeHint
                ? Container(
                    key: const ValueKey<String>('realtime-comment-hint'),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onRealtimeHintTap,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_new_rounded,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '有新评论',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onRealtimeHintClose,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.7,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey<String>('realtime-comment-hint-empty'),
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
        oldDelegate.theme != theme ||
        oldDelegate.showRealtimeHint != showRealtimeHint;
  }
}
