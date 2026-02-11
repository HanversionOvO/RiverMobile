part of 'topic_detail_page.dart';

class CommentDetailPage extends StatefulWidget {
  const CommentDetailPage({
    super.key,
    required this.dependencies,
    required this.rootPost,
    required this.heroTag,
    this.initialEmojiUrls = const <String, String>{},
    this.initialEmojiGroups = const <String, List<String>>{},
  });

  final AppDependencies dependencies;
  final RiverSideTopicPostDetail rootPost;
  final String heroTag;
  final Map<String, String> initialEmojiUrls;
  final Map<String, List<String>> initialEmojiGroups;

  @override
  State<CommentDetailPage> createState() => _CommentDetailPageState();
}

class _CommentDetailPageState extends State<CommentDetailPage> {
  static const String _labelTitle = '\u8bc4\u8bba\u8be6\u60c5';
  static const String _labelRootComment = '\u8be5\u8bc4\u8bba';
  static const String _labelReplies = '\u56de\u590d\u8be5\u8bc4\u8bba';
  static const String _labelEmptyReplies = '\u6682\u65e0\u56de\u590d';
  static const String _labelQuoteTitle = '\u88ab\u56de\u590d\u5185\u5bb9';
  static const String _labelReload = '\u91cd\u8bd5';
  static const String _labelReplyNeedLogin =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';
  static const String _labelReplySuccess =
      '\u56de\u590d\u53d1\u5e03\u6210\u529f';
  static const String _labelEditCommentTitle =
      _TopicDetailPageState._labelEditCommentTitle;
  static const String _labelEditCommentSuccess =
      _TopicDetailPageState._labelEditCommentSuccess;
  static const String _labelDeleteCommentTitle =
      _TopicDetailPageState._labelDeleteCommentTitle;
  static const String _labelDeleteCommentHint =
      _TopicDetailPageState._labelDeleteCommentHint;
  static const String _labelDeleteCommentSuccess =
      _TopicDetailPageState._labelDeleteCommentSuccess;
  static const String _labelActionCopyContent =
      _TopicDetailPageState._labelActionCopyContent;
  static const String _labelActionEditComment =
      _TopicDetailPageState._labelActionEditComment;
  static const String _labelActionDeleteComment =
      _TopicDetailPageState._labelActionDeleteComment;
  static const String _labelSave = _TopicDetailPageState._labelSave;
  static const String _labelCancel = _TopicDetailPageState._labelCancel;
  static const String _labelDelete = _TopicDetailPageState._labelDelete;

  late RiverSideTopicPostDetail _rootPost;
  List<RiverSideTopicPostDetail> _replies = const <RiverSideTopicPostDetail>[];
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};
  final Set<int> _reactingPostIds = <int>{};
  final Map<int, String> _pendingReactionHeroByPostId = <int, String>{};
  final Map<int, int> _reactionPulseTokenByPostId = <int, int>{};
  bool _loading = true;
  bool _hasMutations = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rootPost = widget.rootPost;
    _emojiUrls = widget.initialEmojiUrls;
    _emojiGroups = widget.initialEmojiGroups;
    _loadData();
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cookieHeader = _activeCookieHeader();
      final apiClient = widget.dependencies.accountStore.riverSideApiClient;
      final repliesFuture = apiClient.fetchPostReplies(
        topicId: _rootPost.topicId,
        postId: _rootPost.id,
        cookieHeader: cookieHeader,
      );
      final emojiFuture = _emojiUrls.isNotEmpty
          ? Future<Map<String, String>>.value(_emojiUrls)
          : apiClient
                .fetchEmojiUrlMap(cookieHeader: cookieHeader)
                .catchError((_) => const <String, String>{});
      final emojiGroupsFuture = _emojiGroups.isNotEmpty
          ? Future<Map<String, List<String>>>.value(_emojiGroups)
          : apiClient
                .fetchEmojiGroups(cookieHeader: cookieHeader)
                .catchError((_) => const <String, List<String>>{});

      final repliesRaw = await repliesFuture;
      final replies = <RiverSideTopicPostDetail>[];
      final replyIds = <int>{};
      for (final item in repliesRaw) {
        if (!replyIds.add(item.id) || item.id == _rootPost.id) {
          continue;
        }
        replies.add(item);
      }
      final emojiUrls = await emojiFuture;
      final emojiGroups = await emojiGroupsFuture;
      if (!mounted) {
        return;
      }

      setState(() {
        _replies = replies;
        _emojiUrls = emojiUrls;
        _emojiGroups = emojiGroups;
        _loading = false;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '\u8bc4\u8bba\u8be6\u60c5\u52a0\u8f7d\u5931\u8d25';
      });
    }
  }

  Future<void> _onRefresh() => _loadData();

  void _mutateState(VoidCallback action) {
    if (!mounted) {
      return;
    }
    setState(action);
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage(context);
  }
}
