part of 'chat_detail_page.dart';

extension _ChatDetailPageUi on _ChatDetailPageState {
  Widget _buildPage(BuildContext context) {
    if (_loadingInitial && _messages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.channel.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.channel.name)),
        body: Center(
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
                  onPressed: () => _loadInitial(clearExisting: true),
                  child: const Text(_ChatDetailPageState._labelRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final active =
        widget.dependencies.accountStore.activeRiverSideUsername
            ?.toLowerCase() ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _sending ? null : _openComposer,
            icon: const Icon(Icons.edit_outlined),
            tooltip: '\u53d1\u9001\u6d88\u606f',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadInitial(clearExisting: false),
              child: _messages.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(_ChatDetailPageState._labelNoMessages),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          if (_loadingOlder) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (!_hasMorePast) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: Text(
                                  _ChatDetailPageState._labelNoMore,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 4);
                        }

                        final item = _messages[index - 1];
                        final isMine =
                            item.username.toLowerCase() == active &&
                            active.isNotEmpty;
                        final bubbleColor = isMine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest;
                        final textColor = Theme.of(
                          context,
                        ).colorScheme.onSurface;

                        final content = item.raw.trim().isNotEmpty
                            ? item.raw
                            : _stripHtml(item.cooked);
                        final replyRef = item.inReplyTo;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: item.avatarUrl.isEmpty
                                          ? null
                                          : NetworkImage(item.avatarUrl),
                                      child: item.avatarUrl.isEmpty
                                          ? const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  if (!isMine) const SizedBox(width: 8),
                                  Flexible(
                                    child: GestureDetector(
                                      onLongPress: () {
                                        _showMessageActions(
                                          item: item,
                                          isMine: isMine,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: bubbleColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          10,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _displayName(item),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            if (replyRef != null) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surface
                                                      .withValues(alpha: 0.7),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.reply_outlined,
                                                      size: 14,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '@${replyRef.username.isEmpty ? _ChatDetailPageState._labelUnknownUser : replyRef.username}  '
                                                        '${replyRef.excerpt.trim().isEmpty ? _stripHtml(replyRef.cooked) : replyRef.excerpt}',
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            if (item.deleted)
                                              Text(
                                                _ChatDetailPageState
                                                    ._labelMessageDeleted,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                              )
                                            else
                                              MarkdownBody(
                                                data: content,
                                                selectable: false,
                                                styleSheet:
                                                    MarkdownStyleSheet.fromTheme(
                                                      Theme.of(context),
                                                    ).copyWith(
                                                      p: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: textColor,
                                                          ),
                                                      pPadding:
                                                          const EdgeInsets.all(
                                                            0,
                                                          ),
                                                      blockSpacing: 6,
                                                    ),
                                                inlineSyntaxes:
                                                    _emojiUrls.isEmpty
                                                    ? const <md.InlineSyntax>[]
                                                    : <md.InlineSyntax>[
                                                        _ChatEmojiInlineSyntax(
                                                          _emojiUrls,
                                                        ),
                                                      ],
                                                builders: _emojiUrls.isEmpty
                                                    ? const <
                                                        String,
                                                        MarkdownElementBuilder
                                                      >{}
                                                    : <
                                                        String,
                                                        MarkdownElementBuilder
                                                      >{
                                                        'emoji': _ChatEmojiBuilder(
                                                          resolveUrl:
                                                              _resolveForumUrl,
                                                          headersForUrl:
                                                              _headersForUrl,
                                                        ),
                                                      },
                                                onTapLink: (text, href, title) {
                                                  if (href != null &&
                                                      href.isNotEmpty) {
                                                    _openLink(href);
                                                  }
                                                },
                                              ),
                                            if (item.reactions.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: item.reactions
                                                    .where((it) => it.count > 0)
                                                    .map((reaction) {
                                                      final action =
                                                          reaction.reacted
                                                          ? 'remove'
                                                          : 'add';
                                                      return ActionChip(
                                                        onPressed: item.deleted
                                                            ? null
                                                            : () {
                                                                _reactToMessage(
                                                                  item: item,
                                                                  emojiName:
                                                                      reaction
                                                                          .emoji,
                                                                  action:
                                                                      action,
                                                                );
                                                              },
                                                        avatar:
                                                            _emojiTokenWidget(
                                                              reaction.emoji,
                                                            ),
                                                        label: Text(
                                                          '${reaction.count}',
                                                        ),
                                                      );
                                                    })
                                                    .toList(growable: false),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatDateTime(item.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isMine) const SizedBox(width: 8),
                                  if (isMine)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: item.avatarUrl.isEmpty
                                          ? null
                                          : NetworkImage(item.avatarUrl),
                                      child: item.avatarUrl.isEmpty
                                          ? const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _openComposer,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('\u53d1\u9001\u6d88\u606f'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
