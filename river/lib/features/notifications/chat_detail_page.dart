import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/widgets/river_markdown_editor.dart';
import 'package:url_launcher/url_launcher.dart';

part 'chat_detail_page_actions.dart';
part 'chat_detail_page_view.dart';
part 'chat_detail_page_ui.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.dependencies,
    required this.channel,
  });

  final AppDependencies dependencies;
  final RiverSideChatChannelItem channel;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  static const List<String> _defaultReactionEmojiNames = <String>[
    '+1',
    'laughing',
    'heart',
    'open_mouth',
    'thinking',
    'anxious_face_with_sweat',
    'distorted_face',
    'saluting_face',
    'sob',
    '-1',
  ];

  static const Map<String, String> _fallbackReactionSymbols = <String, String>{
    '+1': '\u{1F44D}',
    '-1': '\u{1F44E}',
    'laughing': '\u{1F606}',
    'heart': '\u2764\uFE0F',
    'open_mouth': '\u{1F62E}',
    'thinking': '\u{1F914}',
    'anxious_face_with_sweat': '\u{1F605}',
    'distorted_face': '\u{1F635}',
    'saluting_face': '\u{1FAE1}',
    'sob': '\u{1F62D}',
  };

  static const String _labelNeedLogin =
      '\u8bf7\u5148\u767b\u5f55 RiverSide \u8d26\u53f7';
  static const String _labelLoadFailed =
      '\u6d88\u606f\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  static const String _labelSendFailed =
      '\u53d1\u9001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  static const String _labelNoMessages = '\u6682\u65e0\u6d88\u606f';
  static const String _labelNoMore =
      '\u6ca1\u6709\u66f4\u591a\u5386\u53f2\u6d88\u606f';
  static const String _labelMessageDeleted = '\u6d88\u606f\u5df2\u5220\u9664';
  static const String _labelRetry = '\u91cd\u8bd5';
  static const String _labelDelete = '\u5220\u9664';
  static const String _labelCancel = '\u53d6\u6d88';
  static const String _labelCopied = '\u5df2\u590d\u5236';
  static const String _labelDeleteSuccess = '\u6d88\u606f\u5df2\u5220\u9664';
  static const String _labelDeleteConfirm =
      '\u786e\u5b9a\u5220\u9664\u8fd9\u6761\u6d88\u606f\u5417\uff1f';
  static const String _labelReact = '\u56de\u5e94';
  static const String _labelReply = '\u56de\u590d';
  static const String _labelCopy = '\u590d\u5236\u5185\u5bb9';
  static const String _labelUnknownUser = '\u672a\u77e5\u7528\u6237';

  final ScrollController _scrollController = ScrollController();

  List<RiverSideChatMessageItem> _messages = const <RiverSideChatMessageItem>[];
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};
  bool _loadingInitial = true;
  bool _loadingOlder = false;
  bool _hasMorePast = true;
  bool _sending = false;
  String? _error;
  String? _lastActiveUsername;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _scrollController.addListener(_onScroll);
    _loadInitial(clearExisting: true);
    _loadEmojiData();
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) {
      return;
    }
    _lastActiveUsername = current;
    _loadInitial(clearExisting: true);
    _loadEmojiData();
  }

  void _onScroll() {
    if (_loadingInitial || _loadingOlder || !_hasMorePast) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.offset <= 120) {
      _loadOlderMessages();
    }
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  Map<String, String> _baseImageHeaders() {
    final cookie = _activeCookieHeader()?.trim() ?? '';
    if (cookie.isEmpty) {
      return const <String, String>{'Referer': riverSideBaseUrl};
    }
    return <String, String>{'Cookie': cookie, 'Referer': riverSideBaseUrl};
  }

  Map<String, String>? _headersForUrl(String resolvedUrl) {
    final headers = _baseImageHeaders();
    final forumHost = Uri.parse(riverSideBaseUrl).host.toLowerCase();
    final host = (Uri.tryParse(resolvedUrl)?.host ?? '').toLowerCase();

    if (host.isEmpty || host == forumHost || host.endsWith('.$forumHost')) {
      return headers;
    }

    final noCookie = <String, String>{};
    headers.forEach((key, value) {
      if (key.toLowerCase() == 'cookie') {
        return;
      }
      noCookie[key] = value;
    });
    return noCookie.isEmpty ? null : noCookie;
  }

  void _mutateState(VoidCallback action) {
    if (!mounted) {
      return;
    }
    setState(action);
  }

  Future<void> _loadEmojiData() async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final results = await Future.wait<dynamic>([
        api.fetchEmojiUrlMap(cookieHeader: cookie),
        api.fetchEmojiGroups(cookieHeader: cookie),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _emojiUrls =
            results[0] as Map<String, String>? ?? const <String, String>{};
        _emojiGroups =
            results[1] as Map<String, List<String>>? ??
            const <String, List<String>>{};
      });
    } catch (_) {
      // Keep chat page resilient when emoji API fails.
    }
  }

  Future<void> _loadInitial({required bool clearExisting}) async {
    final serial = ++_requestSerial;
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _hasMorePast = false;
        _error = _labelNeedLogin;
        if (clearExisting) {
          _messages = const <RiverSideChatMessageItem>[];
        }
      });
      return;
    }

    setState(() {
      _loadingInitial = true;
      _error = null;
      if (clearExisting) {
        _messages = const <RiverSideChatMessageItem>[];
      }
    });

    try {
      final page = await widget.dependencies.accountStore.riverSideApiClient
          .fetchChatChannelMessages(
            channelId: widget.channel.id,
            cookieHeader: cookie,
            fetchFromLastRead: true,
            pageSize: 50,
          );
      if (!mounted || serial != _requestSerial) {
        return;
      }

      setState(() {
        _messages = _mergeMessages(_messages, page.messages);
        _loadingInitial = false;
        _hasMorePast = page.canLoadMorePast;
        _error = null;
      });
      _jumpToBottom();
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _error = _labelLoadFailed;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _messages.isEmpty || !_hasMorePast) {
      return;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }

    final oldestId = _messages.first.id;
    if (oldestId <= 0) {
      return;
    }

    final beforePixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final beforeMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      _loadingOlder = true;
    });

    try {
      final page = await widget.dependencies.accountStore.riverSideApiClient
          .fetchChatChannelMessages(
            channelId: widget.channel.id,
            cookieHeader: cookie,
            fetchFromLastRead: false,
            pageSize: 50,
            targetMessageId: oldestId,
            direction: 'past',
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = _mergeMessages(_messages, page.messages);
        _hasMorePast = page.canLoadMorePast;
        _loadingOlder = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final afterMax = _scrollController.position.maxScrollExtent;
        final delta = afterMax - beforeMax;
        final target = beforePixels + (delta > 0 ? delta : 0);
        _scrollController.jumpTo(
          target.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOlder = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOlder = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_labelLoadFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage(context);
  }
}
