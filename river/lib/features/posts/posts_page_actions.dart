part of 'posts_page.dart';

extension _PostsPageActions on _PostsPageState {
  void _onAccountStoreChanged() {
    final current = widget.dependencies.accountStore.activeRiverSideUsername;
    final last = _lastActiveUsername;
    if (current == last) {
      return;
    }

    _lastActiveUsername = current;
    _loadCategories();
    _loadFirstPage(clearExisting: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    if (offset >= maxExtent - _PostsPageState._loadMoreTriggerOffset) {
      _loadMore();
    }

    var nextMode = _floatingActionMode;
    if (offset < _PostsPageState._showActionButtonOffset) {
      nextMode = _FloatingActionMode.hidden;
    } else {
      final delta = offset - _lastScrollOffset;
      if (delta <= -_PostsPageState._actionSwitchDelta) {
        nextMode = _FloatingActionMode.refresh;
      } else if (delta >= _PostsPageState._actionSwitchDelta ||
          _floatingActionMode == _FloatingActionMode.hidden) {
        nextMode = _FloatingActionMode.backToTop;
      }
    }

    if (nextMode != _floatingActionMode) {
      _mutateState(() {
        _floatingActionMode = nextMode;
      });
    }

    _lastScrollOffset = offset;
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

  Future<void> _loadCategories() async {
    if (_loadingCategories) {
      return;
    }

    _mutateState(() {
      _loadingCategories = true;
    });

    try {
      final categories = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .fetchCategories(cookieHeader: _activeCookieHeader());
      if (!mounted) {
        return;
      }

      _mutateState(() {
        _categories = categories;
        _loadingCategories = false;
      });
      _refreshSelectedCategoryName();
      _refreshTopicCategoryNames();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingCategories = false;
      });
    }
  }

  Future<void> _ensureCategoriesLoaded() async {
    if (_categories.isNotEmpty || _loadingCategories) {
      return;
    }
    await _loadCategories();
  }

  void _refreshSelectedCategoryName() {
    final selectedId = _selectedCategoryId;
    if (selectedId == null) {
      return;
    }

    for (final category in _categories) {
      if (category.id == selectedId) {
        final displayName = _displayCategoryName(category);
        if (_selectedCategoryName != displayName && mounted) {
          _mutateState(() {
            _selectedCategoryName = displayName;
          });
        }
        return;
      }
    }
  }

  void _refreshTopicCategoryNames() {
    if (_topics.isEmpty || _categories.isEmpty) {
      return;
    }

    final byId = <int, RiverSideCategoryOption>{
      for (final item in _categories) item.id: item,
    };
    var changed = false;
    final next = <RiverSideTopicSummary>[];
    for (final topic in _topics) {
      final categoryId = topic.categoryId;
      if (categoryId == null) {
        next.add(topic);
        continue;
      }

      final category = byId[categoryId];
      if (category == null) {
        next.add(topic);
        continue;
      }

      final nextName = _displayCategoryName(category);
      if (nextName == topic.categoryName) {
        next.add(topic);
        continue;
      }

      changed = true;
      next.add(
        RiverSideTopicSummary(
          id: topic.id,
          title: topic.title,
          excerpt: topic.excerpt,
          categoryId: topic.categoryId,
          categoryName: nextName,
          replyCount: topic.replyCount,
          viewCount: topic.viewCount,
          createdAt: topic.createdAt,
          authorDisplayName: topic.authorDisplayName,
          authorUsername: topic.authorUsername,
          authorAvatarUrl: topic.authorAvatarUrl,
          isHot: topic.isHot,
          isPinned: topic.isPinned,
        ),
      );
    }

    if (changed && mounted) {
      _mutateState(() {
        _topics = next;
      });
    }
  }

  String _displayCategoryName(RiverSideCategoryOption category) {
    final parentId = category.parentCategoryId;
    if (parentId == null) {
      return category.name;
    }

    for (final item in _categories) {
      if (item.id == parentId) {
        return '${item.name} / ${category.name}';
      }
    }
    return category.name;
  }

  Future<void> _loadFirstPage({required bool clearExisting}) async {
    final serial = ++_requestSerial;
    _mutateState(() {
      _loadingFirstPage = true;
      _loadingMore = false;
      _error = null;
      _hasMore = true;
      _currentPage = 0;
      if (clearExisting) {
        _topics = const <RiverSideTopicSummary>[];
      }
    });

    try {
      var pageNumber = 0;
      var page = await widget.dependencies.accountStore.riverSideApiClient
          .fetchTopicPage(
            feed: _selectedFeed,
            page: pageNumber,
            cookieHeader: _activeCookieHeader(),
            categoryId: _selectedCategoryId,
          );

      // Category filter may have no match in early pages; scan ahead.
      var scanned = 0;
      while (_selectedCategoryId != null &&
          page.topics.isEmpty &&
          page.hasMore &&
          scanned < _PostsPageState._maxScanPagePerLoad) {
        scanned++;
        pageNumber++;
        page = await widget.dependencies.accountStore.riverSideApiClient
            .fetchTopicPage(
              feed: _selectedFeed,
              page: pageNumber,
              cookieHeader: _activeCookieHeader(),
              categoryId: _selectedCategoryId,
            );
      }

      if (!mounted || serial != _requestSerial) {
        return;
      }

      _mutateState(() {
        _topics = page.topics;
        _hasMore = page.hasMore;
        _currentPage = pageNumber;
        _loadingFirstPage = false;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _loadingFirstPage = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _loadingFirstPage = false;
        _error = '帖子加载失败，请稍后重试';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingFirstPage || _loadingMore || !_hasMore) {
      return;
    }

    final serial = _requestSerial;
    _mutateState(() {
      _loadingMore = true;
    });

    try {
      var nextPage = _currentPage + 1;
      var scanned = 0;
      var hasMore = true;
      final merged = <RiverSideTopicSummary>[];
      final existingIds = _topics.map((topic) => topic.id).toSet();

      while (hasMore && scanned < _PostsPageState._maxScanPagePerLoad) {
        scanned++;
        final page = await widget.dependencies.accountStore.riverSideApiClient
            .fetchTopicPage(
              feed: _selectedFeed,
              page: nextPage,
              cookieHeader: _activeCookieHeader(),
              categoryId: _selectedCategoryId,
            );

        for (final topic in page.topics) {
          if (existingIds.contains(topic.id)) {
            continue;
          }
          existingIds.add(topic.id);
          merged.add(topic);
        }

        hasMore = page.hasMore;
        if (merged.isNotEmpty || !hasMore) {
          break;
        }
        nextPage++;
      }

      if (!mounted || serial != _requestSerial) {
        return;
      }

      _mutateState(() {
        _topics = <RiverSideTopicSummary>[..._topics, ...merged];
        _currentPage = nextPage;
        _hasMore = hasMore;
        _loadingMore = false;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted || serial != _requestSerial) {
        return;
      }
      _mutateState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加载更多失败')));
    }
  }

  Future<void> _onRefresh() async {
    await _loadFirstPage(clearExisting: false);
  }

  Future<void> _onFloatingActionPressed() async {
    if (_floatingActionMode == _FloatingActionMode.backToTop) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    if (_floatingActionMode == _FloatingActionMode.refresh) {
      await _onRefresh();
    }
  }

  Future<void> _onCategoryButtonPressed() async {
    if (_selectedCategoryId != null) {
      _mutateState(() {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
      });
      _loadFirstPage(clearExisting: true);
      return;
    }

    await _ensureCategoriesLoaded();
    if (!mounted) {
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用类别')));
      return;
    }

    final selected = await showModalBottomSheet<RiverSideCategoryOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _CategoryPickerSheet(
          groups: _buildCategoryGroups(),
          selectedCategoryId: _selectedCategoryId,
          onSelected: (category) => Navigator.of(sheetContext).pop(category),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    _mutateState(() {
      _selectedCategoryId = selected.id;
      _selectedCategoryName = _displayCategoryName(selected);
      _floatingActionMode = _FloatingActionMode.hidden;
    });
    _lastScrollOffset = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage(clearExisting: true);
  }

  List<_CategoryGroup> _buildCategoryGroups() {
    final byId = <int, RiverSideCategoryOption>{
      for (final item in _categories) item.id: item,
    };

    final childrenByParent = <int, List<RiverSideCategoryOption>>{};
    for (final item in _categories) {
      final parentId = item.parentCategoryId;
      if (parentId == null || !byId.containsKey(parentId)) {
        continue;
      }
      childrenByParent.putIfAbsent(parentId, () => <RiverSideCategoryOption>[]);
      childrenByParent[parentId]!.add(item);
    }

    for (final entry in childrenByParent.entries) {
      entry.value.sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) {
          return byPosition;
        }
        return a.id.compareTo(b.id);
      });
    }

    final groups = <_CategoryGroup>[];
    final handledParentIds = <int>{};
    for (final item in _categories) {
      if (item.parentCategoryId != null || handledParentIds.contains(item.id)) {
        continue;
      }
      handledParentIds.add(item.id);
      groups.add(
        _CategoryGroup(
          parent: item,
          children:
              childrenByParent[item.id] ?? const <RiverSideCategoryOption>[],
        ),
      );
    }

    for (final item in _categories) {
      if (item.parentCategoryId != null &&
          byId.containsKey(item.parentCategoryId)) {
        continue;
      }
      if (handledParentIds.contains(item.id)) {
        continue;
      }
      handledParentIds.add(item.id);
      groups.add(
        _CategoryGroup(
          parent: item,
          children: const <RiverSideCategoryOption>[],
        ),
      );
    }

    return groups;
  }

  void _onFeedChanged(RiverSideTopicFeed nextFeed) {
    if (nextFeed == _selectedFeed) {
      return;
    }

    _mutateState(() {
      _selectedFeed = nextFeed;
      _floatingActionMode = _FloatingActionMode.hidden;
    });
    _lastScrollOffset = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage(clearExisting: true);
  }

  Future<void> _openTopicDetail(int topicId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topicId,
        ),
      ),
    );
  }

  Future<void> _openTopicAuthorProfile(RiverSideTopicSummary topic) async {
    await showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: topic.authorUsername,
      displayName: topic.authorDisplayName,
      avatarUrl: topic.authorAvatarUrl,
    );
  }
}
