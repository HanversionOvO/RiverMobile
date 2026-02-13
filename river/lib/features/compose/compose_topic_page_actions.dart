part of 'compose_topic_page.dart';

extension _ComposeTopicPageActions on _ComposeTopicPageState {
  Stream<String> _generateAiContentStreamForCompose(
    RiverMarkdownAiRequest request,
  ) {
    final service = RiverAiService(widget.dependencies.settingsController);
    return service.generateStream(
      instruction: request.instruction,
      currentText: request.currentMarkdown,
      referenceText: request.referenceMarkdown,
    );
  }

  String _topicDraftKey() {
    final username =
        widget.dependencies.accountStore.activeRiverSideUsername?.trim() ?? '';
    if (username.isEmpty) {
      return 'river_topic_guest';
    }
    return 'river_topic_${username.toLowerCase()}';
  }

  RiverMarkdownDraftEntry _mapDraftToEditorEntry(RiverSideComposerDraft draft) {
    final subtitle = draft.markdown.trim().isNotEmpty
        ? draft.markdown.trim()
        : '无内容';
    final title = draft.title.trim().isNotEmpty ? draft.title.trim() : '发帖草稿';
    return RiverMarkdownDraftEntry(
      draftKey: draft.draftKey,
      sequence: draft.sequence,
      markdown: draft.markdown,
      title: title,
      subtitle: subtitle,
      updatedAt: draft.createdAt,
    );
  }

  Future<List<RiverMarkdownDraftEntry>> _loadComposeDraftsForEditor({
    required String draftKey,
  }) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      return const <RiverMarkdownDraftEntry>[];
    }
    final drafts = await widget.dependencies.accountStore.riverSideApiClient
        .fetchComposerDrafts(cookieHeader: cookie, offset: 0, limit: 50);
    return drafts
        .where((draft) {
          final action = draft.action.trim().toLowerCase();
          return draft.draftKey == draftKey ||
              action == 'createtopic' ||
              action == 'create_topic';
        })
        .map(_mapDraftToEditorEntry)
        .toList(growable: false);
  }

  Future<bool> _deleteComposeDraftForEditor(
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

  Future<void> _loadMetaData() async {
    final cookie = _activeCookieHeader();
    _mutateState(() => _loadingMeta = true);

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final activeUsername =
          widget.dependencies.accountStore.activeRiverSideUsername;
      final categoriesFuture = (() async {
        var categories = await RiverSideCategoryStore.instance.load(
          apiClient: api,
          username: activeUsername,
          cookieHeader: cookie,
        );
        if (cookie != null && cookie.trim().isNotEmpty && categories.isEmpty) {
          categories = await RiverSideCategoryStore.instance.load(
            apiClient: api,
            username: activeUsername,
            cookieHeader: cookie,
            forceRefresh: true,
          );
        }
        return categories;
      })();
      final emojiFuture = api
          .fetchEmojiUrlMap(cookieHeader: cookie)
          .catchError((_) => const <String, String>{});
      final emojiGroupsFuture = api
          .fetchEmojiGroups(cookieHeader: cookie)
          .catchError((_) => const <String, List<String>>{});

      final categories = await categoriesFuture;
      final emojis = await emojiFuture;
      final emojiGroups = await emojiGroupsFuture;

      if (!mounted) return;
      _mutateState(() {
        _categories = categories;
        _emojiUrls = emojis;
        _emojiGroups = emojiGroups;
        _loadingMeta = false;
        // 如果已选的分类不在新列表中，重置
        if (_selectedCategoryId != null &&
            !_categories.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      _mutateState(() => _loadingMeta = false);
    }
  }

  // ... _uploadImage 方法保持不变 ...
  Future<String?> _uploadImage(String fileName, List<int> bytes) async {
    final cookie = _activeCookieHeader();
    if (cookie == null || cookie.trim().isEmpty) {
      throw const RiverSideApiException(_ComposeTopicPageState._labelNeedLogin);
    }
    final uploaded = await widget.dependencies.accountStore.riverSideApiClient
        .uploadComposerImage(
          cookieHeader: cookie,
          fileName: fileName,
          bytes: bytes,
        );
    final normalized = uploaded.startsWith('upload://')
        ? uploaded
        : _resolveForumUrl(uploaded);
    return '![]($normalized)';
  }

  Future<void> _openEditor() async {
    HapticFeedback.lightImpact();
    final draftKey = _topicDraftKey();

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
      if (mounted) {
        _mutateState(() {
          if (_titleController.text.trim().isEmpty &&
              draft.title.trim().isNotEmpty) {
            _titleController.text = draft.title.trim();
          }
          if (_selectedCategoryId == null && draft.categoryId != null) {
            _selectedCategoryId = draft.categoryId;
          }
        });
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
              'action': 'createTopic',
              'title': _titleController.text.trim(),
              'categoryId': _selectedCategoryId,
              'archetypeId': 'regular',
            },
            cookieHeader: cookie,
          );
      final draftTitle = _titleController.text.trim().isEmpty
          ? '发帖草稿'
          : _titleController.text.trim();
      return RiverMarkdownDraftEntry(
        draftKey: draftKey,
        sequence: nextSequence,
        markdown: markdown,
        title: draftTitle,
        subtitle: markdown.trim(),
        updatedAt: DateTime.now(),
      );
    }

    // 打开全屏编辑器
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return RiverMarkdownEditor(
          title: '正文',
          hintText: '在这里输入内容...',
          submitLabel: '确认',
          initialText: _contentMarkdown,
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92, // 更高的占比
          onUploadImage: _uploadImage,
          onLoadCurrentDraft: loadCurrentDraft,
          onSaveDraft: saveDraft,
          onLoadDrafts: () => _loadComposeDraftsForEditor(draftKey: draftKey),
          onDeleteDraft: _deleteComposeDraftForEditor,
          aiScene: RiverMarkdownAiScene.topicCompose,
          onAiGenerateStream: _generateAiContentStreamForCompose,
          onSubmit: (markdown) async {
            _mutateState(() {
              _contentMarkdown = markdown;
            });
            return true;
          },
        );
      },
    );
    if (saved == true && mounted) {
      // 可选：显示一个小提示，或者静默保存
    }
  }

  Future<void> _openCategoryPicker() async {
    HapticFeedback.selectionClick();
    if (_categories.isEmpty && !_loadingMeta) {
      await _loadMetaData();
    }
    if (!mounted) return;
    if (_categories.isEmpty) {
      _showToast('暂无可选板块', isError: true);
      return;
    }

    final selected = await showModalBottomSheet<RiverSideCategoryOption?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return RiverSideCategoryPickerSheet(
          initialCategories: _categories,
          selectedCategoryId: _selectedCategoryId,
          allowSelectAll: false,
          onRefreshCategories: ({bool forceRefresh = false}) async {
            final cookieHeader = _activeCookieHeader();
            final categories = await RiverSideCategoryStore.instance.load(
              apiClient: widget.dependencies.accountStore.riverSideApiClient,
              username:
                  widget.dependencies.accountStore.activeRiverSideUsername,
              cookieHeader: cookieHeader,
              forceRefresh: forceRefresh,
            );
            if (mounted) {
              _mutateState(() {
                _categories = categories;
                if (_selectedCategoryId != null &&
                    !_categories.any(
                      (item) => item.id == _selectedCategoryId,
                    )) {
                  _selectedCategoryId = null;
                }
              });
            }
            return categories;
          },
          onSelected: (category) {
            if (category == null) {
              return;
            }
            Navigator.of(sheetContext).pop(category);
          },
        );
      },
    );
    if (!mounted || selected == null) return;
    _mutateState(() {
      _selectedCategoryId = selected.id;
    });
  }

  RiverSideCategoryOption? _selectedCategory() {
    return findRiverSideCategoryById(
      id: _selectedCategoryId,
      categories: _categories,
    );
  }

  String _displayCategoryName(RiverSideCategoryOption category) {
    return displayRiverSideCategoryName(
      category: category,
      allCategories: _categories,
    );
  }

  bool _validateBeforeSubmit({
    required bool focusTitle,
    required bool requireLogin,
  }) {
    if (requireLogin && _activeCookieHeader() == null) {
      _showToast(_ComposeTopicPageState._labelNeedLogin, isError: true);
      return false;
    }
    if (_titleController.text.trim().isEmpty) {
      if (focusTitle) _titleFocusNode.requestFocus();
      _showToast('标题还是要有的', isError: true);
      return false;
    }
    if (_selectedCategoryId == null) {
      // 尝试自动弹出选择器
      _openCategoryPicker();
      _showToast('请选择一个发布板块', isError: true);
      return false;
    }
    if (_contentMarkdown.trim().isEmpty) {
      _openEditor(); // 自动打开编辑器
      _showToast('内容不能为空', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _previewTopic() async {
    HapticFeedback.lightImpact();
    if (!_validateBeforeSubmit(focusTitle: false, requireLogin: false)) return;

    final category = _selectedCategory();
    await Navigator.of(context).push(
      riverPageRoute<void>(
        builder: (_) => ComposeTopicPreviewPage(
          title: _titleController.text.trim(),
          categoryName: category == null ? '' : _displayCategoryName(category),
          markdown: _contentMarkdown,
          author: _activeAccount,
        ),
      ),
    );
  }

  Future<void> _publishTopic() async {
    if (_publishing) return;
    HapticFeedback.heavyImpact(); // 强震动反馈

    if (!_validateBeforeSubmit(focusTitle: true, requireLogin: true)) return;

    final cookie = _activeCookieHeader()!;
    final title = _titleController.text.trim();
    final categoryId = _selectedCategoryId!;
    final raw = _contentMarkdown.trim();

    _mutateState(() => _publishing = true);

    try {
      final result = await widget.dependencies.accountStore.riverSideApiClient
          .createTopic(
            title: title,
            raw: raw,
            categoryId: categoryId,
            cookieHeader: cookie,
          );
      if (!mounted) return;

      _showToast('发布成功！');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      // 使用 replacement 跳转，防止返回到编辑页
      await Navigator.of(context).pushReplacement(
        riverPageRoute<void>(
          builder: (_) => TopicDetailPage(
            dependencies: widget.dependencies,
            topicId: result.topicId,
          ),
        ),
      );
    } on RiverSideApiException catch (error) {
      if (!mounted) return;
      _showToast(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showToast('发布失败，请检查网络', isError: true);
    } finally {
      if (mounted) {
        _mutateState(() => _publishing = false);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF333333), // 深色背景
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
