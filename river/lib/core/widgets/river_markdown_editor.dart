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

    // 隐藏键盘，体验更好
    FocusScope.of(context).unfocus();

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploadingImage = true);

      final callback = widget.onUploadImage;
      if (callback != null) {
        final bytes = await picked.readAsBytes();
        final inserted = await callback(picked.name, bytes);
        if (mounted && inserted != null && inserted.isNotEmpty) {
          _insertText('\n$inserted\n');
          _showSnack('图片已添加');
        } else if (mounted) {
          _showSnack('图片上传失败', isError: true);
        }
      }
    } catch (_) {
      if (mounted) _showSnack('选择图片出错', isError: true);
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
        // 恢复焦点
        _focusNode.requestFocus();
      }
    }
  }

  void _showEmojiPicker() {
    // 收起键盘
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StructuredEmojiPicker(
        emojiUrls: widget.emojiUrls,
        emojiGroups: widget.emojiGroups,
        onSelected: (key) {
          _insertText(':$key:');
          Navigator.pop(context);
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
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // 计算合适的高度
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedMaxHeight = widget.maxHeight > 0
        ? widget.maxHeight
        : screenHeight * 0.85;

    return Container(
      height: resolvedMaxHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 1. 顶部 Header (简洁风格)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? '发布内容',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // 发送按钮 (使用 TextButton 或 FilledButton，跟随主题)
                TextButton(
                  onPressed: _submitting ? null : _submit,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                        )
                      : Text(widget.submitLabel ?? '发送'),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // 2. 编辑区域
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
                hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),

          // 3. 底部工具栏
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow, // 浅色背景区分
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ToolbarBtn(
                    icon: Icons.image_outlined,
                    isActive: _uploadingImage,
                    onTap: _pickAndUploadImage,
                  ),
                  _ToolbarBtn(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    onTap: _showEmojiPicker,
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                  _ToolbarBtn(
                    icon: Icons.format_bold_rounded,
                    onTap: () => _applyFormat('**', '**', 'bold'),
                  ),
                  _ToolbarBtn(
                    icon: Icons.format_italic_rounded,
                    onTap: () => _applyFormat('*', '*', 'italic'),
                  ),
                  _ToolbarBtn(
                    icon: Icons.format_quote_rounded,
                    onTap: () => _applyFormat('> ', '', 'quote'),
                  ),
                  _ToolbarBtn(
                    icon: Icons.code_rounded,
                    onTap: () => _applyFormat('```\n', '\n```', 'code'),
                  ),
                  _ToolbarBtn(
                    icon: Icons.link_rounded,
                    onTap: () => _applyFormat('[', '](url)', 'link'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return IconButton(
      onPressed: isActive ? null : onTap,
      icon: isActive
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, color: color),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        highlightColor: colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}

// ===========================================================================
// 重构后的表情选择面板：多级选择逻辑 (左侧导航 + 右侧内容)
// ===========================================================================

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
  // 分类列表
  late List<String> _categories;
  // 缓存每个分类下的表情 key
  late Map<String, List<String>> _categoryData;
  // 当前选中的分类索引
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    _categoryData = {};
    _categories = [];

    // 1. 处理传入的分组
    widget.emojiGroups.forEach((category, keys) {
      final validKeys = keys
          .where((k) => widget.emojiUrls.containsKey(k))
          .toList();
      if (validKeys.isNotEmpty) {
        _categories.add(category);
        _categoryData[category] = validKeys;
      }
    });

    // 2. 如果没有分组，或者想加一个"全部"
    // 这里如果没有数据，加一个默认的
    if (_categories.isEmpty && widget.emojiUrls.isNotEmpty) {
      const defaultCat = '全部';
      _categories.add(defaultCat);
      _categoryData[defaultCat] = widget.emojiUrls.keys.toList()..sort();
    } else if (_categories.isNotEmpty) {
      // 可选：是否添加“全部”在第一个？
      // 如果需要，解除下面注释
      /*
       final allKeys = widget.emojiUrls.keys.toList()..sort();
       _categories.insert(0, '全部');
       _categoryData['全部'] = allKeys;
       */
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.45;

    if (_categories.isEmpty) {
      return Container(
        height: 200,
        color: colorScheme.surface,
        alignment: Alignment.center,
        child: Text('暂无表情', style: TextStyle(color: theme.hintColor)),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部小把手
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // 左侧：分类导航 (NavigationRail 风格)
                Container(
                  width: 86,
                  color: colorScheme.surfaceContainerLow.withOpacity(0.5),
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = index == _selectedIndex;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.secondaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 右侧：表情网格
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
                    child: _buildEmojiGrid(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(ThemeData theme) {
    final currentCategory = _categories[_selectedIndex];
    final keys = _categoryData[currentCategory] ?? [];

    // 使用 Key 强制刷新 GridView 滚动位置
    return GridView.builder(
      key: ValueKey(currentCategory),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final url = widget.emojiUrls[key];

        return InkWell(
          onTap: () => widget.onSelected(key),
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url ?? '',
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.broken_image_rounded,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ),
        );
      },
    );
  }
}
