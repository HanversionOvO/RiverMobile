import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/features/home/tab_placeholder_page.dart';
import 'package:river/features/mine/mine_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _selectedTabIndex = 0;

  static const List<String> _titles = <String>['帖子', '发帖', '聊天', '我的'];

  late final List<Widget> _pages = <Widget>[
    const TabPlaceholderPage(label: '帖子页占位'),
    const TabPlaceholderPage(label: '发帖页占位'),
    const TabPlaceholderPage(label: '聊天页占位'),
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
            label: '帖子',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '发帖',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
