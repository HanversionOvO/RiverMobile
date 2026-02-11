part of 'chat_detail_page.dart';

extension _ChatDetailPageActions on _ChatDetailPageState {
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
    final title = replyTo == null
        ? '\u53d1\u9001\u6d88\u606f'
        : '\u56de\u590d @${_displayName(replyTo)}';

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return RiverMarkdownEditor(
          title: title,
          hintText: '\u8bf7\u8f93\u5165\u6d88\u606f\u5185\u5bb9',
          submitLabel: '\u53d1\u9001',
          closeOnSubmitSuccess: true,
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          onUploadImage: _uploadImage,
          onSubmit: (markdown) {
            return _sendMessage(markdown, replyToMessageId: replyTo?.id);
          },
        );
      },
    );
  }

  Future<String?> _uploadImage(String fileName, List<int> bytes) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return null;
    }

    final uploaded = await widget.dependencies.accountStore.riverSideApiClient
        .uploadComposerImage(
          cookieHeader: cookie,
          fileName: fileName,
          bytes: bytes,
        );
    final resolved = uploaded.startsWith('upload://')
        ? '$riverSideBaseUrl/uploads/short-url/${uploaded.substring('upload://'.length)}'
        : _resolveForumUrl(uploaded);
    return '![]($resolved)';
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
      _mutateState(() {
        _messages = _mergeMessages(_messages, <RiverSideChatMessageItem>[
          message,
        ]);
      });
      _jumpToBottom();
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
    try {
      await widget.dependencies.accountStore.riverSideApiClient
          .reactToChatChannelMessage(
            channelId: item.channelId,
            messageId: item.id,
            cookieHeader: cookie,
            emoji: emojiName,
            reactAction: action,
          );
      await _refreshMessageById(item.id);
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

  List<String> _reactionCandidatesForMessage(RiverSideChatMessageItem item) {
    final set = <String>{
      ..._ChatDetailPageState._defaultReactionEmojiNames,
      ...item.reactions
          .map((it) => it.emoji.trim())
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
        .map((it) => it.emoji)
        .toSet();

    final selected = await showModalBottomSheet<String>(
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

    if (!mounted || selected == null || selected.trim().isEmpty) {
      return;
    }
    final action = reacted.contains(selected) ? 'remove' : 'add';
    await _reactToMessage(item: item, emojiName: selected, action: action);
  }

  Future<void> _showMessageActions({
    required RiverSideChatMessageItem item,
    required bool isMine,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine)
                ListTile(
                  leading: const Icon(Icons.add_reaction_outlined),
                  title: const Text(_ChatDetailPageState._labelReact),
                  onTap: () => Navigator.of(sheetContext).pop('react'),
                ),
              if (!isMine && !item.deleted)
                ListTile(
                  leading: const Icon(Icons.reply_outlined),
                  title: const Text(_ChatDetailPageState._labelReply),
                  onTap: () => Navigator.of(sheetContext).pop('reply'),
                ),
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text(_ChatDetailPageState._labelCopy),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              if (isMine && !item.deleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text(_ChatDetailPageState._labelDelete),
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'react':
        await _openReactionPicker(item);
        break;
      case 'reply':
        await _openComposer(replyTo: item);
        break;
      case 'copy':
        await _copyMessageContent(item);
        break;
      case 'delete':
        await _deleteMessage(item);
        break;
    }
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
}
