import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/categories/riverside_category_store.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/widgets/riverside_category_picker_sheet.dart';
import 'package:river/core/widgets/river_markdown_editor.dart';
import 'package:river/features/compose/compose_topic_preview_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

part 'compose_topic_page_view.dart';
part 'compose_topic_page_actions.dart';

class ComposeTopicPage extends StatefulWidget {
  const ComposeTopicPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<ComposeTopicPage> createState() => _ComposeTopicPageState();
}

class _ComposeTopicPageState extends State<ComposeTopicPage>
    with SingleTickerProviderStateMixin {
  static const String _labelNeedLogin = '请先登录 RiverSide 账号';

  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();

  List<RiverSideCategoryOption> _categories = const <RiverSideCategoryOption>[];
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};

  String _contentMarkdown = '';
  int? _selectedCategoryId;
  bool _loadingMeta = false;
  bool _publishing = false;
  double _topBarFactor = 0;
  String? _lastActiveUsername;

  // 动画控制器：用于入场动画
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);

    // 初始化动画
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );

    _animController.forward();
    _loadMetaData();
    _pageScrollController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _pageScrollController
      ..removeListener(_onPageScroll)
      ..dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final next =
        (_pageScrollController.hasClients ? _pageScrollController.offset : 0) /
        96;
    final normalized = next.clamp(0.0, 1.0);
    if ((_topBarFactor - normalized).abs() < 0.01 || !mounted) {
      return;
    }
    setState(() {
      _topBarFactor = normalized;
    });
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) return;
    _lastActiveUsername = current;
    _loadMetaData();
  }

  String? _activeCookieHeader() {
    final activeUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    if (activeUsername == null || activeUsername.isEmpty) return null;
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(
      activeUsername,
    );
  }

  UserAccount? get _activeAccount =>
      widget.dependencies.accountStore.activeRiverSideAccount;

  void _mutateState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage(context);
  }

  String _resolveForumUrl(String source) {
    // ... (保留原有逻辑)
    final raw = source.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('upload://')) {
      return 'https://river-side.cc/uploads/short-url/${raw.substring('upload://'.length)}';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://river-side.cc$raw';
    return 'https://river-side.cc/$raw';
  }
}
