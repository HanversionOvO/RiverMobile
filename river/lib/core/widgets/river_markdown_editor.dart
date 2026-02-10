import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
  static const String _defaultHint =
      '\u8bf7\u8f93\u5165\u56de\u590d\u5185\u5bb9';
  static const String _defaultSubmit = '\u53d1\u9001';
  static const String _labelEmpty =
      '\u56de\u590d\u5185\u5bb9\u4e0d\u80fd\u4e3a\u7a7a';
  static const String _labelImagePickFailed =
      '\u9009\u62e9\u56fe\u7247\u5931\u8d25';
  static const String _labelImageUploadFailed =
      '\u56fe\u7247\u4e0a\u4f20\u5931\u8d25';
  static const String _labelImageUploadSuccess =
      '\u56fe\u7247\u5df2\u63d2\u5165';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showMessage(_labelEmpty);
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      final ok = await widget.onSubmit(text);
      if (!mounted) {
        return;
      }
      if (ok && widget.closeOnSubmitSuccess) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final callback = widget.onUploadImage;
    if (callback == null || _uploadingImage) {
      return;
    }

    XFile? pickedFile;
    try {
      pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      _showMessage(_labelImagePickFailed);
      return;
    }
    if (pickedFile == null) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });
    try {
      final bytes = await pickedFile.readAsBytes();
      final inserted = await callback(pickedFile.name, bytes);
      if (!mounted) {
        return;
      }
      if (inserted != null && inserted.trim().isNotEmpty) {
        _insertAtSelection('\n$inserted\n');
        _showMessage(_labelImageUploadSuccess);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(_labelImageUploadFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _showEmojiPicker() async {
    if (widget.emojiUrls.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final grouped = _buildEmojiGroupsForPicker();
        final categories = grouped.keys.toList(growable: false);
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }
        var currentCategory = categories.first;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final names = grouped[currentCategory] ?? const <String>[];
            final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
            return SafeArea(
              child: SizedBox(
                height: maxHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: 118,
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final selected = category == currentCategory;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            title: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              setSheetState(() {
                                currentCategory = category;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 0.95,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: names.length,
                        itemBuilder: (context, index) {
                          final name = names[index];
                          final url = widget.emojiUrls[name] ?? '';
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.of(sheetContext).pop(name),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: CachedNetworkImage(
                                imageUrl: url,
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                errorWidget: (context, imageUrl, error) => Text(
                                  ':$name:',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected.trim().isEmpty) {
      return;
    }
    _insertAtSelection(':$selected:');
  }

  Map<String, List<String>> _buildEmojiGroupsForPicker() {
    final grouped = <String, List<String>>{};
    final allNames = <String>[];
    final normalized = <String>{};
    for (final key in widget.emojiUrls.keys) {
      final raw = key.trim();
      final lower = raw.toLowerCase();
      if (raw.isEmpty || normalized.contains(lower)) {
        continue;
      }
      normalized.add(lower);
      allNames.add(raw);
    }
    allNames.sort((a, b) => a.compareTo(b));

    for (final entry in widget.emojiGroups.entries) {
      final category = entry.key.trim();
      if (category.isEmpty) {
        continue;
      }
      final names = <String>[];
      for (final raw in entry.value) {
        final name = raw.trim();
        if (name.isEmpty) {
          continue;
        }
        if (!widget.emojiUrls.containsKey(name)) {
          continue;
        }
        if (!names.contains(name)) {
          names.add(name);
        }
      }
      if (names.isEmpty) {
        continue;
      }
      names.sort((a, b) => a.compareTo(b));
      grouped[category] = names;
    }

    if (grouped.isEmpty) {
      grouped['\u5168\u90e8'] = allNames;
    } else {
      final ordered = <String, List<String>>{'\u5168\u90e8': allNames};
      ordered.addAll(grouped);
      return ordered;
    }
    return grouped;
  }

  void _applyWrap({
    required String prefix,
    required String suffix,
    String placeholder = '',
  }) {
    final text = _controller.text;
    final selection = _controller.selection;
    final safeStart = selection.start < 0 ? text.length : selection.start;
    final safeEnd = selection.end < 0 ? text.length : selection.end;
    final start = safeStart <= safeEnd ? safeStart : safeEnd;
    final end = safeStart <= safeEnd ? safeEnd : safeStart;
    final selected = text.substring(start, end);
    final content = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$content$suffix';

    final updated = text.replaceRange(start, end, replacement);
    _controller.value = _controller.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _insertAtSelection(String content) {
    final text = _controller.text;
    final selection = _controller.selection;
    final safeStart = selection.start < 0 ? text.length : selection.start;
    final safeEnd = selection.end < 0 ? text.length : selection.end;
    final start = safeStart <= safeEnd ? safeStart : safeEnd;
    final end = safeStart <= safeEnd ? safeEnd : safeStart;

    final updated = text.replaceRange(start, end, content);
    _controller.value = _controller.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + content.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedMaxHeight = widget.maxHeight > 0
        ? widget.maxHeight
        : screenHeight * 0.84;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: resolvedMaxHeight,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title ?? '',
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.submitLabel ?? _defaultSubmit),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    children: [
                      _ToolbarIconButton(
                        icon: Icons.format_bold,
                        tooltip: 'Bold',
                        onPressed: () => _applyWrap(
                          prefix: '**',
                          suffix: '**',
                          placeholder: 'bold',
                        ),
                      ),
                      _ToolbarIconButton(
                        icon: Icons.format_italic,
                        tooltip: 'Italic',
                        onPressed: () => _applyWrap(
                          prefix: '*',
                          suffix: '*',
                          placeholder: 'italic',
                        ),
                      ),
                      _ToolbarIconButton(
                        icon: Icons.format_quote,
                        tooltip: 'Quote',
                        onPressed: () => _applyWrap(
                          prefix: '> ',
                          suffix: '',
                          placeholder: 'quote',
                        ),
                      ),
                      _ToolbarIconButton(
                        icon: Icons.code,
                        tooltip: 'Code',
                        onPressed: () => _applyWrap(
                          prefix: '```\n',
                          suffix: '\n```',
                          placeholder: 'code',
                        ),
                      ),
                      _ToolbarIconButton(
                        icon: Icons.link,
                        tooltip: 'Link',
                        onPressed: () => _insertAtSelection('[text](https://)'),
                      ),
                      _ToolbarIconButton(
                        icon: Icons.sentiment_satisfied_alt_outlined,
                        tooltip: 'Emoji',
                        onPressed: _showEmojiPicker,
                      ),
                      _ToolbarIconButton(
                        icon: Icons.image_outlined,
                        tooltip: 'Image',
                        loading: _uploadingImage,
                        onPressed: _pickAndUploadImage,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: widget.hintText ?? _defaultHint,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                        isDense: true,
                        filled: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );
  }
}
