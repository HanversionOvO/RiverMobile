import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_message_bus_models.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/core/widgets/river_image_viewer.dart';
import 'package:river/core/widgets/river_markdown_editor.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
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
  static const String _chatGlobalRealtimeChannel = '/chat';
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
  static const String _labelReply = '\u56de\u590d';
  static const String _labelCopy = '\u590d\u5236\u5185\u5bb9';
  static const String _labelUnknownUser = '\u672a\u77e5\u7528\u6237';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController =
      _ChatComposerRichController();
  final FocusNode _composerFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final Set<int> _selectedMessageIds = <int>{};
  final Map<int, GlobalKey> _messageItemKeys = <int, GlobalKey>{};
  final GlobalKey _composerDockKey = GlobalKey();

  List<RiverSideChatMessageItem> _messages = const <RiverSideChatMessageItem>[];
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};
  bool _loadingInitial = true;
  bool _loadingOlder = false;
  bool _hasMorePast = true;
  bool _sending = false;
  bool _showScrollToBottom = false;
  bool _realtimeSyncing = false;
  bool _realtimeSyncPending = false;
  bool _selectionMode = false;
  bool _composerHasText = false;
  int _newMessageHintCount = 0;
  RiverSideChatMessageItem? _replyingMessage;
  double _composerDockHeight = 112;
  int? _pressedMessageId;
  Timer? _pressedMessageClearTimer;
  String? _error;
  String? _lastActiveUsername;
  int _requestSerial = 0;
  RiverSideMessageBusPoller? _messageBusPoller;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _scrollController.addListener(_onScroll);
    _composerController.addListener(_onComposerTextChanged);
    _composerFocusNode.addListener(_onComposerFocusChanged);
    _onComposerTextChanged();
    _loadInitial(clearExisting: true);
    _loadEmojiData();
    _restartRealtimePolling();
  }

  @override
  void dispose() {
    _messageBusPoller?.stop();
    _pressedMessageClearTimer?.cancel();
    _composerController.removeListener(_onComposerTextChanged);
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _composerController.dispose();
    _composerFocusNode.dispose();
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
    _messageBusPoller?.stop();
    _messageBusPoller = null;
    _selectedMessageIds.clear();
    _selectionMode = false;
    _loadInitial(clearExisting: true);
    _loadEmojiData();
    _restartRealtimePolling();
  }

  void _onScroll() {
    if (_scrollController.hasClients && mounted) {
      final position = _scrollController.position;
      final distanceToBottom = position.maxScrollExtent - position.pixels;
      if (distanceToBottom <= 120 && _newMessageHintCount > 0) {
        _newMessageHintCount = 0;
      }
      final shouldShow = distanceToBottom > 280 || _newMessageHintCount > 0;
      if (shouldShow != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    }

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

  void _onComposerTextChanged() {
    final hasText = _composerController.text.trim().isNotEmpty;
    if (!mounted || _composerHasText == hasText) {
      return;
    }
    setState(() {
      _composerHasText = hasText;
    });
  }

  void _onComposerFocusChanged() {
    if (!_composerFocusNode.hasFocus) {
      return;
    }
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 60),
        _scrollToBottomAnimated,
      ),
    );
  }

  void _markMessagePressed(int messageId) {
    _pressedMessageClearTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _pressedMessageId = messageId;
    });
    _pressedMessageClearTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _pressedMessageId != messageId) {
        return;
      }
      setState(() {
        _pressedMessageId = null;
      });
    });
  }

  GlobalKey _messageKeyFor(int messageId) {
    return _messageItemKeys.putIfAbsent(
      messageId,
      () => GlobalObjectKey('chat_msg_$messageId'),
    );
  }

  List<RiverSideChatMessageItem> _selectedMessagesOrdered() {
    if (_selectedMessageIds.isEmpty) {
      return const <RiverSideChatMessageItem>[];
    }
    final selected = _messages
        .where((item) => _selectedMessageIds.contains(item.id))
        .toList(growable: false);
    selected.sort((a, b) => a.id.compareTo(b.id));
    return selected;
  }

  void _enterSelectionModeWith(int messageId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(messageId);
      _showScrollToBottom = false;
    });
  }

  void _toggleSelectedMessage(int messageId) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    if (!mounted || !_selectionMode) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _jumpToMessageById(int messageId) async {
    if (messageId <= 0 || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);

    Future<bool> ensureVisible() async {
      final key = _messageItemKeys[messageId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
        if (!mounted) {
          return false;
        }
        _markMessagePressed(messageId);
        return true;
      }
      final index = _messages.indexWhere((item) => item.id == messageId);
      if (index < 0 || !_scrollController.hasClients) {
        return false;
      }
      final ratio = _messages.length <= 1
          ? 0.0
          : index / (_messages.length - 1);
      final target = _scrollController.position.maxScrollExtent * ratio;
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) {
        return false;
      }
      final retryCtx = _messageItemKeys[messageId]?.currentContext;
      if (retryCtx != null && retryCtx.mounted) {
        await Scrollable.ensureVisible(
          retryCtx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
        if (!mounted) {
          return false;
        }
        _markMessagePressed(messageId);
        return true;
      }
      return false;
    }

    if (_messages.any((item) => item.id == messageId)) {
      final ok = await ensureVisible();
      if (!ok && mounted) {
        messenger?.showSnackBar(const SnackBar(content: Text('未找到引用消息')));
      }
      return;
    }

    var safety = 0;
    while (mounted && _hasMorePast && safety < 12) {
      final before = _messages.length;
      await _loadOlderMessages();
      if (!mounted) {
        return;
      }
      if (_messages.any((item) => item.id == messageId)) {
        final ok = await ensureVisible();
        if (!ok && mounted) {
          messenger?.showSnackBar(const SnackBar(content: Text('未找到引用消息')));
        }
        return;
      }
      if (_messages.length == before) {
        break;
      }
      safety++;
    }

    if (!mounted) {
      return;
    }
    messenger?.showSnackBar(const SnackBar(content: Text('目标消息尚未加载')));
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 2) {
      return true;
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final threshold = math.max(260.0, _composerDockHeight + keyboard + 120);
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }

  void _setReplyingMessage(RiverSideChatMessageItem? item) {
    if (!mounted) {
      return;
    }
    setState(() {
      _replyingMessage = item;
    });
    _composerFocusNode.requestFocus();
  }

  Future<void> _consumeNewMessageHintAndScroll() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _newMessageHintCount = 0;
      _showScrollToBottom = false;
    });
    await _scrollToBottomAnimated();
  }

  void _updateComposerDockHeight(double value) {
    final next = value.isFinite ? value : 0.0;
    if (next <= 0) {
      return;
    }
    if ((next - _composerDockHeight).abs() < 0.8 || !mounted) {
      return;
    }
    setState(() {
      _composerDockHeight = next;
    });
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
      return <String, String>{'Referer': riverSideBaseUrl};
    }
    return <String, String>{'Cookie': cookie, 'Referer': riverSideBaseUrl};
  }

  Map<String, String>? _headersForUrl(String resolvedUrl) {
    final headers = _baseImageHeaders();
    final host = (Uri.tryParse(resolvedUrl)?.host ?? '').toLowerCase();
    if (host.isEmpty || isRiverSideHost(host)) {
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

  void _restartRealtimePolling() {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }

    final channelId = widget.channel.id;
    final channels = <String, int>{
      _chatGlobalRealtimeChannel: -1,
      '/chat/$channelId': -1,
      '/chat/$channelId/new-messages': -1,
    };
    final poller = RiverSideMessageBusPoller(
      apiClient: widget.dependencies.accountStore.riverSideApiClient,
      cookieHeader: cookie,
      channelLastIds: channels,
      onEvents: (events) {
        if (!mounted || events.isEmpty) {
          return;
        }
        final hasRelevant = events.any(_isRealtimeEventForCurrentChannel);
        if (hasRelevant) {
          _scheduleRealtimeSync();
        }
      },
    );
    _messageBusPoller = poller;
    poller.start();
  }

  bool _isRealtimeEventForCurrentChannel(RiverSideMessageBusEvent event) {
    final channel = event.channel.trim();
    if (channel.isEmpty) {
      return false;
    }
    final target = widget.channel.id;
    if (channel == '/chat/$target' ||
        channel == '/chat/$target/new-messages' ||
        channel.startsWith('/chat/$target/')) {
      return true;
    }
    if (channel == _chatGlobalRealtimeChannel) {
      final matched = _eventDataMatchesCurrentChannel(event.data);
      return matched ?? true;
    }
    if (!channel.startsWith('/chat/')) {
      return false;
    }
    final segments = channel.split('/');
    if (segments.length < 3) {
      return false;
    }
    final channelId = int.tryParse(segments[2]);
    return channelId != null && channelId == target;
  }

  bool? _eventDataMatchesCurrentChannel(dynamic raw) {
    final ids = <int>{};
    _collectChannelIds(raw, ids, depth: 0);
    if (ids.isEmpty) {
      return null;
    }
    return ids.contains(widget.channel.id);
  }

  void _collectChannelIds(dynamic raw, Set<int> out, {required int depth}) {
    if (depth > 6 || raw == null) {
      return;
    }
    if (raw is List) {
      for (final item in raw) {
        _collectChannelIds(item, out, depth: depth + 1);
      }
      return;
    }
    if (raw is Map) {
      raw.forEach((key, value) {
        final k = '$key'.toLowerCase();
        if (k == 'channel_id' ||
            k == 'chat_channel_id' ||
            k == 'channelid' ||
            k == 'chatchannelid') {
          final id = int.tryParse('$value');
          if (id != null && id > 0) {
            out.add(id);
          }
        }
        _collectChannelIds(value, out, depth: depth + 1);
      });
      return;
    }
    if (raw is String) {
      final source = raw.trim();
      if (source.isEmpty) {
        return;
      }
      if ((source.startsWith('{') && source.endsWith('}')) ||
          (source.startsWith('[') && source.endsWith(']'))) {
        try {
          final decoded = jsonDecode(source);
          _collectChannelIds(decoded, out, depth: depth + 1);
        } catch (_) {
          // Ignore invalid JSON payload fragments.
        }
      }
    }
  }

  void _scheduleRealtimeSync() {
    if (_realtimeSyncing) {
      _realtimeSyncPending = true;
      return;
    }
    _realtimeSyncPending = false;
    unawaited(_syncRealtimeLatestMessages());
  }

  Future<void> _syncRealtimeLatestMessages() async {
    if (_realtimeSyncing || !mounted) {
      return;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }
    _realtimeSyncing = true;
    try {
      do {
        _realtimeSyncPending = false;
        final wasNearBottom = _isNearBottomForRealtimeSync();
        final api = widget.dependencies.accountStore.riverSideApiClient;
        final latestId = _messages.isEmpty ? null : _messages.last.id;
        final firstPage = await api.fetchChatChannelMessages(
          channelId: widget.channel.id,
          cookieHeader: cookie,
          fetchFromLastRead: false,
          pageSize: 50,
          targetMessageId: latestId,
          direction: latestId == null ? null : 'future',
        );
        if (!mounted) {
          return;
        }

        var merged = _mergeMessages(_messages, firstPage.messages);
        var canLoadFuture = firstPage.canLoadMoreFuture;
        var safety = 0;
        while (canLoadFuture && merged.isNotEmpty && safety < 5) {
          final nextId = merged.last.id;
          final next = await api.fetchChatChannelMessages(
            channelId: widget.channel.id,
            cookieHeader: cookie,
            fetchFromLastRead: false,
            pageSize: 50,
            targetMessageId: nextId,
            direction: 'future',
          );
          if (!mounted) {
            return;
          }
          final beforeCount = merged.length;
          merged = _mergeMessages(merged, next.messages);
          canLoadFuture = next.canLoadMoreFuture && merged.length > beforeCount;
          if (next.messages.isEmpty) {
            break;
          }
          safety++;
        }

        if (!mounted) {
          return;
        }
        final hasChanged = merged.length != _messages.length;
        if (hasChanged) {
          final addedCount = merged.length > _messages.length
              ? merged.length - _messages.length
              : 0;
          setState(() {
            _messages = merged;
            _hasMorePast = _hasMorePast || firstPage.canLoadMorePast;
            if (wasNearBottom) {
              _newMessageHintCount = 0;
            } else if (addedCount > 0) {
              _newMessageHintCount += addedCount;
              _showScrollToBottom = true;
            }
          });
          if (wasNearBottom) {
            unawaited(_scrollToBottomAnimated());
          }
        }
      } while (_realtimeSyncPending && mounted);
    } catch (_) {
      // Keep realtime sync resilient; next poll event will retry.
    } finally {
      _realtimeSyncing = false;
    }
  }

  bool _isNearBottomForRealtimeSync() {
    return _isNearBottom();
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
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final page = await api.fetchChatChannelMessages(
        channelId: widget.channel.id,
        cookieHeader: cookie,
        fetchFromLastRead: false,
        pageSize: 50,
      );
      if (!mounted || serial != _requestSerial) {
        return;
      }

      var merged = _mergeMessages(_messages, page.messages);
      var canLoadPast = page.canLoadMorePast;
      var canLoadFuture = page.canLoadMoreFuture;
      var safety = 0;
      while (canLoadFuture && merged.isNotEmpty && safety < 5) {
        final latestId = merged.last.id;
        final futurePage = await api.fetchChatChannelMessages(
          channelId: widget.channel.id,
          cookieHeader: cookie,
          fetchFromLastRead: false,
          pageSize: 50,
          targetMessageId: latestId,
          direction: 'future',
        );
        if (!mounted || serial != _requestSerial) {
          return;
        }
        final beforeCount = merged.length;
        merged = _mergeMessages(merged, futurePage.messages);
        canLoadPast = canLoadPast || futurePage.canLoadMorePast;
        canLoadFuture =
            futurePage.canLoadMoreFuture && merged.length > beforeCount;
        if (futurePage.messages.isEmpty) {
          break;
        }
        safety++;
      }

      setState(() {
        _messages = merged;
        _loadingInitial = false;
        _hasMorePast = canLoadPast;
        _error = null;
        _newMessageHintCount = 0;
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
