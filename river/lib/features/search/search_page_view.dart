part of 'search_page.dart';

extension _SearchPageView on _SearchPageState {
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
                onPressed: () => _runSearch(reset: true),
                child: const Text(_SearchPageState._labelRetry),
              ),
            ],
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
        if (_userItems.isEmpty) {
          return const Center(child: Text(_SearchPageState._labelNoUsers));
        }
        return ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
          itemCount: _userItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = _userItems[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.avatarUrl.isEmpty
                      ? null
                      : NetworkImage(user.avatarUrl),
                  child: user.avatarUrl.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: Text(user.displayName),
                subtitle: Text('@${user.username}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openUserProfile(user),
              ),
            );
          },
        );
    }
  }

  Widget _buildRecentSearchBody() {
    if (_loadingRecentSearches && _recentSearches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadRecentSearches,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          Row(
            children: [
              Text(
                _SearchPageState._labelRecentSearches,
                style: Theme.of(context).textTheme.titleMedium,
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  label: const Text(_SearchPageState._labelClearRecent),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentSearches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(_SearchPageState._labelNoRecentSearches),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final keyword in _recentSearches)
                  ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(keyword),
                    onPressed: () => _applyRecentSearch(keyword),
                  ),
              ],
            ),
          if (_recentSearches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: Text(_SearchPageState._labelNeedKeyword)),
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
          children: const [
            SizedBox(height: 180),
            Center(child: Text(_SearchPageState._labelNoPosts)),
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
          return Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 10),
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
                          child: Text(
                            post.authorDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          _formatDateTime(post.createdAt),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (post.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _MetaInfo(
                          icon: Icons.label_outline,
                          text: post.categoryName,
                          color: subtitleColor,
                        ),
                        _MetaInfo(
                          icon: Icons.chat_bubble_outline,
                          text: post.replyCount.toString(),
                          color: subtitleColor,
                        ),
                        _MetaInfo(
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
          );
        },
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

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
