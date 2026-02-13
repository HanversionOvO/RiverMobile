part of 'search_page.dart';

extension _SearchPageView on _SearchPageState {
  Widget _buildPage(BuildContext context) {
    final theme = Theme.of(context);
    final hasKeyword = _keywordController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        titleSpacing: 8,
        title: Text(
          _SearchPageState._labelSearch,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Hero(
              tag: postsSearchHeroTag,
              child: Material(
                color: Colors.transparent,
                child: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(124),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              children: [
                _buildSearchInput(theme, hasKeyword),
                const SizedBox(height: 10),
                _buildModeSelector(theme),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(
            'search-body:${_searchMode.name}:$_activeQuery:${_loading ? 1 : 0}'
            ':${_error ?? ''}:$_resultAnimationEpoch',
          ),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showBackToTop,
        builder: (context, visible, _) {
          final showingSuggestions =
              _keywordFocused && _keywordController.text.trim().isNotEmpty;
          final shouldShow = visible && !_loading && !showingSuggestions;
          return IgnorePointer(
            ignoring: !shouldShow,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: shouldShow ? Offset.zero : const Offset(0, 0.15),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: shouldShow ? 1 : 0,
                child: FloatingActionButton.small(
                  heroTag: 'search_back_to_top',
                  onPressed: shouldShow ? _scrollToTop : null,
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme, bool hasKeyword) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _keywordFocused
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: _keywordFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.48)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.52),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: _keywordFocused ? 0.10 : 0.05,
            ),
            blurRadius: _keywordFocused ? 12 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _keywordController,
        focusNode: _keywordFocusNode,
        autofocus: true,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        onChanged: _onKeywordInputChanged,
        onSubmitted: (_) => _runSearch(reset: true),
        decoration: InputDecoration(
          hintText: _SearchPageState._labelSearchHint,
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 44,
          ),
          prefixIcon: Icon(
            Icons.manage_search_rounded,
            color: _keywordFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: SizedBox(
            width: hasKeyword ? 92 : 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasKeyword)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '清空',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _keywordController.clear();
                      _mutateState(() {
                        _activeQuery = '';
                        _error = null;
                        _postItems = const <RiverSidePostSearchItem>[];
                        _userItems = const <RiverSideUserSearchItem>[];
                      });
                      _loadRecentSearches();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  tooltip: _SearchPageState._labelSearch,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _runSearch(reset: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SegmentedButton<_SearchMode>(
          segments: _SearchMode.values
              .map(
                (mode) => ButtonSegment<_SearchMode>(
                  value: mode,
                  label: Text(mode.label),
                  icon: Icon(
                    mode == _SearchMode.posts
                        ? Icons.article_outlined
                        : Icons.person_search_outlined,
                    size: 16,
                  ),
                ),
              )
              .toList(growable: false),
          selected: <_SearchMode>{_searchMode},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            _onModeChanged(selection.first);
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final showSuggestions =
        _keywordFocused && _keywordController.text.trim().isNotEmpty;
    if (showSuggestions) {
      return _buildSuggestionBody();
    }
    if (_loading) {
      return _buildLoadingState();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded, size: 30),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _runSearch(reset: true),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(_SearchPageState._labelRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_activeQuery.isEmpty) {
      return _buildRecentSearchBody();
    }

    switch (_searchMode) {
      case _SearchMode.posts:
        return _buildPostsResultList();
      case _SearchMode.users:
        return _buildUsersResultList();
    }
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 11,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 11,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersResultList() {
    if (_userItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search_outlined,
        text: _SearchPageState._labelNoUsers,
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
        itemCount: _userItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = _userItems[index];
          return _StaggeredAppear(
            key: ValueKey<String>(
              'user-${user.username}-$index-$_resultAnimationEpoch',
            ),
            index: index,
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundImage: user.avatarUrl.isEmpty
                      ? null
                      : NetworkImage(user.avatarUrl),
                  child: user.avatarUrl.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: _HighlightedText(
                  text: user.displayName,
                  keyword: _activeQuery,
                  style: Theme.of(context).textTheme.titleMedium,
                  highlightStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _HighlightedText(
                  text: '@${user.username}',
                  keyword: _activeQuery,
                  style: Theme.of(context).textTheme.bodySmall,
                  highlightStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openUserProfile(user),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionBody() {
    final query = _keywordController.text.trim();
    final hasKeywordSuggestions = _keywordSuggestions.isNotEmpty;
    final hasPostSuggestions = _postSuggestions.isNotEmpty;
    final hasUserSuggestions = _userSuggestions.isNotEmpty;
    final hasAnySuggestions =
        hasKeywordSuggestions || hasPostSuggestions || hasUserSuggestions;
    final sectionTitleStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        if (_loadingSuggestions)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasKeywordSuggestions) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Text(
                    _SearchPageState._labelSuggestion,
                    style: sectionTitleStyle,
                  ),
                ),
                for (final keyword in _keywordSuggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_rounded, size: 18),
                    title: _HighlightedText(
                      text: keyword,
                      keyword: query,
                      style: Theme.of(context).textTheme.bodyMedium,
                      highlightStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.north_west_rounded, size: 18),
                    onTap: () => _applySuggestionKeyword(keyword),
                  ),
              ],
              if (_searchMode == _SearchMode.posts && hasPostSuggestions) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Text(
                    _SearchPageState._labelSuggestionPosts,
                    style: sectionTitleStyle,
                  ),
                ),
                for (final post in _postSuggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.article_outlined, size: 18),
                    title: _HighlightedText(
                      text: post.title,
                      keyword: query,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      highlightStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      post.authorDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => _openTopicDetail(post.topicId),
                  ),
              ],
              if (_searchMode == _SearchMode.users && hasUserSuggestions) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Text(
                    _SearchPageState._labelSuggestionUsers,
                    style: sectionTitleStyle,
                  ),
                ),
                for (final user in _userSuggestions)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundImage: user.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(user.avatarUrl),
                      child: user.avatarUrl.isEmpty
                          ? const Icon(Icons.person_outline, size: 14)
                          : null,
                    ),
                    title: _HighlightedText(
                      text: user.displayName,
                      keyword: query,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      highlightStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: _HighlightedText(
                      text: '@${user.username}',
                      keyword: query,
                      style: Theme.of(context).textTheme.bodySmall,
                      highlightStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => _openUserProfile(user),
                  ),
              ],
              if (!hasAnySuggestions && !_loadingSuggestions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Text(
                    '没有匹配的联想建议',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchBody() {
    if (_loadingRecentSearches && _recentSearches.isEmpty) {
      return _buildLoadingState();
    }

    return RefreshIndicator(
      onRefresh: _loadRecentSearches,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _SearchPageState._labelRecentSearches,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_recentSearches.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearingRecentSearches
                            ? null
                            : _clearRecentSearches,
                        icon: _clearingRecentSearches
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                        label: const Text(_SearchPageState._labelClearRecent),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_recentSearches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _SearchPageState._labelNoRecentSearches,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _recentSearches.length; i++)
                        _StaggeredAppear(
                          key: ValueKey<String>(
                            'recent-${_recentSearches[i]}-$i',
                          ),
                          index: i,
                          child: ActionChip(
                            avatar: const Icon(Icons.history_rounded, size: 16),
                            label: Text(_recentSearches[i]),
                            onPressed: () =>
                                _applyRecentSearch(_recentSearches[i]),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (_recentSearches.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _SearchPageState._labelNeedKeyword,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostsResultList() {
    if (_postItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            _buildEmptyState(
              icon: Icons.article_outlined,
              text: _SearchPageState._labelNoPosts,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
        itemCount: _postItems.length + 1,
        itemBuilder: (context, index) {
          if (index == _postItems.length) {
            if (_loadingMorePosts) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (!_hasMorePostPages) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    _SearchPageState._labelNoMore,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            return const SizedBox(height: 36);
          }

          final post = _postItems[index];
          final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StaggeredAppear(
              key: ValueKey<String>(
                'post-${post.topicId}-$index-$_resultAnimationEpoch',
              ),
              index: index,
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: InkWell(
                  onTap: () => _openTopicDetail(post.topicId),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: post.authorAvatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(post.authorAvatarUrl),
                              child: post.authorAvatarUrl.isEmpty
                                  ? const Icon(Icons.person_outline, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _HighlightedText(
                                text: post.authorDisplayName,
                                keyword: _activeQuery,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                                highlightStyle: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Text(
                              _formatDateTime(post.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: subtitleColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _HighlightedText(
                          text: post.title,
                          keyword: _activeQuery,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          highlightStyle: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        if (post.excerpt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _HighlightedText(
                            text: post.excerpt,
                            keyword: _activeQuery,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: subtitleColor, height: 1.35),
                            highlightStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaInfoPill(
                              icon: Icons.label_outline_rounded,
                              text: post.categoryName,
                              color: subtitleColor,
                            ),
                            _MetaInfoPill(
                              icon: Icons.chat_bubble_outline_rounded,
                              text: post.replyCount.toString(),
                              color: subtitleColor,
                            ),
                            _MetaInfoPill(
                              icon: Icons.visibility_outlined,
                              text: post.viewCount.toString(),
                              color: subtitleColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }
    final local = value.toLocal();
    String two(int number) => number < 10 ? '0$number' : '$number';
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StaggeredAppear extends StatelessWidget {
  const _StaggeredAppear({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 22).clamp(0, 220);
    final duration = Duration(milliseconds: 220 + delay);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.keyword,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String keyword;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty || text.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final activeHighlightStyle =
        highlightStyle ??
        baseStyle?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        );
    final regex = RegExp(
      RegExp.escape(normalizedKeyword),
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: activeHighlightStyle,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

class _MetaInfoPill extends StatelessWidget {
  const _MetaInfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
