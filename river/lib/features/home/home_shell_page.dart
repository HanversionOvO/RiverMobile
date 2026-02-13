import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/features/compose/compose_topic_page.dart';
import 'package:river/features/mine/mine_page.dart';
import 'package:river/features/notifications/notifications_page.dart';
import 'package:river/features/posts/posts_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  static const Duration _postsTabDoubleTapWindow = Duration(milliseconds: 320);

  int _selectedTabIndex = 0;
  int _notificationsUnreadCount = 0;
  double _postsSecondFloorProgress = 0;
  DateTime? _lastPostsTabTapAt;
  final PostsPageController _postsPageController = PostsPageController();

  late final List<Widget> _pages = <Widget>[
    PostsPage(
      dependencies: widget.dependencies,
      controller: _postsPageController,
      onSecondFloorVisibilityChanged: _onPostsSecondFloorVisibilityChanged,
      onSecondFloorProgressChanged: _onPostsSecondFloorProgressChanged,
    ),
    ComposeTopicPage(dependencies: widget.dependencies),
    NotificationsPage(
      dependencies: widget.dependencies,
      onUnreadCountChanged: _onUnreadCountChanged,
    ),
    MinePage(dependencies: widget.dependencies),
  ];

  void _onUnreadCountChanged(int value) {
    if (!mounted || value == _notificationsUnreadCount) {
      return;
    }
    setState(() {
      _notificationsUnreadCount = value;
    });
  }

  void _onPostsSecondFloorVisibilityChanged(bool visible) {
    if (!mounted) {
      return;
    }
    if (!visible && _postsSecondFloorProgress != 0) {
      setState(() {
        _postsSecondFloorProgress = 0;
      });
    }
  }

  void _onPostsSecondFloorProgressChanged(double progress) {
    final next = progress.clamp(0.0, 1.0);
    if (!mounted || (_postsSecondFloorProgress - next).abs() < 0.001) {
      return;
    }
    setState(() {
      _postsSecondFloorProgress = next;
    });
  }

  Widget _buildNotificationTabIcon({required bool selected}) {
    final baseIcon = Icon(
      selected ? Icons.notifications : Icons.notifications_none_outlined,
    );
    final count = _notificationsUnreadCount;
    if (count <= 0) {
      return baseIcon;
    }
    return Badge.count(count: count > 99 ? 99 : count, child: baseIcon);
  }

  void _onDestinationSelected(int index) {
    if (index == 0) {
      if (_selectedTabIndex == 0) {
        final now = DateTime.now();
        final lastTapAt = _lastPostsTabTapAt;
        if (lastTapAt != null &&
            now.difference(lastTapAt) <= _postsTabDoubleTapWindow) {
          _lastPostsTabTapAt = null;
          unawaited(_postsPageController.scrollToTopAndRefresh());
          return;
        }
        _lastPostsTabTapAt = now;
        return;
      }
      _lastPostsTabTapAt = DateTime.now();
    } else {
      _lastPostsTabTapAt = null;
    }

    if (index == _selectedTabIndex) {
      return;
    }
    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final secondFloorProgress = _selectedTabIndex == 0
        ? _postsSecondFloorProgress
        : 0.0;
    final bottomOpacity = (1 - secondFloorProgress).clamp(0.0, 1.0);
    final bottomSizeFactor = (1 - secondFloorProgress).clamp(0.0, 1.0);
    return Scaffold(
      body: IndexedStack(index: _selectedTabIndex, children: _pages),
      bottomNavigationBar: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: bottomSizeFactor,
          child: Opacity(
            opacity: bottomOpacity,
            child: IgnorePointer(
              ignoring: secondFloorProgress > 0.001,
              child: NavigationBar(
                selectedIndex: _selectedTabIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: <NavigationDestination>[
                  const NavigationDestination(
                    icon: Icon(Icons.forum_outlined),
                    selectedIcon: Icon(Icons.forum),
                    label: '\u5e16\u5b50',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.edit_note_outlined),
                    selectedIcon: Icon(Icons.edit_note),
                    label: '\u53d1\u5e16',
                  ),
                  NavigationDestination(
                    icon: _buildNotificationTabIcon(selected: false),
                    selectedIcon: _buildNotificationTabIcon(selected: true),
                    label: '\u901a\u77e5',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '\u6211\u7684',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
