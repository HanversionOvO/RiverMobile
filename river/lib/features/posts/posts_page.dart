import 'dart:async';
import 'dart:convert';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/categories/riverside_category_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_message_bus_models.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/realtime/riverside_message_bus_poller.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
import 'package:river/features/search/search_page.dart';
import 'package:river/core/widgets/riverside_category_picker_sheet.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

// -----------------------------------------------------------------------------

part 'posts_page_widgets.dart';

// -----------------------------------------------------------------------------
class PostsPageController {
  _PostsPageState? _state;

  void _attach(_PostsPageState state) {
    _state = state;
  }

  void _detach(_PostsPageState state) {
    if (_state == state) {
      _state = null;
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    await _state?._scrollToTopAndRefresh();
  }
}

// -----------------------------------------------------------------------------

class _PostsSecondFloorLayer extends StatelessWidget {
  const _PostsSecondFloorLayer({
    required this.progress,
    required this.feedLabel,
    required this.bottomBarHeight,
    required this.bottomNavigationReserveHeight,
    required this.interactive,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double progress;
  final String feedLabel;
  final double bottomBarHeight;
  final double bottomNavigationReserveHeight;
  final bool interactive;
  final Future<void> Function() onClose;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final t = progress.clamp(0.0, 1.0);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;
    final panelHeight = (media.size.height * t).clamp(0.0, media.size.height);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !interactive,
            child: Container(
              color: Colors.black.withValues(alpha: lerpDouble(0.0, 0.34, t)!),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            ignoring: !interactive,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: SizedBox(
                width: double.infinity,
                height: panelHeight,
                child: ClipRect(
                  child: Material(
                    color: theme.colorScheme.surface,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.surfaceContainerLowest,
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topInset + 10,
                              12,
                              12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '二楼',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  feedLabel,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: '关闭',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onClose,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.smart_toy_outlined,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'AI 智能体专区（预留）',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '快捷入口',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: const [
                                    _SecondFloorQuickChip(
                                      icon: Icons.bookmark_border_rounded,
                                      label: '收藏',
                                    ),
                                    _SecondFloorQuickChip(
                                      icon: Icons.history_rounded,
                                      label: '浏览记录',
                                    ),
                                    _SecondFloorQuickChip(
                                      icon:
                                          Icons.local_fire_department_outlined,
                                      label: '热门趋势',
                                    ),
                                    _SecondFloorQuickChip(
                                      icon: Icons.person_search_outlined,
                                      label: '关注动态',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '我的小程序',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    const spacing = 10.0;
                                    final itemWidth =
                                        (constraints.maxWidth - spacing * 3) /
                                        4;
                                    final miniApps = const [
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.explore_outlined,
                                        label: '发现',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: '消息',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon:
                                            Icons.insert_chart_outlined_rounded,
                                        label: '统计',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.palette_outlined,
                                        label: '主题',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.book_outlined,
                                        label: '草稿',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.task_alt_rounded,
                                        label: '待办',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.image_outlined,
                                        label: '图集',
                                      ),
                                      _SecondFloorMiniAppItem(
                                        icon: Icons.more_horiz_rounded,
                                        label: '更多',
                                      ),
                                    ];
                                    return Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children: miniApps
                                          .map(
                                            (item) => SizedBox(
                                              width: itemWidth,
                                              height: itemWidth * 0.95,
                                              child: item,
                                            ),
                                          )
                                          .toList(growable: false),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.only(
                              bottom:
                                  bottomInset + bottomNavigationReserveHeight,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            child: SizedBox(
                              height: bottomBarHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.layers_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '二楼',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '当前：$feedLabel',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '上滑返回',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
      ],
    );
  }
}

class _SecondFloorQuickChip extends StatelessWidget {
  const _SecondFloorQuickChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondFloorMiniAppItem extends StatelessWidget {
  const _SecondFloorMiniAppItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
class PostsPage extends StatefulWidget {
  const PostsPage({
    super.key,
    required this.dependencies,
    this.controller,
    this.onSecondFloorVisibilityChanged,
    this.onSecondFloorProgressChanged,
  });

  final AppDependencies dependencies;
  final PostsPageController? controller;
  final ValueChanged<bool>? onSecondFloorVisibilityChanged;
  final ValueChanged<double>? onSecondFloorProgressChanged;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> with TickerProviderStateMixin {
  static const String _latestTopicChannel = '/latest';
  static const String _presenceMessageBusChannel =
      '/presence/whos-online/online';
  static const String _presenceStateChannelName = '/whos-online/online';
  static const double _secondFloorBottomBarHeight = 52;
  static const double _secondFloorBottomNavReserveHeight = 64;

  List<RiverSideCategoryOption> _categories = [];
  bool _loadingCategories = false;

  int? _selectedBoardId;
  String? _selectedBoardName;

  late TabController _tabController;
  final List<RiverSideTopicFeed> _feeds = RiverSideTopicFeed.values;

  int _filterVersion = 0;

  final Map<int, GlobalKey<_TopicListTabState>> _tabKeys = {};
  String? _lastActiveUsername;
  RiverSideMessageBusPoller? _messageBusPoller;
  bool _hasRealtimeTopicUpdate = false;
  double _headerScrollFactor = 0;
  int _pollingBootstrapSerial = 0;

  final Map<String, _OnlineUserPreview> _knownUserPreviewsByUsername =
      <String, _OnlineUserPreview>{};
  final Map<int, String> _knownOnlineUsernameById = <int, String>{};
  final Set<int> _onlineUserIds = <int>{};
  final Set<String> _onlineUsernames = <String>{};
  int _onlineUsersCount = 0;
  final GlobalKey _onlineUsersPillKey = GlobalKey();
  late final AnimationController _secondFloorController;
  double _secondFloorPullDistance = 0;
  bool _secondFloorArmed = false;
  bool _secondFloorVisibleForParent = false;
  bool _secondFloorOpened = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    widget.dependencies.settingsController.addListener(
      _onRefreshBannerSettingsChanged,
    );
    _tabController = TabController(length: _feeds.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _secondFloorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _secondFloorController.addListener(_onSecondFloorProgressChanged);
    _loadCategories();
    _restartRealtimePolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderWithCurrentTab();
    });
  }

  @override
  void dispose() {
    _messageBusPoller?.stop();
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    widget.dependencies.settingsController.removeListener(
      _onRefreshBannerSettingsChanged,
    );
    widget.controller?._detach(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _secondFloorController.removeListener(_onSecondFloorProgressChanged);
    _secondFloorController.dispose();
    if (_secondFloorVisibleForParent) {
      widget.onSecondFloorVisibilityChanged?.call(false);
    }
    super.dispose();
  }

  bool get _showPostsRealtimeRefreshBanner {
    return widget
        .dependencies
        .settingsController
        .showPostsRealtimeRefreshBanner;
  }

  void _onSecondFloorProgressChanged() {
    final progress = _secondFloorController.value.clamp(0.0, 1.0);
    widget.onSecondFloorProgressChanged?.call(progress);
    final visible = progress > 0.01;
    if (visible == _secondFloorVisibleForParent) {
      return;
    }
    _secondFloorVisibleForParent = visible;
    widget.onSecondFloorVisibilityChanged?.call(visible);
  }

  void _onRefreshBannerSettingsChanged() {
    if (!mounted) {
      return;
    }
    if (!_showPostsRealtimeRefreshBanner && _hasRealtimeTopicUpdate) {
      setState(() {
        _hasRealtimeTopicUpdate = false;
      });
      return;
    }
    setState(() {});
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) {
      return;
    }
    _lastActiveUsername = current;
    _messageBusPoller?.stop();
    _messageBusPoller = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _hasRealtimeTopicUpdate = false;
      _filterVersion++;
      _onlineUserIds.clear();
      _onlineUsernames.clear();
      _knownOnlineUsernameById.clear();
      _onlineUsersCount = 0;
      _knownUserPreviewsByUsername.clear();
    });
    _loadCategories();
    unawaited(_scrollToTopAndRefresh());
    _restartRealtimePolling();
  }

  String? _activeCookieHeader() {
    final username = widget.dependencies.accountStore.activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(username);
  }

  void _restartRealtimePolling() {
    _messageBusPoller?.stop();
    _messageBusPoller = null;

    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }
    final bootstrapSerial = ++_pollingBootstrapSerial;
    unawaited(
      _bootstrapRealtimePolling(
        bootstrapSerial: bootstrapSerial,
        cookieHeader: cookie,
      ),
    );
  }

  Future<void> _bootstrapRealtimePolling({
    required int bootstrapSerial,
    required String cookieHeader,
  }) async {
    final apiClient = widget.dependencies.accountStore.riverSideApiClient;
    var presenceLastMessageId = -1;

    try {
      final presenceState = await apiClient.fetchPresenceChannelState(
        channelName: _presenceStateChannelName,
        cookieHeader: cookieHeader,
      );
      if (!mounted || bootstrapSerial != _pollingBootstrapSerial) {
        return;
      }
      if (presenceState != null) {
        presenceLastMessageId = presenceState.lastMessageId;
        if (!presenceState.countOnly) {
          _applyPresenceSnapshot(
            presenceState.users,
            count: presenceState.count,
          );
        } else {
          _applyPresenceCountOnly(presenceState.count);
        }
      }
    } catch (_) {
      // Keep poller resilient even if presence bootstrap fails.
    }
    if (!mounted || bootstrapSerial != _pollingBootstrapSerial) {
      return;
    }

    final channelLastIds = <String, int>{
      _latestTopicChannel: -1,
      _presenceMessageBusChannel: presenceLastMessageId,
    };
    final poller = RiverSideMessageBusPoller(
      apiClient: apiClient,
      cookieHeader: cookieHeader,
      channelLastIds: channelLastIds,
      onEvents: (events) {
        if (!mounted || events.isEmpty) {
          return;
        }
        var hasLatestEvent = false;
        for (final event in events) {
          if (event.channel == _latestTopicChannel) {
            hasLatestEvent = true;
            continue;
          }
          if (event.channel == _presenceMessageBusChannel) {
            _consumePresenceEventData(event.data);
          }
        }
        if (!hasLatestEvent || _hasRealtimeTopicUpdate) {
          return;
        }
        if (!_showPostsRealtimeRefreshBanner) {
          return;
        }
        setState(() {
          _hasRealtimeTopicUpdate = true;
        });
      },
    );
    if (bootstrapSerial != _pollingBootstrapSerial) {
      poller.stop();
      return;
    }
    _messageBusPoller = poller;
    poller.start();
  }

  void _applyPresenceCountOnly(int count) {
    final nextCount = count < 0 ? 0 : count;
    if (!mounted) {
      return;
    }
    if (_onlineUsersCount == nextCount &&
        _onlineUserIds.isEmpty &&
        _onlineUsernames.isEmpty) {
      return;
    }
    setState(() {
      _onlineUsersCount = nextCount;
      _onlineUserIds.clear();
      _onlineUsernames.clear();
      _knownOnlineUsernameById.clear();
    });
  }

  void _applyPresenceSnapshot(
    Iterable<RiverSidePresenceUser> users, {
    int? count,
  }) {
    final nextOnlineIds = <int>{};
    final nextOnlineUsernames = <String>{};
    for (final user in users) {
      if (user.id > 0) {
        nextOnlineIds.add(user.id);
      }
      final normalizedUsername = _normalizePresenceUsername(user.username);
      if (normalizedUsername.isNotEmpty) {
        nextOnlineUsernames.add(normalizedUsername);
      }
      if (user.id > 0 && normalizedUsername.isNotEmpty) {
        _knownOnlineUsernameById[user.id] = normalizedUsername;
      }
    }

    final nextCount = _resolvePresenceCount(
      explicitCount: count,
      usernamesCount: nextOnlineUsernames.length,
      idsCount: nextOnlineIds.length,
    );
    if (!mounted) {
      return;
    }
    if (_onlineUsersCount == nextCount &&
        _setEquals(_onlineUserIds, nextOnlineIds) &&
        _setEquals(_onlineUsernames, nextOnlineUsernames)) {
      return;
    }
    setState(() {
      _onlineUserIds
        ..clear()
        ..addAll(nextOnlineIds);
      _onlineUsernames
        ..clear()
        ..addAll(nextOnlineUsernames);
      _onlineUsersCount = nextCount;
    });
  }

  bool _consumePresenceEventData(dynamic rawData) {
    final payload = _decodePresencePayload(rawData);
    if (payload is List) {
      final users = _parsePresenceUsers(payload);
      _applyPresenceSnapshot(users);
      return true;
    }

    if (payload is! Map) {
      return false;
    }
    final data = _toStringDynamicMap(payload);
    if (data.isEmpty) {
      return false;
    }

    final usersRaw = _readListField(data, const <String>['users']);
    if (usersRaw != null) {
      _applyPresenceSnapshot(
        _parsePresenceUsers(usersRaw),
        count: _parseInt(data['count']),
      );
      return true;
    }

    final enteringUsersRaw = _readListField(data, const <String>[
      'entering_users',
      'online_users',
    ]);
    final leavingUserIdsRaw = _readListField(data, const <String>[
      'leaving_user_ids',
    ]);
    final explicitCount = _parseInt(data['count']);

    final nextIds = <int>{..._onlineUserIds};
    final nextUsernames = <String>{..._onlineUsernames};
    var changed = false;

    if (enteringUsersRaw != null) {
      for (final user in _parsePresenceUsers(enteringUsersRaw)) {
        if (user.id > 0) {
          changed = nextIds.add(user.id) || changed;
        }
        final normalized = _normalizePresenceUsername(user.username);
        if (normalized.isNotEmpty) {
          changed = nextUsernames.add(normalized) || changed;
        }
        if (user.id > 0 && normalized.isNotEmpty) {
          _knownOnlineUsernameById[user.id] = normalized;
        }
      }
    }

    if (leavingUserIdsRaw != null) {
      for (final userId in _parsePresenceUserIds(leavingUserIdsRaw)) {
        final removed = nextIds.remove(userId);
        if (!removed) {
          continue;
        }
        changed = true;
        final username = _knownOnlineUsernameById[userId];
        if (username != null) {
          nextUsernames.remove(username);
        }
      }
    }

    final nextCount = _resolvePresenceCount(
      explicitCount: explicitCount,
      usernamesCount: nextUsernames.length,
      idsCount: nextIds.length,
    );
    if (!mounted) {
      return false;
    }
    if (!changed &&
        _onlineUsersCount == nextCount &&
        _setEquals(_onlineUserIds, nextIds) &&
        _setEquals(_onlineUsernames, nextUsernames)) {
      return false;
    }
    setState(() {
      _onlineUserIds
        ..clear()
        ..addAll(nextIds);
      _onlineUsernames
        ..clear()
        ..addAll(nextUsernames);
      _onlineUsersCount = nextCount;
    });
    return true;
  }

  dynamic _decodePresencePayload(dynamic rawData) {
    if (rawData is String) {
      final source = rawData.trim();
      if (source.isEmpty) {
        return null;
      }
      if ((source.startsWith('{') && source.endsWith('}')) ||
          (source.startsWith('[') && source.endsWith(']'))) {
        try {
          return jsonDecode(source);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return rawData;
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      result['${entry.key}'] = entry.value;
    }
    return result;
  }

  List<dynamic>? _readListField(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is List) {
        return value;
      }
    }
    return null;
  }

  List<RiverSidePresenceUser> _parsePresenceUsers(List<dynamic> rawUsers) {
    final users = <RiverSidePresenceUser>[];
    for (final rawUser in rawUsers) {
      final map = _toStringDynamicMap(rawUser);
      if (map.isNotEmpty) {
        final id = _parseInt(map['id']) ?? 0;
        final username = (map['username'] ?? '').toString().trim();
        if (id > 0 || username.isNotEmpty) {
          users.add(RiverSidePresenceUser(id: id, username: username));
        }
        continue;
      }

      final id = _parseInt(rawUser);
      if (id != null && id > 0) {
        users.add(RiverSidePresenceUser(id: id, username: ''));
        continue;
      }

      final username = '$rawUser'.trim();
      if (username.isNotEmpty) {
        users.add(RiverSidePresenceUser(id: 0, username: username));
      }
    }
    return users;
  }

  List<int> _parsePresenceUserIds(List<dynamic> rawIds) {
    final ids = <int>[];
    for (final raw in rawIds) {
      final id = _parseInt(raw);
      if (id != null && id > 0) {
        ids.add(id);
      }
    }
    return ids;
  }

  int _resolvePresenceCount({
    required int? explicitCount,
    required int usernamesCount,
    required int idsCount,
  }) {
    if (explicitCount != null && explicitCount >= 0) {
      return explicitCount;
    }
    final fallback = usernamesCount > idsCount ? usernamesCount : idsCount;
    return fallback < 0 ? 0 : fallback;
  }

  int? _parseInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  String _normalizePresenceUsername(String source) {
    return source.trim().toLowerCase();
  }

  bool _setEquals<T>(Set<T> left, Set<T> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final item in left) {
      if (!right.contains(item)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _consumeRealtimeTopicUpdate() async {
    if (_hasRealtimeTopicUpdate && mounted) {
      setState(() {
        _hasRealtimeTopicUpdate = false;
      });
    }
    await _scrollToTopAndRefresh();
  }

  void _dismissRealtimeTopicUpdateHint() {
    if (!_hasRealtimeTopicUpdate || !mounted) {
      return;
    }
    setState(() {
      _hasRealtimeTopicUpdate = false;
    });
  }

  Future<List<RiverSideCategoryOption>> _loadCategories({
    bool forceRefresh = false,
  }) async {
    if (_loadingCategories) return _categories;
    _loadingCategories = true;
    try {
      final cookie = _activeCookieHeader();
      final activeUsername =
          widget.dependencies.accountStore.activeRiverSideUsername;
      var categories = await RiverSideCategoryStore.instance.load(
        apiClient: widget.dependencies.accountStore.riverSideApiClient,
        username: activeUsername,
        cookieHeader: cookie,
        forceRefresh: forceRefresh,
      );
      if (!forceRefresh &&
          cookie != null &&
          cookie.trim().isNotEmpty &&
          categories.isEmpty) {
        categories = await RiverSideCategoryStore.instance.load(
          apiClient: widget.dependencies.accountStore.riverSideApiClient,
          username: activeUsername,
          cookieHeader: cookie,
          forceRefresh: true,
        );
      }
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_selectedBoardId != null) {
            final selected = findRiverSideCategoryById(
              id: _selectedBoardId,
              categories: _categories,
            );
            _selectedBoardName = selected == null
                ? null
                : displayRiverSideCategoryName(
                    category: selected,
                    allCategories: _categories,
                  );
          }
        });
      }
      return categories;
    } catch (e) {
      debugPrint('Failed to load boards: $e');
      return _categories;
    } finally {
      _loadingCategories = false;
    }
  }

  Future<void> _scrollToTopAndRefresh() async {
    final key = _tabKeys[_tabController.index];
    key?.currentState?.scrollToTopAndRefresh();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _syncHeaderWithCurrentTab();
  }

  void _syncHeaderWithCurrentTab() {
    final key = _tabKeys[_tabController.index];
    final offset = key?.currentState?.currentScrollOffset ?? 0;
    _onActiveTabScrollOffsetChanged(offset);
  }

  void _setSecondFloorPullDistance(double value) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final triggerDistance = _secondFloorTriggerDistanceForViewport();
    final next = value.clamp(0.0, screenHeight);
    final armed = next >= triggerDistance;
    final changed =
        (_secondFloorPullDistance - next).abs() > 0.1 ||
        _secondFloorArmed != armed;
    if (!changed || !mounted) {
      return;
    }
    setState(() {
      _secondFloorPullDistance = next;
      _secondFloorArmed = armed;
    });
    if (!_secondFloorController.isAnimating) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      final progress = (next / screenHeight).clamp(0.0, 1.0);
      if ((_secondFloorController.value - progress).abs() > 0.001) {
        _secondFloorController.value = progress;
      }
    }
  }

  double _secondFloorTriggerDistanceForViewport() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight * 0.5;
  }

  Future<void> _animateSecondFloorTo(
    double target, {
    Curve curve = Curves.easeOutCubic,
    Duration? duration,
  }) async {
    final clampedTarget = target.clamp(0.0, 1.0);
    final distance = (clampedTarget - _secondFloorController.value).abs();
    final computedDuration =
        duration ??
        Duration(
          milliseconds: (220 + (distance * 260)).round().clamp(220, 460),
        );
    await _secondFloorController.animateTo(
      clampedTarget,
      duration: computedDuration,
      curve: curve,
    );
    if (clampedTarget <= 0.0 && _secondFloorController.value != 0.0) {
      _secondFloorController.value = 0.0;
    } else if (clampedTarget >= 1.0 && _secondFloorController.value != 1.0) {
      _secondFloorController.value = 1.0;
    }
  }

  void _resetSecondFloorPullState() {
    if (_secondFloorPullDistance == 0 && !_secondFloorArmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _secondFloorPullDistance = 0;
      _secondFloorArmed = false;
    });
  }

  Future<void> _openSecondFloor() async {
    if (mounted && !_secondFloorOpened) {
      setState(() {
        _secondFloorOpened = true;
      });
    } else {
      _secondFloorOpened = true;
    }
    await _animateSecondFloorTo(1);
  }

  Future<void> _closeSecondFloor() async {
    await _animateSecondFloorTo(0);
    if (mounted && _secondFloorOpened) {
      setState(() {
        _secondFloorOpened = false;
      });
    } else {
      _secondFloorOpened = false;
    }
    _resetSecondFloorPullState();
  }

  void _onHeaderDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() < 0.1) {
      return;
    }
    if (delta > 0) {
      _setSecondFloorPullDistance(_secondFloorPullDistance + delta);
      return;
    }
    if (delta < 0 && _secondFloorPullDistance > 0) {
      _setSecondFloorPullDistance(_secondFloorPullDistance + delta);
    }
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    if (_secondFloorPullDistance <= 0) {
      if (_secondFloorController.value > 0 &&
          _secondFloorController.value < 1) {
        _resetSecondFloorPullState();
        unawaited(
          _animateSecondFloorTo(
            0,
            curve: Curves.easeOutQuart,
            duration: const Duration(milliseconds: 280),
          ),
        );
      }
      return;
    }
    if (_secondFloorArmed) {
      unawaited(_openSecondFloor());
      return;
    }
    _resetSecondFloorPullState();
    unawaited(
      _animateSecondFloorTo(
        0,
        curve: Curves.easeOutQuart,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _onSecondFloorDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() < 0.1) {
      return;
    }
    // 上滑关闭：delta < 0 => progress 下降；下滑回弹：delta > 0 => progress 上升
    final screenHeight = MediaQuery.sizeOf(context).height;
    final next = (_secondFloorController.value + (delta / screenHeight)).clamp(
      0.0,
      1.0,
    );
    _secondFloorController.value = next;
  }

  void _onSecondFloorDragEnd(DragEndDetails details) {
    final shouldClose = _secondFloorController.value < 0.62;
    if (shouldClose) {
      unawaited(_closeSecondFloor());
      return;
    }
    unawaited(_animateSecondFloorTo(1));
  }

  void _onActiveTabScrollOffsetChanged(double offset) {
    final next = (offset / 96).clamp(0.0, 1.0);
    if ((_headerScrollFactor - next).abs() < 0.01 || !mounted) {
      return;
    }
    setState(() {
      _headerScrollFactor = next;
    });
  }

  void _onBoardFilterPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => RiverSideCategoryPickerSheet(
        initialCategories: _categories,
        selectedCategoryId: _selectedBoardId,
        allowSelectAll: true,
        onRefreshCategories: ({bool forceRefresh = false}) {
          return _loadCategories(forceRefresh: forceRefresh);
        },
        onSelected: (category) {
          Navigator.pop(context);
          if (_selectedBoardId == category?.id) return;
          setState(() {
            _selectedBoardId = category?.id;
            _selectedBoardName = category == null
                ? null
                : displayRiverSideCategoryName(
                    category: category,
                    allCategories: _categories,
                  );
            _filterVersion++;
          });
        },
      ),
    );
  }

  Map<int, String> _buildCategoryNameMap() {
    if (_categories.isEmpty) {
      return const <int, String>{};
    }
    return <int, String>{
      for (final category in _categories)
        category.id: displayRiverSideCategoryName(
          category: category,
          allCategories: _categories,
        ),
    };
  }

  void _onTabTopicsSnapshotChanged(List<RiverSideTopicSummary> topics) {
    var changed = false;
    for (final topic in topics) {
      final username = topic.authorUsername.trim();
      final normalized = _normalizePresenceUsername(username);
      if (normalized.isEmpty) {
        continue;
      }
      final preview = _OnlineUserPreview(
        username: username,
        displayName: topic.authorDisplayName.trim().isEmpty
            ? username
            : topic.authorDisplayName.trim(),
        avatarUrl: topic.authorAvatarUrl.trim(),
      );
      final previous = _knownUserPreviewsByUsername[normalized];
      if (previous == preview) {
        continue;
      }
      _knownUserPreviewsByUsername[normalized] = preview;
      changed = true;
    }
    if (changed &&
        mounted &&
        _onlineUsernames.any(_knownUserPreviewsByUsername.containsKey)) {
      setState(() {});
    }
  }

  int get _resolvedOnlineUsersCount {
    if (_onlineUsersCount > 0) {
      return _onlineUsersCount;
    }
    final byName = _onlineUsernames.length;
    final byId = _onlineUserIds.length;
    return byName > byId ? byName : byId;
  }

  List<_OnlineUserPreview> _buildOnlineUsersForDisplay() {
    final usernames = _onlineUsernames.toList(growable: false)..sort();
    final users = <_OnlineUserPreview>[];
    for (final normalized in usernames) {
      final known = _knownUserPreviewsByUsername[normalized];
      if (known != null) {
        users.add(known);
      } else {
        users.add(
          _OnlineUserPreview(
            username: normalized,
            displayName: normalized,
            avatarUrl: '',
          ),
        );
      }
    }
    return users;
  }

  Rect _resolveOnlineUsersPillRect(BuildContext context) {
    final pillContext = _onlineUsersPillKey.currentContext;
    final screenSize = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    if (pillContext == null) {
      return Rect.fromLTWH(screenSize.width - 176, topInset + 14, 164, 34);
    }
    final renderObject = pillContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return Rect.fromLTWH(screenSize.width - 176, topInset + 14, 164, 34);
    }
    final globalOffset = renderObject.localToGlobal(Offset.zero);
    return globalOffset & renderObject.size;
  }

  Future<void> _openOnlineUsersPopup() async {
    final users = _buildOnlineUsersForDisplay();
    final onlineCount = _resolvedOnlineUsersCount;
    final anchorRect = _resolveOnlineUsersPillRect(context);
    final selected = await showGeneralDialog<_OnlineUserPreview>(
      context: context,
      barrierLabel: 'online_users',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.04),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        final shownUsers = users.take(120).toList(growable: false);
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final topInset = MediaQuery.paddingOf(dialogContext).top;
        final bottomInset = MediaQuery.paddingOf(dialogContext).bottom;
        final popupWidth = (screenSize.width * 0.72).clamp(244.0, 328.0);
        final popupLeft = (anchorRect.right - popupWidth).clamp(
          12.0,
          screenSize.width - popupWidth - 12.0,
        );
        final popupTop = (anchorRect.bottom + 8).clamp(
          topInset + 6,
          screenSize.height - 210,
        );
        final maxHeight = (screenSize.height - popupTop - bottomInset - 12)
            .clamp(156.0, 360.0);
        final arrowLeft = (anchorRect.center.dx - popupLeft - 6).clamp(
          14.0,
          popupWidth - 22,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).maybePop(),
              ),
            ),
            Positioned(
              top: popupTop,
              left: popupLeft,
              width: popupWidth,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -6,
                        left: arrowLeft,
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.32),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.32,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.tips_and_updates_outlined,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '当前在线',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$onlineCount',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: '关闭',
                                    visualDensity: VisualDensity.compact,
                                    splashRadius: 16,
                                    onPressed: () =>
                                        Navigator.of(dialogContext).maybePop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            if (shownUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
                                child: Text('暂无在线用户详情'),
                              )
                            else
                              Flexible(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    2,
                                    8,
                                    12,
                                  ),
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    final user = shownUsers[index];
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => Navigator.of(
                                          dialogContext,
                                        ).pop(user),
                                        child: Ink(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildOnlineUserAvatar(
                                                user: user,
                                                radius: 15,
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      user.displayName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    Text(
                                                      '@${user.username}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 6),
                                  itemCount: shownUsers.length,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeInQuad,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    await showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: selected.username,
      displayName: selected.displayName,
      avatarUrl: selected.avatarUrl,
    );
  }

  Future<void> _openSearchPage() async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => SearchPage(dependencies: widget.dependencies),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final easedHeaderFactor = Curves.easeOutCubic.transform(
      _headerScrollFactor,
    );
    final categoryNameMap = _buildCategoryNameMap();

    return PopScope<void>(
      canPop: !_secondFloorOpened,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_secondFloorOpened || _secondFloorController.value > 0) {
          unawaited(_closeSecondFloor());
        }
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _secondFloorController,
          builder: (context, _) {
            final progress = _secondFloorController.value.clamp(0.0, 1.0);
            final baseShift = lerpDouble(
              0,
              MediaQuery.sizeOf(context).height * 0.78,
              progress,
            )!;
            final showSecondFloor = progress > 0.0001;
            final secondFloorInteractive =
                _secondFloorOpened || progress >= 0.999;

            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, baseShift),
                  child: IgnorePointer(
                    ignoring: secondFloorInteractive,
                    child: Column(
                      children: [
                        _buildTopHeader(
                          theme,
                          easedHeaderFactor,
                          secondFloorProgress: progress,
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: _feeds.asMap().entries.map((entry) {
                              final index = entry.key;
                              final feed = entry.value;

                              _tabKeys[index] ??=
                                  GlobalKey<_TopicListTabState>();

                              return _TopicListTab(
                                key: _tabKeys[index],
                                dependencies: widget.dependencies,
                                feed: feed,
                                boardId: _selectedBoardId,
                                categoryNameMap: categoryNameMap,
                                filterVersion: _filterVersion,
                                showInlineRealtimeHint:
                                    _showPostsRealtimeRefreshBanner &&
                                    _hasRealtimeTopicUpdate,
                                onConsumeRealtimeUpdate:
                                    _consumeRealtimeTopicUpdate,
                                onDismissRealtimeUpdate:
                                    _dismissRealtimeTopicUpdateHint,
                                onTopicsSnapshotChanged:
                                    _onTabTopicsSnapshotChanged,
                                onScrollOffsetChanged: (offset) {
                                  if (_tabController.index != index) {
                                    return;
                                  }
                                  _onActiveTabScrollOffsetChanged(offset);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !showSecondFloor,
                  child: _PostsSecondFloorLayer(
                    progress: progress,
                    feedLabel: _feeds[_tabController.index].label,
                    bottomBarHeight: _secondFloorBottomBarHeight,
                    bottomNavigationReserveHeight:
                        _secondFloorBottomNavReserveHeight,
                    interactive: secondFloorInteractive,
                    onClose: _closeSecondFloor,
                    onDragUpdate: _onSecondFloorDragUpdate,
                    onDragEnd: _onSecondFloorDragEnd,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOnlineUsersPill(ThemeData theme) {
    final users = _buildOnlineUsersForDisplay();
    final onlineCount = _resolvedOnlineUsersCount;
    final previewUsers = users.take(3).toList(growable: false);
    final enabled = onlineCount > 0;

    return KeyedSubtree(
      key: _onlineUsersPillKey,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? _openOnlineUsersPopup : null,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 24,
                  child: previewUsers.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.group_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (
                              var index = 0;
                              index < previewUsers.length;
                              index++
                            )
                              Positioned(
                                left: index * 12,
                                child: _buildOnlineUserAvatar(
                                  user: previewUsers[index],
                                  radius: 11,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$onlineCount用户在线',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineUserAvatar({
    required _OnlineUserPreview user,
    required double radius,
  }) {
    final theme = Theme.of(context);
    final displayText = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.username.trim();
    final initials = displayText.isEmpty ? '?' : displayText.substring(0, 1);
    final avatarUrl = user.avatarUrl.trim();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.surface, width: 1.4),
        image: avatarUrl.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: avatarUrl.isEmpty
          ? Text(
              initials,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }

  Widget _buildTopHeader(
    ThemeData theme,
    double t, {
    required double secondFloorProgress,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapse = t.clamp(0.0, 1.0);
    final secondFloorFade = (1 - secondFloorProgress).clamp(0.0, 1.0);
    const titleSize = 21.0;
    final subtitleVisibility = (1.0 - collapse).clamp(0.0, 1.0);
    final borderAlpha = lerpDouble(0.18, 0.26, collapse)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(
              alpha: lerpDouble(0.90, 0.96, t)!,
            ),
            theme.colorScheme.surfaceContainerLowest.withValues(
              alpha: lerpDouble(0.82, 0.92, t)!,
            ),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: borderAlpha,
            ),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: lerpDouble(7, 11, t)!,
            sigmaY: lerpDouble(7, 11, t)!,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topInset + lerpDouble(9, 8, collapse)!,
              bottom: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: _onHeaderDragUpdate,
                  onVerticalDragEnd: _onHeaderDragEnd,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 188),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '帖子',
                                    textAlign: TextAlign.left,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      fontSize: titleSize,
                                    ),
                                  ),
                                  ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      heightFactor: subtitleVisibility,
                                      child: Opacity(
                                        opacity: subtitleVisibility,
                                        child: Text(
                                          _feeds[_tabController.index].label,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildOnlineUsersPill(theme),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: _openSearchPage,
                                  tooltip: '搜索',
                                  icon: Hero(
                                    tag: postsSearchHeroTag,
                                    child: const Icon(Icons.search_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Opacity(
                    opacity: secondFloorFade,
                    child: IgnorePointer(
                      ignoring: secondFloorFade <= 0.01,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicatorColor: theme.colorScheme.primary,
                                labelColor: theme.colorScheme.primary,
                                unselectedLabelColor:
                                    theme.colorScheme.onSurfaceVariant,
                                indicatorSize: TabBarIndicatorSize.label,
                                dividerColor: Colors.transparent,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                labelPadding: const EdgeInsets.only(right: 24),
                                tabs: _feeds
                                    .map((feed) => Tab(text: feed.label))
                                    .toList(),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 20,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            _buildBoardFilterButton(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardFilterButton(ThemeData theme) {
    final hasSelection = _selectedBoardId != null;
    final label = _selectedBoardName ?? '\u5168\u90e8\u677f\u5757';

    return Hero(
      tag: 'board_picker_hero',
      flightShuttleBuilder:
          (flightContext, animation, direction, fromContext, toContext) {
            return Material(color: Colors.transparent, child: toContext.widget);
          },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBoardFilterPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: hasSelection
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: BorderRadius.circular(20),
              border: hasSelection
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasSelection
                      ? Icons.dashboard_rounded
                      : Icons.dashboard_customize_outlined,
                  size: 16,
                  color: hasSelection
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSelection
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: hasSelection
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
