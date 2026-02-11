part of 'posts_page.dart';

extension _PostsPageView on _PostsPageState {
  Widget _buildPage(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<RiverSideTopicFeed>(
                    segments: RiverSideTopicFeed.values
                        .map(
                          (feed) => ButtonSegment<RiverSideTopicFeed>(
                            value: feed,
                            label: Text(feed.label),
                          ),
                        )
                        .toList(),
                    selected: <RiverSideTopicFeed>{_selectedFeed},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      _onFeedChanged(selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildCategoryButton(),
            ],
          ),
        ),
        Expanded(child: _buildBodyWithActionButton()),
      ],
    );
  }

  Widget _buildCategoryButton() {
    if (_selectedCategoryId == null) {
      return OutlinedButton(
        onPressed: _onCategoryButtonPressed,
        child: const Text('\u5e16\u5b50\u7c7b\u522b'),
      );
    }

    return FilledButton.tonal(
      onPressed: _onCategoryButtonPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_selectedCategoryName ?? '\u5df2\u9009\u7c7b\u522b'),
          const SizedBox(width: 6),
          const Icon(Icons.close, size: 16),
        ],
      ),
    );
  }

  Widget _buildBodyWithActionButton() {
    return Stack(
      children: [
        Positioned.fill(child: _buildBody()),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              ignoring: !_hasRealtimeTopicUpdate,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: _hasRealtimeTopicUpdate
                    ? Offset.zero
                    : const Offset(0, 1.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hasRealtimeTopicUpdate ? 1 : 0,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_new_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '\u6709\u65b0\u5e16\u5b50\uff0c\u70b9\u51fb\u5237\u65b0',
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _consumeRealtimeTopicUpdate,
                            child: const Text('\u5237\u65b0'),
                          ),
                          IconButton(
                            tooltip: '\u5173\u95ed',
                            onPressed: _dismissRealtimeTopicUpdateHint,
                            icon: const Icon(Icons.close),
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
        Positioned(
          right: 16,
          bottom: _hasRealtimeTopicUpdate ? 92 : 20,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: _floatingActionMode == _FloatingActionMode.hidden ? 0 : 1,
            child: _floatingActionMode == _FloatingActionMode.hidden
                ? const SizedBox.shrink()
                : FloatingActionButton.small(
                    onPressed: _onFloatingActionPressed,
                    child: Icon(
                      _floatingActionMode == _FloatingActionMode.backToTop
                          ? Icons.vertical_align_top
                          : Icons.refresh,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loadingFirstPage && _topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadFirstPage(clearExisting: false),
                child: const Text('\u91cd\u8bd5'),
              ),
            ],
          ),
        ),
      );
    }

    if (_topics.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('\u6682\u65e0\u5e16\u5b50')),
          ],
        ),
      );
    }

    final showHotIcon = _selectedFeed == RiverSideTopicFeed.hot;
    final itemCount = _topics.length + 1;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= _topics.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (!_hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '\u6ca1\u6709\u66f4\u591a\u4e86',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            return const SizedBox(height: 32);
          }

          final topic = _topics[index];
          return _TopicCard(
            topic: topic,
            showHotIcon: showHotIcon,
            onTap: () => _openTopicDetail(topic.id),
            onAuthorTap: () => _openTopicAuthorProfile(topic),
          );
        },
      ),
    );
  }
}
