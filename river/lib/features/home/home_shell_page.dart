import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/features/home/tab_placeholder_page.dart';
import 'package:river/features/mine/mine_page.dart';
import 'package:river/features/posts/posts_page.dart';

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
    '\u804a\u5929',
    '\u6211\u7684',
  ];

  late final List<Widget> _pages = <Widget>[
    PostsPage(dependencies: widget.dependencies),
    const TabPlaceholderPage(label: '\u53d1\u5e16\u9875\u5360\u4f4d'),
    const TabPlaceholderPage(label: '\u804a\u5929\u9875\u5360\u4f4d'),
    MinePage(dependencies: widget.dependencies),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedTabIndex])),
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '\u804a\u5929',
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
