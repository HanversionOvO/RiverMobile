import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

typedef RiverMarkdownSubmitCallback = Future<bool> Function(String markdown);
typedef RiverMarkdownImageUploadCallback =
    Future<String?> Function(String fileName, List<int> bytes);
typedef RiverMarkdownDraftLoadCurrentCallback =
    Future<RiverMarkdownDraftEntry?> Function();
typedef RiverMarkdownDraftSaveCallback =
    Future<RiverMarkdownDraftEntry?> Function(String markdown, int? sequence);
typedef RiverMarkdownDraftLoadListCallback =
    Future<List<RiverMarkdownDraftEntry>> Function();
typedef RiverMarkdownDraftDeleteCallback =
    Future<bool> Function(RiverMarkdownDraftEntry draft);
typedef RiverMarkdownAiGenerateCallback =
    Future<String?> Function(RiverMarkdownAiRequest request);
typedef RiverMarkdownAiGenerateStreamCallback =
    Stream<String> Function(RiverMarkdownAiRequest request);

class RiverMarkdownDraftEntry {
  const RiverMarkdownDraftEntry({
    required this.draftKey,
    required this.sequence,
    required this.markdown,
    this.title = '',
    this.subtitle = '',
    this.updatedAt,
  });

  final String draftKey;
  final int sequence;
  final String markdown;
  final String title;
  final String subtitle;
  final DateTime? updatedAt;
}

enum RiverMarkdownAiScene { generic, topicReply, topicCompose, editComment }

class RiverMarkdownAiRequest {
  const RiverMarkdownAiRequest({
    required this.scene,
    required this.instruction,
    required this.currentMarkdown,
    this.referenceMarkdown,
  });

  final RiverMarkdownAiScene scene;
  final String instruction;
  final String currentMarkdown;
  final String? referenceMarkdown;
}

enum _EditorMode { edit, preview }

class RiverMarkdownEditor extends StatefulWidget {
  const RiverMarkdownEditor({
    super.key,
    required this.onSubmit,
    this.onUploadImage,
    this.title,
    this.hintText,
    this.submitLabel,
    this.initialText = '',
    this.emojiUrls = const <String, String>{},
    this.emojiGroups = const <String, List<String>>{},
    this.closeOnSubmitSuccess = true,
    this.autofocus = true,
    this.maxHeight = 0,
    this.enablePreview = true,
    this.onLoadCurrentDraft,
    this.onSaveDraft,
    this.onLoadDrafts,
    this.onDeleteDraft,
    this.onAiGenerate,
    this.onAiGenerateStream,
    this.aiScene = RiverMarkdownAiScene.generic,
    this.aiReplyReferenceText,
  });

  final RiverMarkdownSubmitCallback onSubmit;
  final RiverMarkdownImageUploadCallback? onUploadImage;
  final String? title;
  final String? hintText;
  final String? submitLabel;
  final String initialText;
  final Map<String, String> emojiUrls;
  final Map<String, List<String>> emojiGroups;
  final bool closeOnSubmitSuccess;
  final bool autofocus;
  final double maxHeight;
  final bool enablePreview;
  final RiverMarkdownDraftLoadCurrentCallback? onLoadCurrentDraft;
  final RiverMarkdownDraftSaveCallback? onSaveDraft;
  final RiverMarkdownDraftLoadListCallback? onLoadDrafts;
  final RiverMarkdownDraftDeleteCallback? onDeleteDraft;
  final RiverMarkdownAiGenerateCallback? onAiGenerate;
  final RiverMarkdownAiGenerateStreamCallback? onAiGenerateStream;
  final RiverMarkdownAiScene aiScene;
  final String? aiReplyReferenceText;

  @override
  State<RiverMarkdownEditor> createState() => _RiverMarkdownEditorState();
}

class _RiverMarkdownEditorState extends State<RiverMarkdownEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  Timer? _draftSaveDebounce;

  bool _submitting = false;
  bool _uploadingImage = false;
  bool _loadingDraft = false;
  bool _savingDraft = false;
  bool _generatingAi = false;
  bool _showAiThinkingHint = false;
  _EditorMode _mode = _EditorMode.edit;
  bool _sheetExpanded = false;
  int? _draftSequence;
  String _lastDraftSavedContent = '';
  DateTime? _lastDraftSavedAt;

  bool get _draftEnabled => widget.onSaveDraft != null;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    if (widget.initialText.isNotEmpty) {
      _controller.selection = TextSelection.collapsed(
        offset: widget.initialText.length,
      );
      _lastDraftSavedContent = widget.initialText;
    }
    _controller.addListener(_onEditorTextChanged);
    _loadCurrentDraft();
  }

  @override
  void dispose() {
    _draftSaveDebounce?.cancel();
    _controller.removeListener(_onEditorTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEditorTextChanged() {
    if (!_draftEnabled) {
      return;
    }
    if (_controller.text.trim().isEmpty) {
      return;
    }
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 1300), () {
      _saveDraft(showSnack: false);
    });
  }

  Future<void> _loadCurrentDraft() async {
    final callback = widget.onLoadCurrentDraft;
    if (callback == null) {
      return;
    }

    setState(() => _loadingDraft = true);
    try {
      final draft = await callback();
      if (!mounted || draft == null) {
        return;
      }
      _draftSequence = draft.sequence;
      if (_controller.text.trim().isEmpty && draft.markdown.trim().isNotEmpty) {
        _controller.text = draft.markdown;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
      _lastDraftSavedContent = _controller.text;
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _loadingDraft = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnack('内容不能为空', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await widget.onSubmit(text);
      if (!mounted) return;
      if (ok && widget.closeOnSubmitSuccess) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack('发送失败: $error', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveDraft({required bool showSnack}) async {
    final callback = widget.onSaveDraft;
    if (callback == null || _savingDraft) {
      return;
    }

    final markdown = _controller.text;
    if (markdown.trim().isEmpty) {
      if (showSnack) {
        _showSnack('内容为空，未保存草稿', isError: true);
      }
      return;
    }
    if (!showSnack && markdown == _lastDraftSavedContent) {
      return;
    }

    setState(() => _savingDraft = true);
    try {
      final saved = await callback(markdown, _draftSequence);
      if (!mounted) {
        return;
      }
      if (saved != null) {
        _draftSequence = saved.sequence;
      }
      _lastDraftSavedContent = markdown;
      _lastDraftSavedAt = DateTime.now();
      if (showSnack) {
        _showSnack('草稿已保存');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (showSnack) {
        _showSnack('草稿保存失败: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _openDraftBox() async {
    final callback = widget.onLoadDrafts;
    if (callback == null) {
      _showSnack('当前页面未启用草稿箱');
      return;
    }

    List<RiverMarkdownDraftEntry> drafts = const <RiverMarkdownDraftEntry>[];
    try {
      drafts = await callback();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('草稿箱加载失败: $error', isError: true);
      return;
    }
    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<RiverMarkdownDraftEntry>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        if (drafts.isEmpty) {
          return const SafeArea(
            child: SizedBox(height: 220, child: Center(child: Text('暂无草稿'))),
          );
        }

        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final title = draft.title.trim().isEmpty
                  ? draft.draftKey
                  : draft.title.trim();
              final subtitle = draft.subtitle.trim().isEmpty
                  ? draft.markdown.trim()
                  : draft.subtitle.trim();
              final updated = draft.updatedAt;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle.isEmpty ? '无内容' : subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (updated != null)
                        Text(
                          '${updated.month}-${updated.day} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (widget.onDeleteDraft != null)
                        IconButton(
                          tooltip: '删除草稿',
                          onPressed: () async {
                            final ok = await widget.onDeleteDraft!(draft);
                            if (!context.mounted) {
                              return;
                            }
                            if (ok) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(draft),
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    _controller.text = selected.markdown;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _draftSequence = selected.sequence;
    _lastDraftSavedContent = selected.markdown;
    _showSnack('已加载草稿');
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) return;

    FocusScope.of(context).unfocus();

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploadingImage = true);

      final callback = widget.onUploadImage;
      if (callback == null) {
        _showSnack('当前不支持上传图片', isError: true);
        return;
      }
      final bytes = await picked.readAsBytes();
      final inserted = await callback(picked.name, bytes);
      if (!mounted) return;

      if (inserted != null && inserted.isNotEmpty) {
        _insertText('\n$inserted\n');
        _showSnack('图片已添加');
      } else {
        _showSnack('图片上传失败', isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack('选择图片出错', isError: true);
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
        _focusNode.requestFocus();
      }
    }
  }

  void _showEmojiPicker() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => RiverStructuredEmojiPicker(
        emojiUrls: widget.emojiUrls,
        emojiGroups: widget.emojiGroups,
        onSelected: (key) {
          _insertText(':$key:');
          Navigator.of(context).pop();
        },
      ),
    );
  }

  List<_AiToolAction> _buildAiToolActions() {
    final actions = <_AiToolAction>[
      const _AiToolAction(
        title: '润色表达',
        subtitle: '保持原意，提升语气和可读性',
        instruction: '请润色这段内容，让表达更自然流畅。',
        icon: Icons.auto_fix_high_rounded,
      ),
      const _AiToolAction(
        title: '扩写内容',
        subtitle: '补充细节与上下文',
        instruction: '请扩写这段内容，补充必要细节，但不要偏题。',
        icon: Icons.unfold_more_double_rounded,
      ),
      const _AiToolAction(
        title: '精简内容',
        subtitle: '保留重点并更简洁',
        instruction: '请精简这段内容，保留核心信息。',
        icon: Icons.short_text_rounded,
      ),
      const _AiToolAction(
        title: '纠错优化',
        subtitle: '修正语病和错别字',
        instruction: '请修正错别字、语病，并保持原始语气。',
        icon: Icons.spellcheck_rounded,
      ),
      const _AiToolAction(
        title: '结构化排版',
        subtitle: '优化成清晰的 Markdown 结构',
        instruction: '请将内容改写为结构清晰的 Markdown 格式。',
        icon: Icons.view_list_rounded,
      ),
    ];
    final reference = (widget.aiReplyReferenceText ?? '').trim();
    if (widget.aiScene == RiverMarkdownAiScene.topicReply &&
        reference.isNotEmpty) {
      actions.insert(
        0,
        const _AiToolAction(
          title: '高情商回复',
          subtitle: '基于被回复内容生成更得体的回复',
          instruction: '请基于被回复内容，生成一段高情商且真诚的回复。',
          icon: Icons.favorite_border_rounded,
          needsReference: true,
        ),
      );
    }
    return actions;
  }

  Future<void> _openAiTools() async {
    final hasAi =
        widget.onAiGenerateStream != null || widget.onAiGenerate != null;
    if (!hasAi) {
      _showSnack('当前页面未接入 AI 能力', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final actions = _buildAiToolActions();
    final selected = await showModalBottomSheet<_AiToolAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiToolsSheet(actions: actions),
    );
    if (!mounted || selected == null) {
      return;
    }
    await _generateAiText(selected);
  }

  Future<void> _generateAiText(_AiToolAction action) async {
    if (_generatingAi) {
      return;
    }
    final originalText = _controller.text;
    final originalSelection = _controller.selection;
    setState(() {
      _generatingAi = true;
      _showAiThinkingHint = true;
    });
    try {
      final request = RiverMarkdownAiRequest(
        scene: widget.aiScene,
        instruction: action.instruction,
        currentMarkdown: _controller.text,
        referenceMarkdown: action.needsReference
            ? widget.aiReplyReferenceText
            : null,
      );
      final stream = widget.onAiGenerateStream != null
          ? widget.onAiGenerateStream!(request)
          : _fallbackStreamFromFuture(request);
      final anchor = _createAiInsertAnchor();
      final buffer = StringBuffer();
      var hasChunk = false;

      await for (final chunk in stream) {
        if (!mounted) {
          return;
        }
        final value = chunk;
        if (value.isEmpty) {
          continue;
        }
        if (!hasChunk && _showAiThinkingHint) {
          setState(() => _showAiThinkingHint = false);
        }
        hasChunk = true;
        buffer.write(value);
        _replaceAiInsertedContent(anchor, buffer.toString());
      }

      if (!mounted) {
        return;
      }
      if (!hasChunk || buffer.toString().trim().isEmpty) {
        _restoreEditorValue(originalText, originalSelection);
        _showSnack('AI 未返回有效内容', isError: true);
        return;
      }
      _showSnack('AI 生成完成');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _restoreEditorValue(originalText, originalSelection);
      _showSnack('AI 生成失败：$error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _generatingAi = false;
          _showAiThinkingHint = false;
        });
      }
    }
  }

  Stream<String> _fallbackStreamFromFuture(
    RiverMarkdownAiRequest request,
  ) async* {
    final callback = widget.onAiGenerate;
    if (callback == null) {
      return;
    }
    final generated = await callback(request);
    final text = (generated ?? '').trim();
    if (text.isEmpty) {
      return;
    }
    const int step = 8;
    for (var i = 0; i < text.length; i += step) {
      final end = (i + step > text.length) ? text.length : i + step;
      yield text.substring(i, end);
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
  }

  _AiInsertAnchor _createAiInsertAnchor() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(safeStart, text.length);
    final next = '${text.substring(0, safeStart)}${text.substring(safeEnd)}';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: safeStart),
    );
    _focusNode.requestFocus();
    return _AiInsertAnchor(start: safeStart, end: safeStart);
  }

  void _replaceAiInsertedContent(_AiInsertAnchor anchor, String content) {
    final text = _controller.text;
    final safeStart = anchor.start.clamp(0, text.length);
    final safeEnd = anchor.end.clamp(safeStart, text.length);
    final next =
        '${text.substring(0, safeStart)}$content${text.substring(safeEnd)}';
    anchor.end = safeStart + content.length;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: anchor.end),
    );
    _focusNode.requestFocus();
  }

  void _restoreEditorValue(String text, TextSelection selection) {
    final safeSelection = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
    _controller.value = TextEditingValue(text: text, selection: safeSelection);
    if (_mode == _EditorMode.edit) {
      _focusNode.requestFocus();
    }
  }

  void _applyFormat(String prefix, String suffix, String placeholder) {
    HapticFeedback.selectionClick();
    final text = _controller.text;
    final selection = _controller.selection;

    if (!selection.isValid) {
      final newText = '$text$prefix$placeholder$suffix';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - suffix.length,
        ),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);
    final content = selectedText.isEmpty ? placeholder : selectedText;

    final newText = text.replaceRange(start, end, '$prefix$content$suffix');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            start +
            prefix.length +
            content.length +
            (selectedText.isEmpty ? 0 : suffix.length),
      ),
    );
    _focusNode.requestFocus();
  }

  void _insertText(String content) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final newText = text.replaceRange(start, end, content);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + content.length),
    );
    _focusNode.requestFocus();
  }

  String _previewMarkdown(String raw) {
    if (raw.trim().isEmpty || widget.emojiUrls.isEmpty) {
      return raw;
    }
    final regex = RegExp(r':([a-zA-Z0-9_+\-.]+):');
    return raw.replaceAllMapped(regex, (match) {
      final key = (match.group(1) ?? '').trim();
      final emojiUrl = widget.emojiUrls[key];
      if (emojiUrl == null || emojiUrl.isEmpty) {
        return match.group(0) ?? '';
      }
      return '![:$key:]($emojiUrl)';
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _toggleSheetHeight([bool? expanded]) {
    final next = expanded ?? !_sheetExpanded;
    if (next == _sheetExpanded) {
      return;
    }
    setState(() => _sheetExpanded = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedCollapsedHeight = widget.maxHeight > 0
        ? widget.maxHeight
        : screenHeight * 0.58;
    final collapsedHeight = resolvedCollapsedHeight.clamp(
      340.0,
      screenHeight * 0.7,
    );
    final expandedHeight = (screenHeight * 0.92).clamp(420.0, screenHeight);
    final editorHeight = _sheetExpanded ? expandedHeight : collapsedHeight;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: editorHeight,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.surfaceContainerLow,
                      colorScheme.surface,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    children: [
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleSheetHeight,
                          onVerticalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity < -180) {
                              _toggleSheetHeight(true);
                            } else if (velocity > 180) {
                              if (_sheetExpanded) {
                                _toggleSheetHeight(false);
                              } else {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 16,
                            alignment: Alignment.center,
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.title ?? '发布内容',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (widget.enablePreview)
                            _EditorModeSwitch(
                              mode: _mode,
                              onChanged: (next) {
                                if (next == _mode) return;
                                setState(() => _mode = next);
                              },
                            ),
                          if (widget.enablePreview) const SizedBox(width: 6),
                          if (_draftEnabled)
                            IconButton(
                              tooltip: '保存草稿',
                              onPressed: _savingDraft
                                  ? null
                                  : () => _saveDraft(showSnack: true),
                              icon: _savingDraft
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                            ),
                          if (widget.onLoadDrafts != null)
                            IconButton(
                              tooltip: '草稿箱',
                              onPressed: _openDraftBox,
                              icon: const Icon(Icons.inventory_2_outlined),
                            ),
                          FilledButton.tonal(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            child: _submitting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : Text(widget.submitLabel ?? '发送'),
                          ),
                        ],
                      ),
                      if (_loadingDraft)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        )
                      else if (_lastDraftSavedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '草稿更新于 ${_lastDraftSavedAt!.hour.toString().padLeft(2, '0')}:${_lastDraftSavedAt!.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _mode == _EditorMode.edit
                      ? Stack(
                          key: const ValueKey<String>('editor_mode_edit'),
                          children: [
                            TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: widget.autofocus,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              maxLines: null,
                              minLines: null,
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.52,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.hintText ?? '分享你的想法...',
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.62),
                                ),
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  18,
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              opacity: _showAiThinkingHint ? 1 : 0,
                              child: IgnorePointer(
                                ignoring: true,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    10,
                                    18,
                                    0,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: _AiThinkingHintChip(
                                      visible: _showAiThinkingHint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          key: const ValueKey<String>('editor_mode_preview'),
                          color: colorScheme.surfaceContainerLowest,
                          child: _controller.text.trim().isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无预览内容',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Markdown(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    24,
                                  ),
                                  data: _previewMarkdown(_controller.text),
                                  selectable: true,
                                  physics: const ClampingScrollPhysics(),
                                  styleSheet:
                                      MarkdownStyleSheet.fromTheme(
                                        theme,
                                      ).copyWith(
                                        p: theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.6,
                                        ),
                                      ),
                                  sizedImageBuilder: (config) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: config.uri.toString(),
                                        fit: BoxFit.contain,
                                        placeholder: (context, imageUrl) =>
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 20,
                                              ),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, imageUrl, error) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _EditorToolbar(
                  uploadingImage: _uploadingImage,
                  generatingAi: _generatingAi,
                  enableAi:
                      widget.onAiGenerateStream != null ||
                      widget.onAiGenerate != null,
                  onImageTap: _pickAndUploadImage,
                  onEmojiTap: _showEmojiPicker,
                  onAiTap: _openAiTools,
                  onBoldTap: () => _applyFormat('**', '**', 'bold'),
                  onItalicTap: () => _applyFormat('*', '*', 'italic'),
                  onQuoteTap: () => _applyFormat('> ', '', 'quote'),
                  onCodeTap: () => _applyFormat('```\n', '\n```', 'code'),
                  onLinkTap: () => _applyFormat('[', '](url)', 'link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorModeSwitch extends StatelessWidget {
  const _EditorModeSwitch({required this.mode, required this.onChanged});

  final _EditorMode mode;
  final ValueChanged<_EditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 74,
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: mode == _EditorMode.edit
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: 34,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  tooltip: 'Markdown 编辑',
                  onPressed: () => onChanged(_EditorMode.edit),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.code_rounded,
                    color: mode == _EditorMode.edit
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: IconButton(
                  tooltip: '预览',
                  onPressed: () => onChanged(_EditorMode.preview),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.visibility_rounded,
                    color: mode == _EditorMode.preview
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.uploadingImage,
    required this.generatingAi,
    required this.enableAi,
    required this.onImageTap,
    required this.onEmojiTap,
    required this.onAiTap,
    required this.onBoldTap,
    required this.onItalicTap,
    required this.onQuoteTap,
    required this.onCodeTap,
    required this.onLinkTap,
  });

  final bool uploadingImage;
  final bool generatingAi;
  final bool enableAi;
  final VoidCallback onImageTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onAiTap;
  final VoidCallback onBoldTap;
  final VoidCallback onItalicTap;
  final VoidCallback onQuoteTap;
  final VoidCallback onCodeTap;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              _ToolbarAction(
                icon: Icons.image_outlined,
                busy: uploadingImage,
                onTap: onImageTap,
              ),
              const SizedBox(width: 6),
              _ToolbarAction(
                icon: Icons.sentiment_satisfied_alt_outlined,
                onTap: onEmojiTap,
              ),
              if (enableAi) ...[
                const SizedBox(width: 6),
                _ToolbarAiAction(
                  busy: generatingAi,
                  onTap: onAiTap,
                ),
              ],
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 24,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              _ToolbarAction(icon: Icons.format_bold_rounded, onTap: onBoldTap),
              _ToolbarAction(
                icon: Icons.format_italic_rounded,
                onTap: onItalicTap,
              ),
              _ToolbarAction(
                icon: Icons.format_quote_rounded,
                onTap: onQuoteTap,
              ),
              _ToolbarAction(icon: Icons.code_rounded, onTap: onCodeTap),
              _ToolbarAction(icon: Icons.link_rounded, onTap: onLinkTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarAiAction extends StatelessWidget {
  const _ToolbarAiAction({required this.onTap, this.busy = false});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: busy ? null : onTap,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
        foregroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : const _AiGlowLabel(),
    );
  }
}

class _AiGlowLabel extends StatelessWidget {
  const _AiGlowLabel();

  @override
  Widget build(BuildContext context) {
    return const _AiFlowingText(
      text: 'AI',
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      glow: true,
    );
  }
}

class _AiFlowingText extends StatefulWidget {
  const _AiFlowingText({
    required this.text,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = 0,
    this.glow = false,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool glow;

  @override
  State<_AiFlowingText> createState() => _AiFlowingTextState();
}

class _AiFlowingTextState extends State<_AiFlowingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            final shifted = Rect.fromLTWH(
              -width + 2 * width * t,
              0,
              width * 2,
              bounds.height <= 0 ? 1.0 : bounds.height,
            );
            return const LinearGradient(
              colors: <Color>[
                Color(0xFF67D2FF),
                Color(0xFF87A8FF),
                Color(0xFFFF95D2),
                Color(0xFF78E7D5),
                Color(0xFF67D2FF),
              ],
              stops: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(shifted);
          },
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              letterSpacing: widget.letterSpacing,
              shadows: widget.glow
                  ? const <Shadow>[
                      Shadow(color: Color(0x663AA8FF), blurRadius: 8),
                      Shadow(color: Color(0x55FF89CB), blurRadius: 10),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _AiThinkingHintChip extends StatelessWidget {
  const _AiThinkingHintChip({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: visible ? 1 : 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.auto_awesome_rounded, size: 14),
            SizedBox(width: 6),
            _AiFlowingText(
              text: 'AI思考中...',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              glow: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: busy ? null : onTap,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
        foregroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : Icon(icon),
    );
  }
}

class _AiToolAction {
  const _AiToolAction({
    required this.title,
    required this.subtitle,
    required this.instruction,
    required this.icon,
    this.needsReference = false,
  });

  final String title;
  final String subtitle;
  final String instruction;
  final IconData icon;
  final bool needsReference;
}

class _AiInsertAnchor {
  _AiInsertAnchor({required this.start, required this.end});

  final int start;
  int end;
}

class _AiToolsSheet extends StatelessWidget {
  const _AiToolsSheet({required this.actions});

  final List<_AiToolAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.52;
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  children: [
                    const SizedBox(width: 38),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.65,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI 工具箱',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: actions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = actions[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(item),
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow.withValues(
                            alpha: 0.96,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.36,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.82,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item.icon,
                                size: 17,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.1,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiCategoryItem {
  const _EmojiCategoryItem({
    required this.name,
    required this.keys,
    required this.coverKey,
  });

  final String name;
  final List<String> keys;
  final String coverKey;
}

class RiverStructuredEmojiPicker extends StatefulWidget {
  const RiverStructuredEmojiPicker({
    super.key,
    required this.emojiUrls,
    required this.emojiGroups,
    required this.onSelected,
    this.title = '选择表情',
  });

  final Map<String, String> emojiUrls;
  final Map<String, List<String>> emojiGroups;
  final ValueChanged<String> onSelected;
  final String title;

  @override
  State<RiverStructuredEmojiPicker> createState() =>
      _RiverStructuredEmojiPickerState();
}

class _RiverStructuredEmojiPickerState
    extends State<RiverStructuredEmojiPicker> {
  late final List<_EmojiCategoryItem> _categories;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _categories = _buildCategories();
  }

  List<_EmojiCategoryItem> _buildCategories() {
    final categories = <_EmojiCategoryItem>[];

    widget.emojiGroups.forEach((name, keys) {
      final valid = keys.where(widget.emojiUrls.containsKey).toList();
      if (valid.isEmpty) return;
      categories.add(
        _EmojiCategoryItem(name: name, keys: valid, coverKey: valid.first),
      );
    });

    if (categories.isEmpty && widget.emojiUrls.isNotEmpty) {
      final allKeys = widget.emojiUrls.keys.toList()..sort();
      categories.add(
        _EmojiCategoryItem(name: '全部', keys: allKeys, coverKey: allKeys.first),
      );
    }
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.52;

    if (_categories.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        alignment: Alignment.center,
        child: Text(
          '暂无表情',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final selected = _categories[_selectedIndex];
    final selectedKeys = selected.keys;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator();
              return true;
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 38),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: ListView.builder(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final item = _categories[index];
                                final selectedCategory =
                                    index == _selectedIndex;
                                final coverUrl =
                                    widget.emojiUrls[item.coverKey] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Tooltip(
                                    message: item.name,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        if (_selectedIndex == index) return;
                                        setState(() => _selectedIndex = index);
                                        HapticFeedback.selectionClick();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: selectedCategory
                                              ? colorScheme.primaryContainer
                                              : colorScheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: selectedCategory
                                                ? colorScheme.primary
                                                      .withValues(alpha: 0.28)
                                                : colorScheme.outlineVariant
                                                      .withValues(alpha: 0.22),
                                          ),
                                        ),
                                        child: Center(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: coverUrl,
                                              width: 28,
                                              height: 28,
                                              fit: BoxFit.contain,
                                              fadeInDuration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              placeholder:
                                                  (
                                                    context,
                                                    imageUrl,
                                                  ) => Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, imageUrl, error) =>
                                                      Icon(
                                                        Icons.tag_faces_rounded,
                                                        size: 20,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
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
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          Expanded(
                            child: ClipRect(
                              child: Material(
                                color: colorScheme.surface,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder:
                                      (currentChild, previousChildren) {
                                        return ClipRect(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            clipBehavior: Clip.hardEdge,
                                            children: <Widget>[
                                              ...previousChildren,
                                              currentChild ??
                                                  const SizedBox.shrink(),
                                            ],
                                          ),
                                        );
                                      },
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.03, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: GridView.builder(
                                    key: ValueKey<String>(selected.name),
                                    physics: const ClampingScrollPhysics(),
                                    clipBehavior: Clip.hardEdge,
                                    primary: false,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      14,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: 1,
                                        ),
                                    itemCount: selectedKeys.length,
                                    itemBuilder: (context, index) {
                                      final key = selectedKeys[index];
                                      final url = widget.emojiUrls[key] ?? '';
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => widget.onSelected(key),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerLow
                                                .withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.outlineVariant
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Center(
                                            child: CachedNetworkImage(
                                              imageUrl: url,
                                              width: 30,
                                              height: 30,
                                              fit: BoxFit.contain,
                                              fadeInDuration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              placeholder:
                                                  (
                                                    context,
                                                    imageUrl,
                                                  ) => Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            7,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    imageUrl,
                                                    error,
                                                  ) => Icon(
                                                    Icons.broken_image_rounded,
                                                    size: 16,
                                                    color: colorScheme.outline,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
