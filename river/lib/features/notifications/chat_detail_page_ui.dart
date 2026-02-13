part of 'chat_detail_page.dart';

extension _ChatDetailPageUi on _ChatDetailPageState {
  Widget _buildPage(BuildContext context) {
    final active =
        widget.dependencies.accountStore.activeRiverSideUsername
            ?.toLowerCase() ??
        '';

    final isLoadingBody = _loadingInitial && _messages.isEmpty;
    final isErrorBody = _error != null && _messages.isEmpty;
    final body = isLoadingBody
        ? _buildLoadingBody(context)
        : isErrorBody
        ? _buildErrorBody(context)
        : _buildChatBody(context, active);

    final bodyKey = isLoadingBody
        ? const ValueKey<String>('chat_body_loading')
        : isErrorBody
        ? const ValueKey<String>('chat_body_error')
        : const ValueKey<String>('chat_body_content');

    return PopScope<void>(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_selectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: _buildTopBar(context),
        body: ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.015),
                  end: Offset.zero,
                ).animate(fade);
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(key: bodyKey, child: body),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    if (_selectionMode) {
      final count = _selectedMessageIds.length;
      return AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        leading: IconButton(
          tooltip: '取消多选',
          onPressed: _exitSelectionMode,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '复制',
            onPressed: count > 0 ? _copySelectedMessages : null,
            icon: const Icon(Icons.content_copy_rounded),
          ),
          IconButton(
            tooltip: '回复',
            onPressed: count > 0 ? _replySelectedMessage : null,
            icon: const Icon(Icons.reply_rounded),
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    final channelName = widget.channel.name.trim().isEmpty
        ? 'Chat'
        : widget.channel.name.trim();
    final subtitle = widget.channel.description.trim().isNotEmpty
        ? widget.channel.description.trim()
        : (widget.channel.isDirectMessage ? '私信会话' : '频道消息');

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 12,
      title: Row(
        children: [
          _buildChannelAvatar(size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _sending ? null : _openComposer,
          icon: const Icon(Icons.reply_rounded),
          tooltip: '发送消息',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
        itemCount: 8,
        itemBuilder: (context, index) {
          final mine = index.isOdd;
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: MediaQuery.sizeOf(context).width * (mine ? 0.58 : 0.68),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: mine
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.66)
                    : theme.colorScheme.surfaceContainerHigh.withValues(
                        alpha: 0.8,
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: MediaQuery.sizeOf(context).width * 0.26,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sms_failed_outlined,
              size: 30,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? _ChatDetailPageState._labelLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _loadInitial(clearExisting: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(_ChatDetailPageState._labelRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(BuildContext context, String activeUsername) {
    final theme = Theme.of(context);
    final keyboardInset = _selectionMode
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    final dockInset = _selectionMode
        ? 74.0
        : (_composerDockHeight > 0 ? _composerDockHeight : 112.0);
    final listBottomPadding = (dockInset + keyboardInset + 16).toDouble();
    final floatingBottom = (dockInset + keyboardInset + 14).toDouble();
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.98),
                theme.colorScheme.surfaceContainerLowest.withValues(
                  alpha: 0.96,
                ),
              ],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () => _loadInitial(clearExisting: false),
            child: _messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 220),
                    children: const [
                      Center(
                        child: Text(_ChatDetailPageState._labelNoMessages),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(10, 10, 10, listBottomPadding),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildLoadMoreIndicator(context);
                      }
                      final messageIndex = index - 1;
                      final item = _messages[messageIndex];
                      final previous = messageIndex > 0
                          ? _messages[messageIndex - 1]
                          : null;
                      final next = messageIndex + 1 < _messages.length
                          ? _messages[messageIndex + 1]
                          : null;
                      final isMine =
                          item.username.toLowerCase() == activeUsername &&
                          activeUsername.isNotEmpty;
                      final showDateDivider = !_isSameDay(
                        previous?.createdAt,
                        item.createdAt,
                      );
                      final showAvatar =
                          !isMine && _shouldShowAvatarByNext(item, next);
                      final showDisplayName =
                          !isMine && _shouldShowDisplayName(previous, item);

                      return Column(
                        children: [
                          if (showDateDivider)
                            _buildDateDivider(context, item.createdAt),
                          KeyedSubtree(
                            key: _messageKeyFor(item.id),
                            child: _buildMessageBubble(
                              context: context,
                              item: item,
                              isMine: isMine,
                              showAvatar: showAvatar,
                              showDisplayName: showDisplayName,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (!_selectionMode)
          Positioned(
            right: 16,
            bottom: floatingBottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _newMessageHintCount > 0
                      ? Padding(
                          key: const ValueKey<String>('chat_new_message_hint'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FilledButton.tonalIcon(
                            onPressed: _consumeNewMessageHintAndScroll,
                            icon: const Icon(Icons.south_rounded, size: 18),
                            label: Text('$_newMessageHintCount 条新消息'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  scale: _showScrollToBottom ? 1 : 0.9,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _showScrollToBottom ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showScrollToBottom,
                      child: FloatingActionButton.small(
                        heroTag: 'chat_scroll_bottom_${widget.channel.id}',
                        onPressed: _consumeNewMessageHintAndScroll,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
                transitionBuilder: (child, animation) {
                  final fade = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(fade);
                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(_selectionMode),
                  child: _selectionMode
                      ? _buildSelectionActionBar(context)
                      : _buildComposerDock(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator(BuildContext context) {
    if (_loadingOlder) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_hasMorePast) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: Text(
            _ChatDetailPageState._labelNoMore,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 4);
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  bool _shouldShowAvatarByNext(
    RiverSideChatMessageItem current,
    RiverSideChatMessageItem? next,
  ) {
    if (next == null) {
      return true;
    }
    if (next.username.toLowerCase() != current.username.toLowerCase()) {
      return true;
    }
    if (current.inReplyTo != null || next.inReplyTo != null) {
      return true;
    }
    final nextAt = next.createdAt;
    final currAt = current.createdAt;
    if (nextAt == null || currAt == null) {
      return false;
    }
    return nextAt.difference(currAt).inMinutes.abs() > 6;
  }

  bool _shouldShowDisplayName(
    RiverSideChatMessageItem? previous,
    RiverSideChatMessageItem current,
  ) {
    if (previous == null) {
      return true;
    }
    return previous.username.toLowerCase() != current.username.toLowerCase();
  }

  Widget _buildDateDivider(BuildContext context, DateTime? time) {
    final label = time == null ? '--' : _formatDateTime(time).split(' ').first;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.85,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required RiverSideChatMessageItem item,
    required bool isMine,
    required bool showAvatar,
    required bool showDisplayName,
  }) {
    final theme = Theme.of(context);
    final pressed = _pressedMessageId == item.id;
    final selected = _selectedMessageIds.contains(item.id);
    final canOpenProfile = !isMine && item.username.trim().isNotEmpty;
    final heroAvatarTag = 'chat-msg-avatar-${widget.channel.id}-${item.id}';
    final heroNameTag = 'chat-msg-name-${widget.channel.id}-${item.id}';
    final bubbleColor = isMine
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.96)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.94);
    final effectiveBubbleColor = pressed
        ? bubbleColor.withValues(alpha: isMine ? 0.80 : 0.72)
        : bubbleColor;
    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final replyRef = item.inReplyTo;
    final content = _normalizeChatMessageMarkdown(item);

    Offset? tapPosition;
    final bubble = Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          tapPosition = details.globalPosition;
        },
        onTap: () async {
          HapticFeedback.selectionClick();
          _markMessagePressed(item.id);
          if (_selectionMode) {
            _toggleSelectedMessage(item.id);
            return;
          }
          await _showMessageActions(
            item: item,
            isMine: isMine,
            anchor:
                tapPosition ??
                Offset(
                  MediaQuery.sizeOf(context).width / 2,
                  MediaQuery.sizeOf(context).height * 0.6,
                ),
          );
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (_selectionMode) {
            _toggleSelectedMessage(item.id);
            return;
          }
          _enterSelectionModeWith(item.id);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.62)
                : effectiveBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && showDisplayName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: InkWell(
                    onTap: canOpenProfile
                        ? () {
                            _openUserProfileSheetForMessage(
                              item: item,
                              heroAvatarTag: heroAvatarTag,
                              heroNameTag: heroNameTag,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: heroNameTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          _displayName(item),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (replyRef != null) _buildReplyPreview(context, replyRef),
              if (replyRef != null) const SizedBox(height: 6),
              if (item.deleted)
                Text(
                  _ChatDetailPageState._labelMessageDeleted,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                MarkdownBody(
                  data: content,
                  selectable: false,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    pPadding: EdgeInsets.zero,
                    blockSpacing: 6,
                    codeblockPadding: const EdgeInsets.all(8),
                    codeblockDecoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  inlineSyntaxes: _emojiUrls.isEmpty
                      ? const <md.InlineSyntax>[]
                      : <md.InlineSyntax>[_ChatEmojiInlineSyntax(_emojiUrls)],
                  builders: _emojiUrls.isEmpty
                      ? const <String, MarkdownElementBuilder>{}
                      : <String, MarkdownElementBuilder>{
                          'emoji': _ChatEmojiBuilder(
                            resolveUrl: _resolveForumUrl,
                            headersForUrl: _headersForUrl,
                          ),
                        },
                  onTapLink: (text, href, title) {
                    if (href != null && href.isNotEmpty) {
                      _openLink(href);
                    }
                  },
                  sizedImageBuilder: (config) {
                    final resolved = _resolveForumUrl('${config.uri}');
                    final headers = _headersForUrl(resolved);
                    final heroTag =
                        'chat-image-${widget.channel.id}-${item.id}-${resolved.hashCode}';
                    final imageProvider = CachedNetworkImageProvider(
                      resolved,
                      headers: headers,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          RiverImageViewerPage.open(
                            context,
                            items: <RiverImageViewerItem>[
                              RiverImageViewerItem(
                                url: resolved,
                                headers: headers,
                                heroTag: heroTag,
                                imageProvider: imageProvider,
                              ),
                            ],
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: Hero(
                              tag: heroTag,
                              child: CachedNetworkImage(
                                imageUrl: resolved,
                                httpHeaders: headers,
                                fit: BoxFit.contain,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (context, url) => ColoredBox(
                                  color:
                                      theme.colorScheme.surfaceContainerLowest,
                                  child: const AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    config.alt?.trim().isNotEmpty == true
                                        ? (config.alt ?? '')
                                        : '图片加载失败',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
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
                        final action = reaction.reacted ? 'remove' : 'add';
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: reaction.reacted
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          onPressed: item.deleted
                              ? null
                              : () {
                                  _reactToMessage(
                                    item: item,
                                    emojiName: reaction.emoji,
                                    action: action,
                                  );
                                },
                          avatar: _emojiTokenWidget(reaction.emoji),
                          label: Text('${reaction.count}'),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatDateTime(item.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final messageRow = Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 34,
              child: showAvatar
                  ? InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canOpenProfile
                          ? () {
                              _openUserProfileSheetForMessage(
                                item: item,
                                heroAvatarTag: heroAvatarTag,
                                heroNameTag: heroNameTag,
                              );
                            }
                          : null,
                      child: Hero(
                        tag: heroAvatarTag,
                        child: _buildUserAvatar(
                          avatarUrl: item.avatarUrl,
                          size: 32,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        Flexible(child: bubble),
        if (isMine) const SizedBox(width: 34),
      ],
    );

    final body = TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.96, end: 1),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: showAvatar ? 12 : 6),
        child: messageRow,
      ),
    );

    if (!_selectionMode) {
      return body;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatSelectionCircle(
            selected: selected,
            onTap: () => _toggleSelectedMessage(item.id),
          ),
          const SizedBox(width: 4),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(
    BuildContext context,
    RiverSideChatMessageReplyRef replyRef,
  ) {
    final theme = Theme.of(context);
    final text = replyRef.excerpt.trim().isNotEmpty
        ? replyRef.excerpt.trim()
        : _stripHtml(replyRef.cooked);
    final replyUser = replyRef.username.trim().isEmpty
        ? _ChatDetailPageState._labelUnknownUser
        : replyRef.username.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          HapticFeedback.selectionClick();
          await _jumpToMessageById(replyRef.id);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.reply_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '@$replyUser  $text',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerDock(BuildContext context) {
    final theme = Theme.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final render = _composerDockKey.currentContext?.findRenderObject();
      if (render is RenderBox) {
        _updateComposerDockHeight(render.size.height + 18);
      }
    });
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Container(
          key: _composerDockKey,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '回复 ${_displayName(_replyingMessage!)}: ${_replyingMessage!.raw.trim().isNotEmpty ? _replyingMessage!.raw.trim() : _stripHtml(_replyingMessage!.cooked)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '取消回复',
                        onPressed: () => _setReplyingMessage(null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '插入图片',
                      visualDensity: VisualDensity.compact,
                      onPressed: _sending ? null : _pickAndInsertComposerImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    IconButton(
                      tooltip: '选择表情',
                      visualDensity: VisualDensity.compact,
                      onPressed: _sending ? null : _showComposerEmojiPicker,
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded),
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: TextField(
                          controller: _composerController,
                          focusNode: _composerFocusNode,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textAlignVertical: TextAlignVertical.center,
                          inputFormatters: [
                            _ChatEmojiInputFormatter(
                              replacements:
                                  _ChatDetailPageState._fallbackReactionSymbols,
                            ),
                          ],
                          decoration: InputDecoration(
                            isCollapsed: true,
                            hintText: _sending ? '发送中...' : '输入消息...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          );
                        },
                        child: (_composerHasText || _sending)
                            ? Container(
                                key: const ValueKey<String>(
                                  'composer_send_visible',
                                ),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkResponse(
                                    customBorder: const CircleBorder(),
                                    onTap: _sending
                                        ? null
                                        : _submitComposerMessage,
                                    radius: 22,
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: _sending
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.send_rounded,
                                                size: 19,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey<String>('composer_send_hidden'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selectedMessageIds.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: count > 0 ? _replySelectedMessage : null,
                icon: const Icon(Icons.reply_rounded),
                label: const Text('回复'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: count > 0 ? _copySelectedMessages : null,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('复制'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelAvatar({required double size}) {
    final raw = widget.channel.avatarUrl.trim();
    if (raw.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Icon(
          widget.channel.isDirectMessage
              ? Icons.person_rounded
              : Icons.tag_rounded,
          size: size * 0.5,
        ),
      );
    }
    final resolved = _resolveForumUrl(raw);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: resolved,
          httpHeaders: _headersForUrl(resolved),
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (context, url, error) => Icon(
            widget.channel.isDirectMessage
                ? Icons.person_rounded
                : Icons.tag_rounded,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar({required String avatarUrl, required double size}) {
    final raw = avatarUrl.trim();
    if (raw.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Icon(Icons.person_outline_rounded, size: size * 0.48),
      );
    }
    final resolved = _resolveForumUrl(raw);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: resolved,
          httpHeaders: _headersForUrl(resolved),
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => const Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
          errorWidget: (context, url, error) =>
              Icon(Icons.person_outline_rounded, size: size * 0.48),
        ),
      ),
    );
  }
}

class _ChatReactionCircleButton extends StatelessWidget {
  const _ChatReactionCircleButton({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 38, height: 38, child: Center(child: child)),
      ),
    );
  }
}

class _ChatSelectionCircle extends StatelessWidget {
  const _ChatSelectionCircle({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
          icon: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _ChatEmojiInputFormatter extends TextInputFormatter {
  const _ChatEmojiInputFormatter({required this.replacements});

  final Map<String, String> replacements;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.baseOffset;
    if (cursor <= 1 || cursor > newValue.text.length) {
      return newValue;
    }
    final left = newValue.text.substring(0, cursor);
    final match = RegExp(r':([a-zA-Z0-9_+\-]+):$').firstMatch(left);
    if (match == null) {
      return newValue;
    }
    final token = match.group(1) ?? '';
    final replacement = replacements[token];
    if (replacement == null || replacement.isEmpty) {
      return newValue;
    }

    final start = cursor - (match.group(0)?.length ?? 0);
    final nextText = newValue.text.replaceRange(start, cursor, replacement);
    final nextOffset = start + replacement.length;
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }
}

class _ChatComposerRichController extends TextEditingController {
  static final RegExp _tokenRegExp = RegExp(
    r'(:[a-zA-Z0-9_+\-]+:|@[a-zA-Z0-9_]+|`[^`]+`|\*\*[^*]+\*\*)',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    if (source.isEmpty) {
      return TextSpan(style: baseStyle, text: source);
    }
    final colorScheme = Theme.of(context).colorScheme;
    final tokenStyle = baseStyle.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final codeStyle = baseStyle.copyWith(
      color: colorScheme.tertiary,
      fontFamily: 'monospace',
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _tokenRegExp.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      final token = source.substring(match.start, match.end);
      final tokenLower = token.toLowerCase();
      final isCode = token.startsWith('`') && token.endsWith('`');
      final isBold = token.startsWith('**') && token.endsWith('**');
      final emojiName = token.startsWith(':') && token.endsWith(':')
          ? token.substring(1, token.length - 1)
          : '';
      final fallbackEmoji =
          _ChatDetailPageState._fallbackReactionSymbols[emojiName];
      final styleToUse = isCode
          ? codeStyle
          : isBold
          ? tokenStyle.copyWith(fontWeight: FontWeight.w800)
          : tokenStyle;
      spans.add(
        TextSpan(
          text: fallbackEmoji ?? (tokenLower == ':smile:' ? '😄' : token),
          style: styleToUse,
        ),
      );
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}
