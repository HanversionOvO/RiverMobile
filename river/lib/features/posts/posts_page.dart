import 'package:flutter/material.dart';
import 'package:river/app/app_dependencies.dart';
import 'package:river/core/categories/riverside_category_utils.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_topic_models.dart';
import 'package:river/core/widgets/riverside_category_picker_sheet.dart';
import 'package:river/features/mine/riverside_profile_sheet.dart';
import 'package:river/features/posts/topic_detail_page.dart';
import 'package:river/core/navigation/river_page_route.dart';

part 'posts_page_widgets.dart';
part 'posts_page_view.dart';
part 'posts_page_actions.dart';

enum _FloatingActionMode { hidden, backToTop, refresh }

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  static const double _loadMoreTriggerOffset = 280;
  static const double _showActionButtonOffset = 420;
  static const double _actionSwitchDelta = 24;
  static const int _maxScanPagePerLoad = 4;

  final ScrollController _scrollController = ScrollController();

  RiverSideTopicFeed _selectedFeed = RiverSideTopicFeed.latestCreated;
  List<RiverSideTopicSummary> _topics = const <RiverSideTopicSummary>[];
  List<RiverSideCategoryOption> _categories = const <RiverSideCategoryOption>[];
  bool _loadingCategories = false;
  bool _loadingFirstPage = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _error;
  int _requestSerial = 0;
  double _lastScrollOffset = 0;
  _FloatingActionMode _floatingActionMode = _FloatingActionMode.hidden;
  String? _lastActiveUsername;

  @override
  void initState() {
    super.initState();
    _lastActiveUsername =
        widget.dependencies.accountStore.activeRiverSideUsername;
    widget.dependencies.accountStore.addListener(_onAccountStoreChanged);
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadFirstPage(clearExisting: true);
  }

  @override
  void dispose() {
    widget.dependencies.accountStore.removeListener(_onAccountStoreChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
