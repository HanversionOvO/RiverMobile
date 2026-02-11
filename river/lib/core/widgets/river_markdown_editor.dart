import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

typedef RiverMarkdownSubmitCallback = Future<bool> Function(String markdown);
typedef RiverMarkdownImageUploadCallback =
    Future<String?> Function(String fileName, List<int> bytes);

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

  @override
  State<RiverMarkdownEditor> createState() => _RiverMarkdownEditorState();
}

class _RiverMarkdownEditorState extends State<RiverMarkdownEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    if (widget.initialText.isNotEmpty) {
      _controller.selection = TextSelection.collapsed(
        offset: widget.initialText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
      backgroundColor: Colors.transparent,
      builder: (_) => _StructuredEmojiPicker(
        emojiUrls: widget.emojiUrls,
        emojiGroups: widget.emojiGroups,
        onSelected: (key) {
          _insertText(':$key:');
          Navigator.of(context).pop();
        },
      ),
    );
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedMaxHeight = widget.maxHeight > 0
        ? widget.maxHeight
        : screenHeight * 0.86;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: resolvedMaxHeight,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.title ?? '发布内容',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? '分享你的想法...',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow.withValues(
                      alpha: 0.95,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        _EditorToolbarButton(
                          icon: Icons.image_outlined,
                          isBusy: _uploadingImage,
                          onTap: _pickAndUploadImage,
                        ),
                        _EditorToolbarButton(
                          icon: Icons.sentiment_satisfied_alt_outlined,
                          onTap: _showEmojiPicker,
                        ),
                        _VerticalSeparator(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.format_bold_rounded,
                          onTap: () => _applyFormat('**', '**', 'bold'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.format_italic_rounded,
                          onTap: () => _applyFormat('*', '*', 'italic'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.format_quote_rounded,
                          onTap: () => _applyFormat('> ', '', 'quote'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.code_rounded,
                          onTap: () => _applyFormat('```\n', '\n```', 'code'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.link_rounded,
                          onTap: () => _applyFormat('[', '](url)', 'link'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorToolbarButton extends StatelessWidget {
  const _EditorToolbarButton({
    required this.icon,
    required this.onTap,
    this.isBusy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isBusy ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return IconButton(
      onPressed: isBusy ? null : onTap,
      visualDensity: VisualDensity.compact,
      icon: isBusy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, color: color),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        highlightColor: colorScheme.primary.withValues(alpha: 0.08),
      ),
    );
  }
}

class _VerticalSeparator extends StatelessWidget {
  const _VerticalSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: color);
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

class _StructuredEmojiPicker extends StatefulWidget {
  const _StructuredEmojiPicker({
    required this.emojiUrls,
    required this.emojiGroups,
    required this.onSelected,
  });

  final Map<String, String> emojiUrls;
  final Map<String, List<String>> emojiGroups;
  final ValueChanged<String> onSelected;

  @override
  State<_StructuredEmojiPicker> createState() => _StructuredEmojiPickerState();
}

class _StructuredEmojiPickerState extends State<_StructuredEmojiPicker> {
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
    final height = MediaQuery.sizeOf(context).height * 0.56;

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
                            '选择表情',
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
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final item = _categories[index];
                          final selectedCategory = index == _selectedIndex;
                          final coverUrl =
                              widget.emojiUrls[item.coverKey] ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
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
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: selectedCategory
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedCategory
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.28,
                                            )
                                          : colorScheme.outlineVariant
                                                .withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: coverUrl,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.contain,
                                        fadeInDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        placeholder: (context, imageUrl) =>
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, imageUrl, error) => Icon(
                                              Icons.tag_faces_rounded,
                                              size: 20,
                                              color:
                                                  colorScheme.onSurfaceVariant,
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
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
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
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
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
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.92, end: 1),
                              duration: Duration(
                                milliseconds: 120 + (index % 14) * 14,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.onSelected(key),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
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
                                      placeholder: (context, imageUrl) =>
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                          ),
                                      errorWidget: (context, imageUrl, error) =>
                                          Icon(
                                            Icons.broken_image_rounded,
                                            size: 16,
                                            color: colorScheme.outline,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
}
