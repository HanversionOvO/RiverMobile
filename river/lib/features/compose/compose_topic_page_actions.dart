part of 'compose_topic_page.dart';

extension _ComposeTopicPageActions on _ComposeTopicPageState {
  Future<void> _loadMetaData() async {
    final cookie = _activeCookieHeader();
    _mutateState(() {
      _loadingMeta = true;
    });

    try {
      final api = widget.dependencies.accountStore.riverSideApiClient;
      final categoriesFuture = api.fetchCategories(cookieHeader: cookie);
      final emojiFuture = api
          .fetchEmojiUrlMap(cookieHeader: cookie)
          .catchError((_) => const <String, String>{});
      final emojiGroupsFuture = api
          .fetchEmojiGroups(cookieHeader: cookie)
          .catchError((_) => const <String, List<String>>{});

      final categories = await categoriesFuture;
      final emojis = await emojiFuture;
      final emojiGroups = await emojiGroupsFuture;

      if (!mounted) {
        return;
      }
      _mutateState(() {
        _categories = categories;
        _emojiUrls = emojis;
        _emojiGroups = emojiGroups;
        _loadingMeta = false;
        if (_selectedCategoryId != null &&
            !_categories.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mutateState(() {
        _loadingMeta = false;
      });
    }
  }

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
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return RiverMarkdownEditor(
          title: '编辑帖子内容',
          hintText: '请输入帖子正文内容',
          submitLabel: '保存内容',
          initialText: _contentMarkdown,
          emojiUrls: _emojiUrls,
          emojiGroups: _emojiGroups,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          onUploadImage: _uploadImage,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帖子内容已保存')));
    }
  }

  Future<void> _openCategoryPicker() async {
    if (_categories.isEmpty && !_loadingMeta) {
      await _loadMetaData();
    }
    if (!mounted) {
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可选板块')));
      return;
    }

    final selected = await showModalBottomSheet<RiverSideCategoryOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return RiverSideCategoryPickerSheet(
          groups: buildRiverSideCategoryGroups(_categories),
          selectedCategoryId: _selectedCategoryId,
          onSelected: (category) => Navigator.of(sheetContext).pop(category),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
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

  bool get _hasDraftContent {
    return _titleController.text.trim().isNotEmpty ||
        _selectedCategoryId != null ||
        _contentMarkdown.trim().isNotEmpty;
  }

  Future<void> _clearDraftWithConfirm() async {
    if (!_hasDraftContent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可清除的内容')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空草稿'),
          content: const Text('确定清空已编辑的标题、板块和正文内容吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    _mutateState(() {
      _titleController.clear();
      _selectedCategoryId = null;
      _contentMarkdown = '';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空发帖草稿')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_ComposeTopicPageState._labelNeedLogin)),
      );
      return false;
    }
    if (_titleController.text.trim().isEmpty) {
      if (focusTitle) {
        _titleFocusNode.requestFocus();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入帖子标题')));
      return false;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择发帖板块')));
      return false;
    }
    if (_contentMarkdown.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先编辑帖子内容')));
      return false;
    }
    return true;
  }

  Future<void> _previewTopic() async {
    if (!_validateBeforeSubmit(focusTitle: true, requireLogin: false)) {
      return;
    }
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
    if (_publishing) {
      return;
    }
    if (!_validateBeforeSubmit(focusTitle: true, requireLogin: true)) {
      return;
    }

    final cookie = _activeCookieHeader()!;
    final title = _titleController.text.trim();
    final categoryId = _selectedCategoryId!;
    final raw = _contentMarkdown.trim();

    _mutateState(() {
      _publishing = true;
    });
    try {
      final result = await widget.dependencies.accountStore.riverSideApiClient
          .createTopic(
            title: title,
            raw: raw,
            categoryId: categoryId,
            cookieHeader: cookie,
          );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发帖成功')));
      await Navigator.of(context).push(
        riverPageRoute<void>(
          builder: (_) => TopicDetailPage(
            dependencies: widget.dependencies,
            topicId: result.topicId,
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发帖失败，请稍后重试')));
    } finally {
      if (mounted) {
        _mutateState(() {
          _publishing = false;
        });
      }
    }
  }
}
