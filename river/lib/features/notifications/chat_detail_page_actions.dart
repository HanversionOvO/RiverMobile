part of 'chat_detail_page.dart';

extension _ChatDetailPageActions on _ChatDetailPageState {
  String _emojiKey(String raw) {
    final value = raw.trim();
    if (value.startsWith(':') && value.endsWith(':') && value.length > 2) {
      return value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  Future<void> _refreshMessageById(
    int messageId, {
    bool fallbackAsDeleted = false,
  }) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return;
    }

    try {
      final page = await widget.dependencies.accountStore.riverSideApiClient
          .fetchChatChannelMessages(
            channelId: widget.channel.id,
            cookieHeader: cookie,
            fetchFromLastRead: false,
            pageSize: 30,
            targetMessageId: messageId,
            direction: 'past',
          );
      if (!mounted) {
        return;
      }

      RiverSideChatMessageItem? target;
      for (final item in page.messages) {
        if (item.id == messageId) {
          target = item;
          break;
        }
      }

      if (target == null) {
        if (fallbackAsDeleted) {
          _markMessageAsDeletedLocally(messageId);
        }
        return;
      }

      _mutateState(() {
        _messages = _mergeMessages(_messages, <RiverSideChatMessageItem>[
          target!,
        ]);
      });
    } catch (_) {
      if (fallbackAsDeleted) {
        _markMessageAsDeletedLocally(messageId);
      }
    }
  }

  void _markMessageAsDeletedLocally(int messageId) {
    if (!mounted) {
      return;
    }

    _mutateState(() {
      _messages = _messages
          .map((item) {
            if (item.id != messageId) {
              return item;
            }
            return RiverSideChatMessageItem(
              id: item.id,
              channelId: item.channelId,
              userId: item.userId,
              username: item.username,
              displayName: item.displayName,
              avatarUrl: item.avatarUrl,
              raw: '',
              cooked: item.cooked,
              createdAt: item.createdAt,
              deleted: true,
              uploadUrls: item.uploadUrls,
              inReplyTo: item.inReplyTo,
              reactions: item.reactions,
            );
          })
          .toList(growable: false);
    });
  }

  List<RiverSideChatMessageItem> _mergeMessages(
    List<RiverSideChatMessageItem> left,
    List<RiverSideChatMessageItem> right,
  ) {
    final byId = <int, RiverSideChatMessageItem>{
      for (final item in left) item.id: item,
    };
    for (final item in right) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        if (ta != tb) {
          return ta.compareTo(tb);
        }
        return a.id.compareTo(b.id);
      });
    return merged;
  }

  Future<void> _openComposer({RiverSideChatMessageItem? replyTo}) async {
    _setReplyingMessage(replyTo);
  }

  void _insertComposerText(String insertion) {
    final value = _composerController.value;
    final start = value.selection.start >= 0
        ? value.selection.start
        : value.text.length;
    final end = value.selection.end >= 0 ? value.selection.end : start;
    final next = value.text.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    _composerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _composerFocusNode.requestFocus();
  }

  Future<void> _showComposerEmojiPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return RiverStructuredEmojiPicker(
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          onSelected: (key) {
            _insertComposerText(':$key:');
            Navigator.of(sheetContext).pop();
          },
          title: '选择表情',
        );
      },
    );
  }

  Future<void> _pickAndInsertComposerImage() async {
    if (_sending) {
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelNeedLogin)),
      );
      return;
    }
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await widget.dependencies.accountStore.riverSideApiClient
          .uploadComposerImage(
            cookieHeader: cookie,
            fileName: picked.name,
            bytes: bytes,
          );
      final resolved = uploaded.startsWith('upload://')
          ? '$riverSideBaseUrl/uploads/short-url/${uploaded.substring('upload://'.length)}'
          : _resolveForumUrl(uploaded);
      _insertComposerText('\n![]($resolved)\n');
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelLoadFailed)),
      );
    }
  }

  Future<void> _submitComposerMessage() async {
    if (_sending) {
      return;
    }
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }
    final replyToId = _replyingMessage?.id;
    final ok = await _sendMessage(text, replyToMessageId: replyToId);
    if (!ok || !mounted) {
      return;
    }
    _mutateState(() {
      _composerController.clear();
      _replyingMessage = null;
      _newMessageHintCount = 0;
      _showScrollToBottom = false;
    });
    _composerFocusNode.requestFocus();
  }

  Future<bool> _sendMessage(String markdown, {int? replyToMessageId}) async {
    if (_sending) {
      return false;
    }
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelNeedLogin)),
      );
      return false;
    }

    _mutateState(() {
      _sending = true;
    });

    try {
      final message = await widget.dependencies.accountStore.riverSideApiClient
          .sendChatChannelMessage(
            channelId: widget.channel.id,
            cookieHeader: cookie,
            message: markdown,
            inReplyToMessageId: replyToMessageId,
          );
      if (!mounted) {
        return false;
      }
      final normalizedMessage = message.createdAt != null
          ? message
          : RiverSideChatMessageItem(
              id: message.id,
              channelId: message.channelId,
              userId: message.userId,
              username: message.username,
              displayName: message.displayName,
              avatarUrl: message.avatarUrl,
              raw: message.raw,
              cooked: message.cooked,
              createdAt: DateTime.now(),
              deleted: message.deleted,
              uploadUrls: message.uploadUrls,
              inReplyTo: message.inReplyTo,
              reactions: message.reactions,
            );
      _mutateState(() {
        _messages = _mergeMessages(_messages, <RiverSideChatMessageItem>[
          normalizedMessage,
        ]);
      });
      _jumpToBottom();
      _scheduleRealtimeSync();
      return true;
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelSendFailed)),
      );
      return false;
    } finally {
      if (mounted) {
        _mutateState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _copyMessageContent(RiverSideChatMessageItem item) async {
    final content = item.raw.trim().isNotEmpty
        ? item.raw.trim()
        : _stripHtml(item.cooked);
    if (content.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_ChatDetailPageState._labelCopied)),
    );
  }

  Future<void> _deleteMessage(RiverSideChatMessageItem item) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelNeedLogin)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(_ChatDetailPageState._labelDelete),
          content: const Text(_ChatDetailPageState._labelDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(_ChatDetailPageState._labelCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(_ChatDetailPageState._labelDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .deleteChatChannelMessage(
            channelId: widget.channel.id,
            messageId: item.id,
            cookieHeader: cookie,
          );
      await _refreshMessageById(item.id, fallbackAsDeleted: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelDeleteSuccess)),
      );
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelLoadFailed)),
      );
    }
  }

  RiverSideChatMessageItem? _findMessageById(int id) {
    for (final message in _messages) {
      if (message.id == id) {
        return message;
      }
    }
    return null;
  }

  RiverSideChatMessageItem _copyMessageWithReactions(
    RiverSideChatMessageItem source,
    List<RiverSideChatMessageReaction> reactions,
  ) {
    return RiverSideChatMessageItem(
      id: source.id,
      channelId: source.channelId,
      userId: source.userId,
      username: source.username,
      displayName: source.displayName,
      avatarUrl: source.avatarUrl,
      raw: source.raw,
      cooked: source.cooked,
      createdAt: source.createdAt,
      deleted: source.deleted,
      uploadUrls: source.uploadUrls,
      inReplyTo: source.inReplyTo,
      reactions: reactions,
    );
  }

  List<RiverSideChatMessageReaction> _applyReactionMutation({
    required List<RiverSideChatMessageReaction> reactions,
    required String emojiName,
    required String action,
  }) {
    final normalized = _emojiKey(emojiName);
    if (normalized.isEmpty) {
      return reactions;
    }
    final next = reactions
        .map(
          (it) => RiverSideChatMessageReaction(
            emoji: it.emoji,
            count: it.count,
            reacted: it.reacted,
            users: it.users,
          ),
        )
        .toList(growable: true);
    final index = next.indexWhere(
      (it) => _emojiKey(it.emoji).toLowerCase() == normalized.toLowerCase(),
    );

    if (action == 'add') {
      if (index >= 0) {
        final current = next[index];
        next[index] = RiverSideChatMessageReaction(
          emoji: current.emoji,
          count: current.count + (current.reacted ? 0 : 1),
          reacted: true,
          users: current.users,
        );
      } else {
        next.add(
          RiverSideChatMessageReaction(
            emoji: normalized,
            count: 1,
            reacted: true,
            users: const <RiverSideChatReactionUser>[],
          ),
        );
      }
    } else if (action == 'remove' && index >= 0) {
      final current = next[index];
      final count = current.reacted ? current.count - 1 : current.count;
      if (count <= 0) {
        next.removeAt(index);
      } else {
        next[index] = RiverSideChatMessageReaction(
          emoji: current.emoji,
          count: count,
          reacted: false,
          users: current.users,
        );
      }
    }

    next.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      return a.emoji.compareTo(b.emoji);
    });
    return List<RiverSideChatMessageReaction>.unmodifiable(next);
  }

  void _replaceMessageLocal(RiverSideChatMessageItem message) {
    _mutateState(() {
      _messages = _mergeMessages(_messages, <RiverSideChatMessageItem>[
        message,
      ]);
    });
  }

  Future<void> _reactToMessage({
    required RiverSideChatMessageItem item,
    required String emojiName,
    required String action,
  }) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelNeedLogin)),
      );
      return;
    }
    final original = _findMessageById(item.id);
    if (original != null) {
      final optimistic = _copyMessageWithReactions(
        original,
        _applyReactionMutation(
          reactions: original.reactions,
          emojiName: emojiName,
          action: action,
        ),
      );
      _replaceMessageLocal(optimistic);
    }

    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .reactToChatChannelMessage(
            channelId: item.channelId,
            messageId: item.id,
            cookieHeader: cookie,
            emoji: emojiName,
            reactAction: action,
          );
      unawaited(_refreshMessageById(item.id));
    } on RiverSideApiException catch (error) {
      if (original != null) {
        _replaceMessageLocal(original);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (original != null) {
        _replaceMessageLocal(original);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ChatDetailPageState._labelLoadFailed)),
      );
    }
  }

  List<String> _reactionCandidatesForMessage(RiverSideChatMessageItem item) {
    final set = <String>{
      ..._ChatDetailPageState._defaultReactionEmojiNames,
      ...item.reactions
          .map((it) => _emojiKey(it.emoji))
          .where((it) => it.isNotEmpty),
    };
    final values = set.toList(growable: false)..sort();
    return values;
  }

  Future<void> _openReactionPicker(RiverSideChatMessageItem item) async {
    final candidates = _reactionCandidatesForMessage(item);
    if (candidates.isEmpty) {
      return;
    }
    final reacted = item.reactions
        .where((it) => it.reacted)
        .map((it) => _emojiKey(it.emoji))
        .toSet();

    String? selected;
    if (_emojiUrls.isNotEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return RiverStructuredEmojiPicker(
            emojiUrls: _emojiUrls,
            emojiGroups: _emojiGroups,
            onSelected: (key) {
              selected = key;
              Navigator.of(sheetContext).pop();
            },
            title: '选择回应',
          );
        },
      );
    } else {
      selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: candidates
                    .map((emojiName) {
                      final selected = reacted.contains(emojiName);
                      return ChoiceChip(
                        selected: selected,
                        showCheckmark: false,
                        label: _emojiTokenWidget(emojiName, size: 22),
                        onSelected: (_) {
                          Navigator.of(sheetContext).pop(emojiName);
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          );
        },
      );
    }

    final selectedEmoji = selected?.trim() ?? '';
    if (!mounted || selectedEmoji.isEmpty) {
      return;
    }
    final selectedKey = _emojiKey(selectedEmoji);
    final action = reacted.contains(selectedKey) ? 'remove' : 'add';
    await _reactToMessage(item: item, emojiName: selectedEmoji, action: action);
  }

  Future<void> _showMessageActions({
    required RiverSideChatMessageItem item,
    required bool isMine,
    required Offset anchor,
  }) async {
    final reacted = item.reactions
        .where((it) => it.reacted)
        .map((it) => _emojiKey(it.emoji))
        .toSet();
    final quickReactions = _reactionCandidatesForMessage(item).take(7).toList();
    final media = MediaQuery.sizeOf(context);
    final showBelow = anchor.dy < media.height * 0.46;
    final panelTop = showBelow
        ? (anchor.dy + 12).clamp(90.0, media.height - 240).toDouble()
        : null;
    final panelBottom = showBelow
        ? null
        : (media.height - anchor.dy + 12)
              .clamp(90.0, media.height - 240)
              .toDouble();

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).maybePop(),
              ),
            ),
            Positioned(
              left: isMine ? 62 : 12,
              right: isMine ? 12 : 62,
              top: panelTop,
              bottom: panelBottom,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMine)
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Row(
                                  children: [
                                    for (final emojiName in quickReactions) ...[
                                      _ChatReactionCircleButton(
                                        selected: reacted.contains(emojiName),
                                        onTap: () => Navigator.of(
                                          dialogContext,
                                        ).pop('react:$emojiName'),
                                        child: _emojiTokenWidget(
                                          emojiName,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    _ChatReactionCircleButton(
                                      selected: false,
                                      onTap: () => Navigator.of(
                                        dialogContext,
                                      ).pop('react_more'),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (!isMine) const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMine && !item.deleted)
                            ListTile(
                              leading: const Icon(Icons.reply_rounded),
                              title: const Text(
                                _ChatDetailPageState._labelReply,
                              ),
                              onTap: () =>
                                  Navigator.of(dialogContext).pop('reply'),
                            ),
                          ListTile(
                            leading: const Icon(Icons.content_copy_rounded),
                            title: const Text(_ChatDetailPageState._labelCopy),
                            onTap: () =>
                                Navigator.of(dialogContext).pop('copy'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.select_all_rounded),
                            title: const Text('多选'),
                            onTap: () =>
                                Navigator.of(dialogContext).pop('multi_select'),
                          ),
                          if (isMine && !item.deleted)
                            ListTile(
                              leading: const Icon(Icons.delete_outline_rounded),
                              title: const Text(
                                _ChatDetailPageState._labelDelete,
                              ),
                              onTap: () =>
                                  Navigator.of(dialogContext).pop('delete'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }
    if (action.startsWith('react:')) {
      final emoji = _emojiKey(action.substring('react:'.length).trim());
      if (emoji.isNotEmpty) {
        final reactAction = reacted.contains(emoji) ? 'remove' : 'add';
        await _reactToMessage(
          item: item,
          emojiName: emoji,
          action: reactAction,
        );
      }
      return;
    }
    switch (action) {
      case 'react_more':
        await _openReactionPicker(item);
        break;
      case 'reply':
        await _openComposer(replyTo: item);
        break;
      case 'copy':
        await _copyMessageContent(item);
        break;
      case 'multi_select':
        _enterSelectionModeWith(item.id);
        break;
      case 'delete':
        await _deleteMessage(item);
        break;
    }
  }

  Future<void> _copySelectedMessages() async {
    final selected = _selectedMessagesOrdered();
    if (selected.isEmpty) {
      return;
    }
    final text = selected
        .map(
          (it) =>
              it.raw.trim().isNotEmpty ? it.raw.trim() : _stripHtml(it.cooked),
        )
        .where((it) => it.trim().isNotEmpty)
        .join('\n\n');
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_ChatDetailPageState._labelCopied)),
    );
    _exitSelectionMode();
  }

  Future<void> _replySelectedMessage() async {
    final selected = _selectedMessagesOrdered();
    if (selected.isEmpty) {
      return;
    }
    final target = selected.last;
    _exitSelectionMode();
    await _openComposer(replyTo: target);
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openUserProfileSheetForMessage({
    required RiverSideChatMessageItem item,
    String? heroAvatarTag,
    String? heroNameTag,
  }) async {
    final username = item.username.trim();
    if (username.isEmpty) {
      return;
    }
    await showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: username,
      displayName: _displayName(item),
      avatarUrl: _resolveForumUrl(item.avatarUrl),
      heroTagAvatar: heroAvatarTag,
      heroTagName: heroNameTag,
    );
  }

  Future<void> _scrollToBottomAnimated() async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    Future<void> goAfterFrame() async {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.position.pixels - target).abs() <= 1) {
        return;
      }
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    await goAfterFrame();
    await goAfterFrame();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
  }
}
