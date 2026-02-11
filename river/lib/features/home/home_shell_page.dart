import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/features/compose/compose_topic_page.dart';
import 'package:river/features/mine/mine_page.dart';
import 'package:river/features/notifications/notifications_page.dart';
import 'package:river/features/posts/posts_page.dart';
import 'package:river/features/search/search_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _selectedTabIndex = 0;

  static const List<String> _titles = <String>[
    '\u5e16\u5b50',
    '\u53d1\u5e16',
    '\u901a\u77e5',
    '\u6211\u7684',
  ];

  late final List<Widget> _pages = <Widget>[
    PostsPage(dependencies: widget.dependencies),
    ComposeTopicPage(dependencies: widget.dependencies),
    NotificationsPage(dependencies: widget.dependencies),
    MinePage(dependencies: widget.dependencies),
  ];

  Future<void> _openSearchPage() async {
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => SearchPage(dependencies: widget.dependencies),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedTabIndex]),
        actions: _selectedTabIndex == 0
            ? [
                IconButton(
                  onPressed: _openSearchPage,
                  tooltip: '\u641c\u7d22',
                  icon: Hero(
                    tag: postsSearchHeroTag,
                    child: const Icon(Icons.search),
                  ),
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: _selectedTabIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '\u5e16\u5b50',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '\u53d1\u5e16',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: '\u901a\u77e5',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '\u6211\u7684',
          ),
        ],
      ),
    );
  }
}

