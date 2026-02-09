// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/widgets/river_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const String _labelReplyNotReady =
      '\u56de\u590d\u529f\u80fd\u6682\u672a\u5b9e\u73b0';
  static const String _labelTargetFloorMissing =
      '\u76ee\u6807\u697c\u5c42\u5c1a\u672a\u52a0\u8f7d';
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

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _postItemKeys = <int, GlobalKey>{};

  RiverSideTopicDetail? _detail;
  List<RiverSideTopicPostDetail> _comments = const <RiverSideTopicPostDetail>[];
  final Set<int> _loadedPostIds = <int>{};
  Map<String, String> _emojiUrls = const <String, String>{};

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

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _error = null;
    });
    _showBackToTopButtonNotifier.value = false;

    try {
      final cookieHeader = _activeCookieHeader();
      final apiClient = widget.dependencies.accountStore.riverSideApiClient;
      final detailFuture = apiClient.fetchTopicDetail(
        topicId: widget.topicId,
        cookieHeader: cookieHeader,
      );
      final emojiFuture = apiClient
          .fetchEmojiUrlMap(cookieHeader: cookieHeader)
          .catchError((_) => const <String, String>{});
      final detail = await detailFuture;
      final emojiUrls = await emojiFuture;
      if (!mounted) {
        return;
      }

      final comments = [...detail.comments]
        ..sort((a, b) => a.postNumber.compareTo(b.postNumber));

      setState(() {
        _detail = detail;
        _comments = comments;
        _loadedPostIds
          ..clear()
          ..addAll(detail.loadedPostIds);
        _emojiUrls = emojiUrls;
        _loadingInitial = false;
      });
      _maybeAutoLoadMore();
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _error =
            '\u5e16\u5b50\u8be6\u60c5\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_loadingInitial || _loadingMore || !_hasMoreComments) {
      return;
    }
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final nextIds = _nextPostIdsToLoad();
    if (nextIds.isEmpty) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final posts = await widget.dependencies.accountStore.riverSideApiClient
          .fetchTopicPostsByIds(
            topicId: detail.topicId,
            postIds: nextIds,
            cookieHeader: _activeCookieHeader(),
          );
      if (!mounted) {
        return;
      }

      final merged = <RiverSideTopicPostDetail>[..._comments];
      final existingIds = merged.map((post) => post.id).toSet();
      for (final post in posts) {
        _loadedPostIds.add(post.id);
        if (post.postNumber <= 1 || existingIds.contains(post.id)) {
          continue;
        }
        existingIds.add(post.id);
        merged.add(post);
      }
      merged.sort((a, b) => a.postNumber.compareTo(b.postNumber));

      setState(() {
        _comments = merged;
        _loadingMore = false;
      });
      _maybeAutoLoadMore();
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u8bc4\u8bba\u52a0\u8f7d\u5931\u8d25')),
      );
    }
  }

  void _maybeAutoLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _loadingInitial ||
          _loadingMore ||
          !_hasMoreComments ||
          !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent <= position.viewportDimension * 0.15) {
        _loadMoreComments();
      }
    });
  }

  Future<void> _jumpToPostNumber({
    required int postNumber,
    required int topicId,
  }) async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    if (topicId != detail.topicId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_labelCrossTopicQuote)));
      return;
    }
    if (postNumber <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_labelInvalidQuoteFloor)));
      return;
    }

    var rounds = 0;
    while (mounted && rounds < 18) {
      rounds++;
      if (!_hasLoadedPostNumber(postNumber)) {
        if (!_hasMoreComments) {
          break;
        }
        await _loadMoreComments();
        continue;
      }

      final targetContext = await _findPostContext(postNumber);
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
        return;
      }

      await _waitNextFrame();
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_labelTargetFloorMissing)));
  }

  Future<BuildContext?> _findPostContext(int postNumber) async {
    for (var i = 0; i < 12; i++) {
      if (!mounted) {
        return null;
      }
      final key = _postItemKeys[postNumber];
      final targetContext = key?.currentContext;
      if (targetContext != null) {
        return targetContext;
      }
      await _scrollTowardPost(postNumber);
      await _waitNextFrame();
    }
    return null;
  }

  Future<void> _scrollTowardPost(int postNumber) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }

    final targetOffset = _estimateOffsetForPost(postNumber, maxExtent);
    final current = _scrollController.offset;
    if ((targetOffset - current).abs() < 12) {
      return;
    }

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  double _estimateOffsetForPost(int postNumber, double maxExtent) {
    final sortedNumbers = <int>[1, ..._comments.map((post) => post.postNumber)]
      ..sort();
    if (sortedNumbers.isEmpty) {
      return maxExtent;
    }
    final targetIndex = sortedNumbers.indexOf(postNumber);
    if (targetIndex <= 0) {
      return 0;
    }
    final denominator = sortedNumbers.length - 1;
    if (denominator <= 0) {
      return 0;
    }
    final ratio = targetIndex / denominator;
    return (maxExtent * ratio).clamp(0, maxExtent);
  }

  Future<void> _waitNextFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) {
      return;
    }
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  Future<void> _showQuoteBottomSheet(_QuoteBlock quote) async {
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
                  '\u56de\u590d @${quote.ref.username} 的 #${quote.ref.postNumber}',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: _MarkdownContent(
                      markdown: quote.contentMarkdown,
                      cookieHeader: _activeCookieHeader(),
                      emojiUrls: _emojiUrls,
                    ),
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
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(_labelReplyNotReady)),
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
          ?trailing,
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
  });

  final RiverSideTopicDetail detail;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;

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
    final post = widget.detail.mainPost;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostAuthorHeader(post: post),
            const SizedBox(height: 10),
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
          ],
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
  });

  final RiverSideTopicPostDetail post;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostAuthorHeader(post: widget.post),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _PostContent extends StatelessWidget {
  const _PostContent({
    required this.markdown,
    required this.topicId,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
  });

  final String markdown;
  final int topicId;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final blocks = _parsePostContentBlocks(markdown, topicId);
    if (blocks.isEmpty) {
      return const _MarkdownContent(
        markdown: _TopicDetailPageState._labelEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (blocks[i] is _MarkdownBlock)
            _MarkdownContent(
              markdown: (blocks[i] as _MarkdownBlock).markdown,
              cookieHeader: cookieHeader,
              emojiUrls: emojiUrls,
            )
          else
            _QuotePreviewCard(
              quote: blocks[i] as _QuoteBlock,
              onTap: () => onQuoteTap(blocks[i] as _QuoteBlock),
            ),
          if (i != blocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _QuotePreviewCard extends StatelessWidget {
  const _QuotePreviewCard({required this.quote, required this.onTap});

  final _QuoteBlock quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = _toPlainPreview(quote.contentMarkdown);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.reply_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u56de\u590d @${quote.ref.username} 的 #${quote.ref.postNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview.isEmpty
                          ? '\u67e5\u770b\u88ab\u56de\u590d\u5185\u5bb9'
                          : preview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  const _MarkdownContent({
    required this.markdown,
    this.cookieHeader,
    this.emojiUrls = const <String, String>{},
  });

  final String markdown;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;

  @override
  Widget build(BuildContext context) {
    final data = markdown.trim().isEmpty
        ? _TopicDetailPageState._labelEmpty
        : markdown;
    final headers = _buildImageHeaders(cookieHeader);
    final galleryItems = _buildMarkdownGalleryItems(
      markdown: data,
      headers: headers,
    );
    var imageBuilderIndex = 0;
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = textTheme.bodyMedium;
    return MarkdownBody(
      data: data,
      selectable: true,
      inlineSyntaxes: emojiUrls.isEmpty
          ? null
          : <md.InlineSyntax>[_EmojiInlineSyntax(emojiUrls)],
      builders: emojiUrls.isEmpty
          ? const <String, MarkdownElementBuilder>{}
          : <String, MarkdownElementBuilder>{
              'emoji': _EmojiBuilder(headers: headers),
            },
      sizedImageBuilder: (config) {
        final resolvedUrl = _resolveForumUrl('${config.uri}');
        final imageIndex = imageBuilderIndex++;
        final fallbackHeroTag = _buildMarkdownHeroTag(
          markdown: data,
          index: imageIndex,
          imageUrl: resolvedUrl,
        );
        final viewerItems = galleryItems.isNotEmpty
            ? galleryItems
            : <RiverImageViewerItem>[
                RiverImageViewerItem(
                  url: resolvedUrl,
                  headers: headers,
                  heroTag: fallbackHeroTag,
                ),
              ];
        final initialIndex = galleryItems.isNotEmpty
            ? _resolveGalleryInitialIndex(
                items: galleryItems,
                url: resolvedUrl,
                preferredIndex: imageIndex,
              )
            : 0;

        return _MarkdownImage(
          url: resolvedUrl,
          headers: headers,
          viewerItems: viewerItems,
          initialIndex: initialIndex,
          heroTag: viewerItems[initialIndex].heroTag,
        );
      },
      onTapLink: (_, href, _) {
        _openLink(href == null ? null : _resolveForumUrl(href));
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        blockquote: baseStyle?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _openLink(String? href) async {
    final raw = href?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MarkdownImage extends StatefulWidget {
  const _MarkdownImage({
    required this.url,
    this.headers,
    required this.viewerItems,
    required this.initialIndex,
    required this.heroTag,
  });

  final String url;
  final Map<String, String>? headers;
  final List<RiverImageViewerItem> viewerItems;
  final int initialIndex;
  final String heroTag;

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  bool _retryWithoutCookie = false;
  bool _fallbackToDirectImage = false;

  @override
  Widget build(BuildContext context) {
    final baseHeaders = _headersForImageUrl(widget.url, widget.headers);
    final hasCookie = (baseHeaders?['Cookie'] ?? '').trim().isNotEmpty;
    final requestHeaders = _retryWithoutCookie
        ? _stripCookieHeader(baseHeaders)
        : baseHeaders;

    final image = _fallbackToDirectImage
        ? _buildDirectImage(context, requestHeaders, hasCookie)
        : _buildCachedImage(context, requestHeaders, hasCookie);

    return GestureDetector(
      onTap: () => _openPreview(requestHeaders),
      child: Hero(tag: widget.heroTag, child: image),
    );
  }

  void _openPreview(Map<String, String>? headers) {
    final items = List<RiverImageViewerItem>.from(widget.viewerItems);
    if (widget.initialIndex >= 0 && widget.initialIndex < items.length) {
      final current = items[widget.initialIndex];
      final effectiveHeaders = headers ?? current.headers;
      items[widget.initialIndex] = RiverImageViewerItem(
        url: current.url,
        headers: effectiveHeaders,
        heroTag: current.heroTag,
        imageProvider: _buildPreviewImageProvider(effectiveHeaders),
      );
    }

    RiverImageViewerPage.open(
      context,
      items: items,
      initialIndex: widget.initialIndex,
    );
  }

  ImageProvider<Object> _buildPreviewImageProvider(
    Map<String, String>? headers,
  ) {
    if (_fallbackToDirectImage) {
      return NetworkImage(widget.url, headers: headers);
    }
    return CachedNetworkImageProvider(
      widget.url,
      headers: headers,
      cacheKey: _buildImageCacheKey(widget.url, headers),
    );
  }

  Widget _buildCachedImage(
    BuildContext context,
    Map<String, String>? requestHeaders,
    bool hasCookie,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: widget.url,
        httpHeaders: requestHeaders,
        cacheKey: _buildImageCacheKey(widget.url, requestHeaders),
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => _buildLoadingPlaceholder(context),
        errorWidget: (context, url, error) {
          if (!_retryWithoutCookie && hasCookie) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _retryWithoutCookie = true;
              });
            });
            return _buildLoadingPlaceholder(context);
          }
          if (!_fallbackToDirectImage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _fallbackToDirectImage = true;
              });
            });
            return _buildLoadingPlaceholder(context);
          }
          return _buildErrorPlaceholder(context);
        },
      ),
    );
  }

  Widget _buildDirectImage(
    BuildContext context,
    Map<String, String>? headers,
    bool hasCookie,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        widget.url,
        headers: headers,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _buildLoadingPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) {
          if (!_retryWithoutCookie && hasCookie) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _retryWithoutCookie = true;
                _fallbackToDirectImage = true;
              });
            });
            return _buildLoadingPlaceholder(context);
          }
          return _buildErrorPlaceholder(context);
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(height: 6),
          Text(
            '\u56fe\u7247\u52a0\u8f7d\u5931\u8d25',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({required this.post});

  final RiverSideTopicPostDetail post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final onlineState = _onlineStateText(post.isOnline);
    final onlineColor = _onlineStateColor(post.isOnline, context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: post.authorAvatarUrl.isEmpty
              ? null
              : NetworkImage(post.authorAvatarUrl),
          child: post.authorAvatarUrl.isEmpty
              ? const Icon(Icons.person_outline)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorDisplayName,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 9, color: onlineColor),
                      const SizedBox(width: 4),
                      Text(
                        onlineState,
                        style: textTheme.bodySmall?.copyWith(
                          color: onlineColor,
                        ),
                      ),
                    ],
                  ),
                  if (post.authorTitle.isNotEmpty)
                    Text(
                      post.authorTitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  Text(
                    '@${post.authorUsername}',
                    style: textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

abstract class _PostContentBlock {
  const _PostContentBlock();
}

class _MarkdownBlock extends _PostContentBlock {
  const _MarkdownBlock(this.markdown);

  final String markdown;
}

class _QuoteBlock extends _PostContentBlock {
  const _QuoteBlock({required this.ref, required this.contentMarkdown});

  final _QuoteRef ref;
  final String contentMarkdown;
}

class _QuoteRef {
  const _QuoteRef({
    required this.username,
    required this.topicId,
    required this.postNumber,
  });

  final String username;
  final int topicId;
  final int postNumber;
}

List<_PostContentBlock> _parsePostContentBlocks(String source, int topicId) {
  final content = source.trim();
  if (content.isEmpty) {
    return const <_PostContentBlock>[];
  }

  final matches = RegExp(
    r'\[quote="([^"]+)"\]([\s\S]*?)\[/quote\]',
    caseSensitive: false,
  ).allMatches(content);

  if (matches.isEmpty) {
    return <_PostContentBlock>[_MarkdownBlock(content)];
  }

  final blocks = <_PostContentBlock>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      final markdown = content.substring(cursor, match.start).trim();
      if (markdown.isNotEmpty) {
        blocks.add(_MarkdownBlock(markdown));
      }
    }

    final header = (match.group(1) ?? '').trim();
    final quoted = (match.group(2) ?? '').trim();
    blocks.add(
      _QuoteBlock(
        ref: _parseQuoteRef(header, topicId),
        contentMarkdown: quoted,
      ),
    );
    cursor = match.end;
  }

  if (cursor < content.length) {
    final markdown = content.substring(cursor).trim();
    if (markdown.isNotEmpty) {
      blocks.add(_MarkdownBlock(markdown));
    }
  }

  return blocks;
}

_QuoteRef _parseQuoteRef(String header, int fallbackTopicId) {
  var username = _TopicDetailPageState._labelUnknownUser;
  final parts = header.split(',');
  if (parts.isNotEmpty) {
    final first = parts.first.trim();
    if (first.isNotEmpty && !first.contains(':')) {
      username = first;
    }
  }

  final postNumber =
      _firstInt(RegExp(r'post:\s*(\d+)', caseSensitive: false), header) ?? 0;
  final topicId =
      _firstInt(RegExp(r'topic:\s*(\d+)', caseSensitive: false), header) ??
      fallbackTopicId;

  return _QuoteRef(
    username: username,
    topicId: topicId,
    postNumber: postNumber,
  );
}

int? _firstInt(RegExp pattern, String source) {
  final match = pattern.firstMatch(source);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

String _toPlainPreview(String markdown) {
  return markdown
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      .replaceAll(RegExp(r'[`*_>#-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _EmojiInlineSyntax extends md.InlineSyntax {
  _EmojiInlineSyntax(this.emojiUrls) : super(r':([a-zA-Z0-9_+\-]+):');

  final Map<String, String> emojiUrls;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final key = (match.group(1) ?? '').trim();
    if (key.isEmpty) {
      return false;
    }
    final url = emojiUrls[key] ?? emojiUrls[key.toLowerCase()];
    if (url == null || url.isEmpty) {
      return false;
    }

    final element = md.Element.text('emoji', key);
    element.attributes['data-url'] = url;
    parser.addNode(element);
    return true;
  }
}

class _EmojiBuilder extends MarkdownElementBuilder {
  _EmojiBuilder({required this.headers});

  final Map<String, String>? headers;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final url = (element.attributes['data-url'] ?? '').trim();
    if (url.isEmpty) {
      return Text(':${element.textContent}:', style: preferredStyle);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: CachedNetworkImage(
        imageUrl: _resolveForumUrl(url),
        httpHeaders: headers,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (context, imageUrl, error) =>
            Text(':${element.textContent}:', style: preferredStyle),
      ),
    );
  }
}

Map<String, String>? _buildImageHeaders(String? cookieHeader) {
  final cookie = cookieHeader?.trim();
  if (cookie == null || cookie.isEmpty) {
    return const <String, String>{'Referer': riverSideBaseUrl};
  }
  return <String, String>{'Cookie': cookie, 'Referer': riverSideBaseUrl};
}

Map<String, String>? _headersForImageUrl(
  String url,
  Map<String, String>? headers,
) {
  if (headers == null || headers.isEmpty) {
    return headers;
  }
  final uri = Uri.tryParse(url);
  final host = (uri?.host ?? '').trim().toLowerCase();
  if (host.isEmpty ||
      host == 'river-side.cc' ||
      host.endsWith('.river-side.cc')) {
    return headers;
  }
  return null;
}

Map<String, String>? _stripCookieHeader(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) {
    return headers;
  }
  final next = <String, String>{};
  headers.forEach((key, value) {
    if (key.toLowerCase() == 'cookie') {
      return;
    }
    next[key] = value;
  });
  return next.isEmpty ? null : next;
}

String _buildImageCacheKey(String url, Map<String, String>? headers) {
  final cookie = (headers?['Cookie'] ?? '').trim();
  if (cookie.isEmpty) {
    return url;
  }
  return '$url#auth';
}

List<RiverImageViewerItem> _buildMarkdownGalleryItems({
  required String markdown,
  required Map<String, String>? headers,
}) {
  final rawUrls = _extractMarkdownImageUrls(markdown);
  if (rawUrls.isEmpty) {
    return const <RiverImageViewerItem>[];
  }

  final items = <RiverImageViewerItem>[];
  for (var i = 0; i < rawUrls.length; i++) {
    final resolved = _resolveForumUrl(rawUrls[i]);
    if (resolved.isEmpty) {
      continue;
    }
    items.add(
      RiverImageViewerItem(
        url: resolved,
        headers: _headersForImageUrl(resolved, headers),
        heroTag: _buildMarkdownHeroTag(
          markdown: markdown,
          index: i,
          imageUrl: resolved,
        ),
      ),
    );
  }
  return items;
}

int _resolveGalleryInitialIndex({
  required List<RiverImageViewerItem> items,
  required String url,
  required int preferredIndex,
}) {
  if (items.isEmpty) {
    return 0;
  }
  if (preferredIndex >= 0 &&
      preferredIndex < items.length &&
      items[preferredIndex].url == url) {
    return preferredIndex;
  }

  for (var i = preferredIndex; i < items.length; i++) {
    if (items[i].url == url) {
      return i;
    }
  }
  for (var i = 0; i < preferredIndex && i < items.length; i++) {
    if (items[i].url == url) {
      return i;
    }
  }
  if (preferredIndex < 0) {
    return 0;
  }
  if (preferredIndex >= items.length) {
    return items.length - 1;
  }
  return preferredIndex;
}

String _buildMarkdownHeroTag({
  required String markdown,
  required int index,
  required String imageUrl,
}) {
  return 'topic-md-gallery-${markdown.hashCode}-$index-${imageUrl.hashCode}';
}

List<String> _extractMarkdownImageUrls(String markdown) {
  if (markdown.trim().isEmpty) {
    return const <String>[];
  }

  final urls = <String>[];
  final pattern = RegExp(
    r'''!\[[^\]]*\]\(([^)]+)\)|<img[^>]+src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(markdown)) {
    var raw = (match.group(1) ?? match.group(2) ?? '').trim();
    if (raw.isEmpty) {
      continue;
    }

    if (raw.startsWith('<') && raw.endsWith('>') && raw.length > 2) {
      raw = raw.substring(1, raw.length - 1).trim();
    }
    final spaceIndex = raw.indexOf(RegExp(r'\s'));
    if (spaceIndex > 0) {
      raw = raw.substring(0, spaceIndex).trim();
    }
    if (raw.isEmpty) {
      continue;
    }
    urls.add(raw);
  }

  return urls;
}

String _resolveForumUrl(String source) {
  final raw = source.trim();
  if (raw.isEmpty) {
    return raw;
  }

  if (raw.startsWith('upload://')) {
    final short = raw.substring('upload://'.length);
    return '$riverSideBaseUrl/uploads/short-url/$short';
  }

  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return raw;
  }
  if (uri.hasScheme) {
    return raw;
  }
  if (raw.startsWith('//')) {
    return 'https:$raw';
  }
  if (raw.startsWith('/')) {
    return '$riverSideBaseUrl$raw';
  }
  return '$riverSideBaseUrl/$raw';
}

String _onlineStateText(bool? isOnline) {
  if (isOnline == null) {
    return _TopicDetailPageState._labelUnknownState;
  }
  return isOnline
      ? _TopicDetailPageState._labelOnline
      : _TopicDetailPageState._labelOffline;
}

Color _onlineStateColor(bool? isOnline, BuildContext context) {
  if (isOnline == null) {
    return Theme.of(context).colorScheme.outline;
  }
  return isOnline ? Colors.green : Theme.of(context).colorScheme.outline;
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '--';
  }

  final local = value.toLocal();
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
