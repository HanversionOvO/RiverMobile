part of 'topic_detail_page.dart';

extension _CommentDetailPageActions on _CommentDetailPageState {
  Stream<String> _generateAiContentStreamForEditor(
    RiverMarkdownAiRequest request,
  ) {
    final service = RiverAiService(widget.dependencies.settingsController);
    return service.generateStream(
      instruction: request.instruction,
      currentText: request.currentMarkdown,
      referenceText: request.referenceMarkdown,
    );
  }

  List<_ReactionOption> _availableReactionOptionsForComment() {
    final reactionIds = <String>{};
    reactionIds.addAll(
      _rootPost.reactions.map((item) => item.id).where((id) => id.isNotEmpty),
    );
    for (final post in _replies) {
      reactionIds.addAll(
        post.reactions.map((item) => item.id).where((id) => id.isNotEmpty),
      );
    }
    if (reactionIds.isEmpty) {
      return _defaultReactionOptions;
    }
    final filtered = _defaultReactionOptions
        .where((option) => reactionIds.contains(option.id))
        .toList(growable: false);
    return filtered.isEmpty ? _defaultReactionOptions : filtered;
  }

  Future<void> _onReactPressed(RiverSideTopicPostDetail post) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelReactionNotReady),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<_ReactionOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReactionPickerSheet(
          postId: post.id,
          options: _availableReactionOptionsForComment(),
          currentReactionId: post.currentUserReaction?.id,
          onSelected: (option) {
            _mutateState(() {
              _pendingReactionHeroByPostId[post.id] = option.id;
            });
            Navigator.of(sheetContext).pop(option);
          },
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }

    await _togglePostReaction(
      post: post,
      reactionId: selected.id,
      cookieHeader: cookieHeader,
    );
  }

  Future<void> _togglePostReaction({
    required RiverSideTopicPostDetail post,
    required String reactionId,
    required String cookieHeader,
  }) async {
    _mutateState(() {
      _reactingPostIds.add(post.id);
    });

    try {
      final state = await widget.dependencies.accountStore.riverSideApiClient
          .togglePostReaction(
            postId: post.id,
            reactionId: reactionId,
            cookieHeader: cookieHeader,
          );
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _applyPostReactionState(state);
        _hasMutations = true;
      });
    } on RiverSideApiException catch (error) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _pendingReactionHeroByPostId.remove(post.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _pendingReactionHeroByPostId.remove(post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u70b9\u8d5e\u64cd\u4f5c\u5931\u8d25')),
      );
    } finally {
      _mutateState(() {
        _reactingPostIds.remove(post.id);
      });
    }
  }

  void _applyPostReactionState(RiverSidePostReactionState state) {
    final clearCurrent = state.currentUserReaction == null;
    if (_rootPost.id == state.postId) {
      _rootPost = _rootPost.copyWith(
        reactions: state.reactions,
        currentUserReaction: state.currentUserReaction,
        clearCurrentUserReaction: clearCurrent,
        reactionUsersCount: state.reactionUsersCount,
      );
    }

    final index = _replies.indexWhere((post) => post.id == state.postId);
    if (index >= 0) {
      final next = <RiverSideTopicPostDetail>[..._replies];
      final current = next[index];
      next[index] = current.copyWith(
        reactions: state.reactions,
        currentUserReaction: state.currentUserReaction,
        clearCurrentUserReaction: clearCurrent,
        reactionUsersCount: state.reactionUsersCount,
      );
      _replies = next;
    }

    _pendingReactionHeroByPostId.remove(state.postId);
    _reactionPulseTokenByPostId[state.postId] =
        (_reactionPulseTokenByPostId[state.postId] ?? 0) + 1;
  }

  Future<void> _onReactionStatusPressed({
    required RiverSideTopicPostDetail post,
    required String reactionId,
  }) async {
    try {
      final groups = await widget.dependencies.accountStore.riverSideApiClient
          .fetchPostReactionUsers(
            postId: post.id,
            reactionId: reactionId,
            cookieHeader: _activeCookieHeader(),
          );
      if (!mounted) {
        return;
      }

      RiverSidePostReactionUsersGroup? group;
      for (final item in groups) {
        if (item.id == reactionId) {
          group = item;
          break;
        }
      }
      group ??= groups.isEmpty ? null : groups.first;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return _ReactionUsersSheet(
            postId: post.id,
            reactionId: reactionId,
            group: group,
          );
        },
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
        const SnackBar(
          content: Text(_TopicDetailPageState._labelReactionUsersEmpty),
        ),
      );
    }
  }

  Future<void> _openAuthorProfileSheetForPost(
    RiverSideTopicPostDetail post,
  ) async {
    final avatarHeroTag = _topicPostAuthorAvatarHeroTag(post);
    final nameHeroTag = _topicPostAuthorNameHeroTag(post);
    await showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: post.authorUsername,
      displayName: post.authorDisplayName,
      avatarUrl: post.authorAvatarUrl,
      heroTagAvatar: avatarHeroTag,
      heroTagName: nameHeroTag,
    );
  }

  Future<void> _openMentionProfileFromContent(String username) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      return;
    }
    await showRiverSideUserProfileSheet(
      context: context,
      dependencies: widget.dependencies,
      username: normalized,
    );
  }

  Future<void> _openTopicFromContent(int topicId) async {
    if (topicId <= 0 || topicId == _rootPost.topicId) {
      return;
    }
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => TopicDetailPage(
          dependencies: widget.dependencies,
          topicId: topicId,
        ),
      ),
    );
  }

  String _buildReplyPayload({
    required String markdown,
    String? quoteUsername,
    int? quotePostNumber,
    int? quoteTopicId,
    String? quoteContent,
  }) {
    final body = markdown.trim();
    if (body.isEmpty) {
      return '';
    }

    final username = quoteUsername?.trim() ?? '';
    final postNumber = quotePostNumber ?? 0;
    final topicId = quoteTopicId ?? 0;
    final content = (quoteContent ?? '').trim();
    if (username.isEmpty ||
        postNumber <= 0 ||
        topicId <= 0 ||
        content.isEmpty) {
      return body;
    }
    return '[quote="$username, post:$postNumber, topic:$topicId"]\n'
        '$content\n'
        '[/quote]\n\n'
        '$body';
  }

  RiverMarkdownDraftEntry _mapDraftToEditorEntry(RiverSideComposerDraft draft) {
    final subtitle = draft.markdown.trim().isNotEmpty
        ? draft.markdown.trim()
        : '无内容';
    return RiverMarkdownDraftEntry(
      draftKey: draft.draftKey,
      sequence: draft.sequence,
      markdown: draft.markdown,
      title: draft.title,
      subtitle: subtitle,
      updatedAt: draft.createdAt,
    );
  }

  String _replyDraftKey({int? replyToPostNumber}) {
    return 'river_reply_${_rootPost.topicId}_${replyToPostNumber ?? 0}';
  }

  String _editDraftKey(int postId) => 'river_edit_$postId';

  Future<List<RiverMarkdownDraftEntry>> _loadCommentDetailDraftsForEditor({
    required bool Function(RiverSideComposerDraft draft) filter,
  }) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return const <RiverMarkdownDraftEntry>[];
    }
    final drafts = await widget.dependencies.accountStore.riverSideApiClient
        .fetchComposerDrafts(cookieHeader: cookie, offset: 0, limit: 50);
    return drafts
        .where(filter)
        .map(_mapDraftToEditorEntry)
        .toList(growable: false);
  }

  Future<bool> _deleteCommentDetailDraftForEditor(
    RiverMarkdownDraftEntry draft,
  ) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return false;
    }
    await widget.dependencies.accountStore.riverSideApiClient
        .deleteComposerDraft(
          draftKey: draft.draftKey,
          sequence: draft.sequence,
          cookieHeader: cookie,
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('草稿已删除')));
    }
    return true;
  }

  Future<String?> _uploadReplyImage(String fileName, List<int> bytes) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      throw const RiverSideApiException(
        _CommentDetailPageState._labelReplyNeedLogin,
      );
    }
    final uploaded = await widget.dependencies.accountStore.riverSideApiClient
        .uploadComposerImage(
          cookieHeader: cookieHeader,
          fileName: fileName,
          bytes: bytes,
        );
    final resolved = uploaded.startsWith('upload://')
        ? uploaded
        : _resolveForumUrl(uploaded);
    return '![]($resolved)';
  }

  Future<bool> _submitReply({
    required String markdown,
    int? replyToPostNumber,
    String? quoteUsername,
    int? quoteTopicId,
    String? quoteContent,
  }) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelReplyNeedLogin),
        ),
      );
      return false;
    }

    try {
      final payload = _buildReplyPayload(
        markdown: markdown,
        quoteUsername: quoteUsername,
        quotePostNumber: replyToPostNumber,
        quoteTopicId: quoteTopicId ?? _rootPost.topicId,
        quoteContent: quoteContent,
      );
      await widget.dependencies.accountStore.riverSideApiClient
          .createTopicReply(
            topicId: _rootPost.topicId,
            raw: payload,
            replyToPostNumber: replyToPostNumber,
            cookieHeader: cookieHeader,
          );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelReplySuccess),
        ),
      );
      await _loadData();
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
        const SnackBar(content: Text('\u56de\u590d\u53d1\u9001\u5931\u8d25')),
      );
      return false;
    }
  }

  Future<void> _openReplyComposer({
    int? replyToPostNumber,
    String? quoteUsername,
    int? quoteTopicId,
    String? quoteContent,
  }) async {
    final draftKey = _replyDraftKey(replyToPostNumber: replyToPostNumber);

    Future<RiverMarkdownDraftEntry?> loadCurrentDraft() async {
      final cookie = _activeCookieHeader();
      if (cookie == null || cookie.trim().isEmpty) {
        return null;
      }
      final draft = await widget.dependencies.accountStore.riverSideApiClient
          .fetchComposerDraft(draftKey: draftKey, cookieHeader: cookie);
      if (draft == null) {
        return null;
      }
      return _mapDraftToEditorEntry(draft);
    }

    Future<RiverMarkdownDraftEntry?> saveDraft(
      String markdown,
      int? sequence,
    ) async {
      final cookie = _activeCookieHeader();
      if (cookie == null || cookie.trim().isEmpty) {
        return null;
      }
      final nextSequence = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .saveComposerDraft(
            draftKey: draftKey,
            sequence: sequence ?? 0,
            data: <String, dynamic>{
              'reply': markdown,
              'action': 'reply',
              'topicId': _rootPost.topicId,
              'postId': replyToPostNumber,
              'metaData': null,
              'archetypeId': 'regular',
            },
            cookieHeader: cookie,
          );
      return RiverMarkdownDraftEntry(
        draftKey: draftKey,
        sequence: nextSequence,
        markdown: markdown,
        title: '回复草稿',
        subtitle: markdown.trim(),
        updatedAt: DateTime.now(),
      );
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return RiverMarkdownEditor(
          title: _TopicDetailPageState._labelReplyEditorTitle,
          submitLabel: _TopicDetailPageState._labelReply,
          initialText: '',
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          aiScene: RiverMarkdownAiScene.topicReply,
          aiReplyReferenceText: quoteContent,
          onAiGenerateStream: _generateAiContentStreamForEditor,
          maxHeight: MediaQuery.sizeOf(context).height * 0.74,
          onUploadImage: _uploadReplyImage,
          onLoadCurrentDraft: loadCurrentDraft,
          onSaveDraft: saveDraft,
          onLoadDrafts: () => _loadCommentDetailDraftsForEditor(
            filter: (draft) {
              if (draft.action == 'reply' &&
                  draft.topicId == _rootPost.topicId) {
                return true;
              }
              return draft.draftKey == draftKey;
            },
          ),
          onDeleteDraft: _deleteCommentDetailDraftForEditor,
          onSubmit: (markdown) => _submitReply(
            markdown: markdown,
            replyToPostNumber: replyToPostNumber,
            quoteUsername: quoteUsername,
            quoteTopicId: quoteTopicId,
            quoteContent: quoteContent,
          ),
        );
      },
    );
  }

  bool _isOwnComment(RiverSideTopicPostDetail post) {
    final active = widget.dependencies.accountStore.activeRiverSideUsername;
    if (active == null || active.trim().isEmpty) {
      return false;
    }
    return active.toLowerCase() == post.authorUsername.toLowerCase();
  }

  Future<void> _copyCommentContent(RiverSideTopicPostDetail post) async {
    final pureContent = _stripQuotedMarkdown(post.contentMarkdown);
    await Clipboard.setData(ClipboardData(text: pureContent));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('\u5df2\u590d\u5236\u5230\u526a\u8d34\u677f'),
      ),
    );
  }

  void _replacePostInState(RiverSideTopicPostDetail updated) {
    if (_rootPost.id == updated.id) {
      _rootPost = updated;
      return;
    }

    final index = _replies.indexWhere((item) => item.id == updated.id);
    if (index < 0) {
      return;
    }
    final next = <RiverSideTopicPostDetail>[..._replies];
    next[index] = updated;
    next.sort((a, b) => a.postNumber.compareTo(b.postNumber));
    _replies = next;
  }

  void _removePostFromState(RiverSideTopicPostDetail post) {
    _replies = _replies.where((item) => item.id != post.id).toList();
  }

  Future<bool> _submitEditComment({
    required RiverSideTopicPostDetail sourcePost,
    required String originalRaw,
    required String nextRaw,
  }) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelReplyNeedLogin),
        ),
      );
      return false;
    }

    try {
      final edited = await widget.dependencies.accountStore.riverSideApiClient
          .editPost(
            postId: sourcePost.id,
            topicId: sourcePost.topicId,
            raw: nextRaw,
            originalRaw: originalRaw,
            cookieHeader: cookieHeader,
          );
      if (!mounted) {
        return false;
      }
      _mutateState(() {
        _replacePostInState(edited);
        _hasMutations = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelEditCommentSuccess),
        ),
      );
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
        const SnackBar(content: Text('\u7f16\u8f91\u8bc4\u8bba\u5931\u8d25')),
      );
      return false;
    }
  }

  Future<void> _openEditCommentComposer(RiverSideTopicPostDetail post) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelReplyNeedLogin),
        ),
      );
      return;
    }

    RiverSideTopicPostDetail original = post;
    try {
      original = await widget.dependencies.accountStore.riverSideApiClient
          .fetchPostById(postId: post.id, cookieHeader: cookieHeader);
    } catch (_) {}

    if (!mounted) {
      return;
    }
    final originalRaw = original.contentMarkdown;
    final draftKey = _editDraftKey(post.id);

    Future<RiverMarkdownDraftEntry?> loadCurrentDraft() async {
      final draft = await widget.dependencies.accountStore.riverSideApiClient
          .fetchComposerDraft(draftKey: draftKey, cookieHeader: cookieHeader);
      if (draft == null) {
        return null;
      }
      return _mapDraftToEditorEntry(draft);
    }

    Future<RiverMarkdownDraftEntry?> saveDraft(
      String markdown,
      int? sequence,
    ) async {
      final nextSequence = await widget
          .dependencies
          .accountStore
          .riverSideApiClient
          .saveComposerDraft(
            draftKey: draftKey,
            sequence: sequence ?? 0,
            data: <String, dynamic>{
              'reply': markdown,
              'action': 'edit',
              'topicId': post.topicId,
              'postId': post.id,
              'original_text': originalRaw,
              'metaData': null,
            },
            cookieHeader: cookieHeader,
          );
      return RiverMarkdownDraftEntry(
        draftKey: draftKey,
        sequence: nextSequence,
        markdown: markdown,
        title: '编辑评论草稿',
        subtitle: markdown.trim(),
        updatedAt: DateTime.now(),
      );
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return RiverMarkdownEditor(
          title: _CommentDetailPageState._labelEditCommentTitle,
          submitLabel: _CommentDetailPageState._labelSave,
          closeOnSubmitSuccess: false,
          initialText: originalRaw,
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          aiScene: RiverMarkdownAiScene.editComment,
          onAiGenerateStream: _generateAiContentStreamForEditor,
          maxHeight: MediaQuery.sizeOf(context).height * 0.74,
          onUploadImage: _uploadReplyImage,
          onLoadCurrentDraft: loadCurrentDraft,
          onSaveDraft: saveDraft,
          onLoadDrafts: () => _loadCommentDetailDraftsForEditor(
            filter: (draft) =>
                draft.action == 'edit' || draft.draftKey == draftKey,
          ),
          onDeleteDraft: _deleteCommentDetailDraftForEditor,
          onSubmit: (markdown) async {
            final ok = await _submitEditComment(
              sourcePost: original,
              originalRaw: originalRaw,
              nextRaw: markdown,
            );
            if (ok && sheetContext.mounted) {
              Navigator.of(sheetContext).pop(true);
            }
            return ok;
          },
        );
      },
    );
  }

  Future<void> _deleteComment(RiverSideTopicPostDetail post) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelReplyNeedLogin),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(_CommentDetailPageState._labelDeleteCommentTitle),
          content: const Text(_CommentDetailPageState._labelDeleteCommentHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(_CommentDetailPageState._labelCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(_CommentDetailPageState._labelDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      await widget.dependencies.accountStore.riverSideApiClient.deletePost(
        postId: post.id,
        topicId: post.topicId,
        postNumber: post.postNumber,
        cookieHeader: cookieHeader,
      );
      if (!mounted) {
        return;
      }
      if (post.id == _rootPost.id) {
        Navigator.of(context).pop(true);
        return;
      }
      _mutateState(() {
        _removePostFromState(post);
        _hasMutations = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_CommentDetailPageState._labelDeleteCommentSuccess),
        ),
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
        const SnackBar(content: Text('\u5220\u9664\u8bc4\u8bba\u5931\u8d25')),
      );
    }
  }

  Future<void> _showCommentActions(RiverSideTopicPostDetail post) async {
    final own = _isOwnComment(post);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text(
                  _CommentDetailPageState._labelActionCopyContent,
                ),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              if (own)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text(
                    _CommentDetailPageState._labelActionEditComment,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('edit'),
                ),
              if (own)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text(
                    _CommentDetailPageState._labelActionDeleteComment,
                  ),
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
      case 'copy':
        await _copyCommentContent(post);
        break;
      case 'edit':
        await _openEditCommentComposer(post);
        break;
      case 'delete':
        await _deleteComment(post);
        break;
    }
  }

  Future<void> _showQuoteBottomSheet(_QuoteBlock quote) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _CommentDetailPageState._labelQuoteTitle,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: _MarkdownContent(
                      markdown: quote.contentMarkdown,
                      cookieHeader: _activeCookieHeader(),
                      emojiUrls: _emojiUrls,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
