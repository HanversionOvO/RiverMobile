import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/widgets/river_markdown_editor.dart';
import 'package:river/features/compose/compose_topic_preview_page.dart';
import 'package:river/features/posts/topic_detail_page.dart';

part 'compose_topic_page_view.dart';
part 'compose_topic_page_actions.dart';

class ComposeTopicPage extends StatefulWidget {
  const ComposeTopicPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<ComposeTopicPage> createState() => _ComposeTopicPageState();
}

class _ComposeTopicPageState extends State<ComposeTopicPage> {
  static const String _labelNeedLogin = '请先登录 RiverSide 账号';

  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  List<RiverSideCategoryOption> _categories = const <RiverSideCategoryOption>[];
  Map<String, String> _emojiUrls = const <String, String>{};
  Map<String, List<String>> _emojiGroups = const <String, List<String>>{};

  String _contentMarkdown = '';
  int? _selectedCategoryId;
  bool _loadingMeta = false;
  bool _publishing = false;
  String? _lastActiveUsername;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _loadMetaData();
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    if (current == _lastActiveUsername) {
      return;
    }
    _lastActiveUsername = current;
    _loadMetaData();
  }

  String? _activeCookieHeader() {
    final activeUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    if (activeUsername == null || activeUsername.isEmpty) {
      return null;
    }
    return widget.dependencies.accountStore.riverSideCookieHeaderFor(
      activeUsername,
    );
  }

  UserAccount? get _activeAccount =>
      widget.dependencies.accountStore.activeRiverSideAccount;

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

  String _resolveForumUrl(String source) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return raw;
    }
    if (raw.startsWith('upload://')) {
      return 'https://river-side.cc/uploads/short-url/${raw.substring('upload://'.length)}';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('/')) {
      return 'https://river-side.cc$raw';
    }
    return 'https://river-side.cc/$raw';
  }
}
