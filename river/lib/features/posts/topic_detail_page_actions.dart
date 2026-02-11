part of 'topic_detail_page.dart';

extension _TopicDetailPageCommentActions on _TopicDetailPageState {
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

  Future<String?> _uploadReplyImage(String fileName, List<int> bytes) async {
    final cookieHeader = _activeCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      throw const RiverSideApiException(
        _TopicDetailPageState._labelReplyNeedLogin,
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

  void _appendPublishedReply(RiverSideTopicPostDetail created) {
    final detail = _detail;
    if (detail == null || created.topicId != detail.topicId) {
      return;
    }

    if (created.postNumber <= 1 || detail.mainPost.id == created.id) {
      _detail = detail.copyWith(mainPost: created);
      _loadedPostIds.add(created.id);
      return;
    }

    final nextComments = <RiverSideTopicPostDetail>[..._comments];
    final existingIndex = nextComments.indexWhere(
      (item) => item.id == created.id,
    );
    var added = false;
    if (existingIndex >= 0) {
      nextComments[existingIndex] = created;
    } else {
      added = true;
      nextComments.add(created);
      _loadedPostIds.add(created.id);
    }
    nextComments.sort((a, b) => a.postNumber.compareTo(b.postNumber));

    final nextStream = detail.streamPostIds.contains(created.id)
        ? detail.streamPostIds
        : <int>[...detail.streamPostIds, created.id];

    _comments = nextComments;
    _detail = detail.copyWith(
      replyCount: added ? detail.replyCount + 1 : detail.replyCount,
      streamPostIds: nextStream,
      loadedPostIds: <int>{..._loadedPostIds},
    );
  }

  Future<bool> _submitReply({
    required int topicId,
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
          content: Text(_TopicDetailPageState._labelReplyNeedLogin),
        ),
      );
      return false;
    }

    try {
      final payload = _buildReplyPayload(
        markdown: markdown,
        quoteUsername: quoteUsername,
        quotePostNumber: replyToPostNumber,
        quoteTopicId: quoteTopicId ?? topicId,
        quoteContent: quoteContent,
      );
      final created = await widget.dependencies.accountStore.riverSideApiClient
          .createTopicReply(
            topicId: topicId,
            raw: payload,
            replyToPostNumber: replyToPostNumber,
            cookieHeader: cookieHeader,
          );
      if (!mounted) {
        return false;
      }

      _mutateState(() {
        _appendPublishedReply(created);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_TopicDetailPageState._labelReplySuccess)),
      );

      if (topicId == (_detail?.topicId ?? -1)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _jumpToPostNumber(
            postNumber: created.postNumber,
            topicId: created.topicId,
          );
        });
      }
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
    required int topicId,
    int? replyToPostNumber,
    String? quoteUsername,
    int? quoteTopicId,
    String? quoteContent,
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return RiverMarkdownEditor(
          title: _TopicDetailPageState._labelReplyEditorTitle,
          submitLabel: _TopicDetailPageState._labelReply,
          initialText: '',
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          onUploadImage: _uploadReplyImage,
          onSubmit: (markdown) {
            return _submitReply(
              topicId: topicId,
              markdown: markdown,
              replyToPostNumber: replyToPostNumber,
              quoteUsername: quoteUsername,
              quoteTopicId: quoteTopicId,
              quoteContent: quoteContent,
            );
          },
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
    await Clipboard.setData(ClipboardData(text: post.contentMarkdown));
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
    final detail = _detail;
    if (detail == null) {
      return;
    }

    if (detail.mainPost.id == updated.id) {
      _detail = detail.copyWith(mainPost: updated);
      return;
    }

    final index = _comments.indexWhere((item) => item.id == updated.id);
    if (index < 0) {
      return;
    }
    final next = <RiverSideTopicPostDetail>[..._comments];
    next[index] = updated;
    next.sort((a, b) => a.postNumber.compareTo(b.postNumber));
    _comments = next;
  }

  void _removePostFromState(RiverSideTopicPostDetail post) {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final nextComments = _comments.where((item) => item.id != post.id).toList();
    _comments = nextComments;
    _loadedPostIds.remove(post.id);
    _detail = detail.copyWith(
      replyCount: detail.replyCount > 0 ? detail.replyCount - 1 : 0,
      streamPostIds: detail.streamPostIds.where((id) => id != post.id).toList(),
      loadedPostIds: <int>{..._loadedPostIds},
    );
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
          content: Text(_TopicDetailPageState._labelReplyNeedLogin),
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelEditCommentSuccess),
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
          content: Text(_TopicDetailPageState._labelReplyNeedLogin),
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
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return RiverMarkdownEditor(
          title: _TopicDetailPageState._labelEditCommentTitle,
          submitLabel: _TopicDetailPageState._labelSave,
          initialText: originalRaw,
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          onUploadImage: _uploadReplyImage,
          onSubmit: (markdown) {
            return _submitEditComment(
              sourcePost: original,
              originalRaw: originalRaw,
              nextRaw: markdown,
            );
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
          content: Text(_TopicDetailPageState._labelReplyNeedLogin),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(_TopicDetailPageState._labelDeleteCommentTitle),
          content: const Text(_TopicDetailPageState._labelDeleteCommentHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(_TopicDetailPageState._labelCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(_TopicDetailPageState._labelDelete),
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
      _mutateState(() {
        _removePostFromState(post);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_TopicDetailPageState._labelDeleteCommentSuccess),
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
                  _TopicDetailPageState._labelActionCopyContent,
                ),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              if (own)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text(
                    _TopicDetailPageState._labelActionEditComment,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('edit'),
                ),
              if (own)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text(
                    _TopicDetailPageState._labelActionDeleteComment,
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
}
