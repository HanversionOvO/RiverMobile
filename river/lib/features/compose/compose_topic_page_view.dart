part of 'compose_topic_page.dart';

extension _ComposeTopicPageView on _ComposeTopicPageState {
  Widget _buildPage(BuildContext context) {
    final selectedCategory = _selectedCategory();
    final categoryText = selectedCategory == null
        ? '请选择板块'
        : _displayCategoryName(selectedCategory);
    final contentPreview = _contentMarkdown.trim();

    return RefreshIndicator(
      onRefresh: _loadMetaData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            decoration: const InputDecoration(
              labelText: '帖子标题',
              hintText: '请输入标题',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _loadingMeta ? null : _openCategoryPicker,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '发帖板块',
                border: const OutlineInputBorder(),
                suffixIcon: _loadingMeta
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.expand_more),
              ),
              child: Text(
                categoryText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '帖子内容',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contentPreview.isEmpty
                        ? '暂无内容，点击“编辑内容”开始输入'
                        : contentPreview,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑内容'),
                      ),
                      const SizedBox(width: 8),
                      if (contentPreview.isNotEmpty)
                        Text(
                          '${contentPreview.length} 字',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearDraftWithConfirm,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('清空草稿'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewTopic,
                  icon: const Icon(Icons.preview_outlined, size: 18),
                  label: const Text('预览'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _publishing ? null : _publishTopic,
                  icon: _publishing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_publishing ? '发布中...' : '发布帖子'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '说明：预览用于模拟帖子详情展示；发布成功后将自动跳转到真实帖子详情。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeCategoryPickerSheet extends StatelessWidget {
  const _ComposeCategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.categoryNameBuilder,
  });

  final List<RiverSideCategoryOption> categories;
  final int? selectedCategoryId;
  final String Function(RiverSideCategoryOption item) categoryNameBuilder;

  @override
  Widget build(BuildContext context) {
    final topLevel = categories
        .where((item) => item.parentCategoryId == null)
        .toList(growable: false);
    final byParent = <int, List<RiverSideCategoryOption>>{};
    for (final item in categories) {
      final parentId = item.parentCategoryId;
      if (parentId == null) {
        continue;
      }
      final list = byParent.putIfAbsent(
        parentId,
        () => <RiverSideCategoryOption>[],
      );
      list.add(item);
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            for (final parent in topLevel) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selectedCategoryId == parent.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(parent.name),
                subtitle: parent.description.isEmpty
                    ? null
                    : Text(
                        parent.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => Navigator.of(context).pop(parent.id),
              ),
              if ((byParent[parent.id] ?? const <RiverSideCategoryOption>[])
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final child in byParent[parent.id]!)
                        ChoiceChip(
                          selected: selectedCategoryId == child.id,
                          label: Text(child.name),
                          onSelected: (_) =>
                              Navigator.of(context).pop(child.id),
                        ),
                    ],
                  ),
                ),
              const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
