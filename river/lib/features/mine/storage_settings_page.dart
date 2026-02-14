import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:river/core/mini_apps/river_mini_app_install_store.dart';
import 'package:river/core/storage/app_cache_service.dart';
import 'package:river/features/mine/widgets/mine_settings_app_bar.dart';

part 'storage_settings_widgets.dart';

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  bool _loading = true;
  final Set<String> _busyIds = <String>{};
  CacheOverview _overview = const CacheOverview(totalBytes: 0, categories: []);
  final RiverMiniAppInstallStore _miniAppInstallStore =
      RiverMiniAppInstallStore();
  RiverMiniAppStorageOverview _miniAppOverview =
      const RiverMiniAppStorageOverview(
        totalBytes: 0,
        appCount: 0,
        items: <RiverMiniAppStorageItem>[],
      );

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  bool _isBusy(String key) => _busyIds.contains(key);

  Future<void> _runBusy(String key, Future<void> Function() task) async {
    if (_busyIds.contains(key)) {
      return;
    }
    setState(() => _busyIds.add(key));
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(key));
      }
    }
  }

  Future<void> _refreshAll({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _loading = true);
    }
    final result = await Future.wait<dynamic>([
      AppCacheService.loadCacheOverview(),
      _miniAppInstallStore.loadStorageOverview(),
    ]);
    final overview = result[0] as CacheOverview;
    final miniAppOverview = result[1] as RiverMiniAppStorageOverview;
    if (!mounted) {
      return;
    }
    setState(() {
      _overview = overview;
      _miniAppOverview = miniAppOverview;
      _loading = false;
    });
  }

  CacheCategoryInfo? _findCategory(String id) {
    for (final item in _overview.categories) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleClearAllCache() async {
    final confirmed = await _confirmClearDialog(
      title: '清除全部缓存',
      message:
          '将清除全部缓存数据（约 ${_formatBytes(_overview.totalBytes)}），不会影响登录状态，确认继续吗？',
    );
    if (confirmed != true) {
      return;
    }

    await _runBusy('tool_clear_all', () async {
      await AppCacheService.clearCache();
      await _refreshAll(showLoading: false);
      if (!mounted) {
        return;
      }
      _showDone('已完成全部缓存清理');
    });
  }

  Future<void> _handleClearCategory(CacheCategoryInfo category) async {
    final confirmed = await _confirmClearDialog(
      title: '清理${category.title}',
      message:
          '将清理“${category.title}”（约 ${_formatBytes(category.bytes)}），确定继续吗？',
    );
    if (confirmed != true) {
      return;
    }

    await _runBusy('category_${category.id}', () async {
      await AppCacheService.clearCategory(category.id);
      await _refreshAll(showLoading: false);
      if (!mounted) {
        return;
      }
      _showDone('已清理${category.title}');
    });
  }

  Future<void> _handleClearSmart(_SmartCategory category) async {
    if (category.categoryIds.isEmpty) {
      return;
    }
    final confirmed = await _confirmClearDialog(
      title: '清理${category.title}',
      message:
          '将清理“${category.title}”中的相关缓存（约 ${_formatBytes(category.bytes)}），确认继续吗？',
    );
    if (confirmed != true) {
      return;
    }

    await _runBusy('smart_${category.id}', () async {
      for (final id in category.categoryIds) {
        await AppCacheService.clearCategory(id);
      }
      await _refreshAll(showLoading: false);
      if (!mounted) {
        return;
      }
      _showDone('已清理${category.title}');
    });
  }

  Future<void> _handleClearMiniApps() async {
    if (_miniAppOverview.appCount <= 0) {
      _showDone('暂无小程序可清理');
      return;
    }
    final confirmed = await _confirmClearDialog(
      title: '清理全部小程序',
      message:
          '将删除已安装的 ${_miniAppOverview.appCount} 个小程序及本地资源（约 ${_formatBytes(_miniAppOverview.totalBytes)}），确认继续吗？',
    );
    if (confirmed != true) {
      return;
    }

    await _runBusy('miniapp_clear_all', () async {
      await _miniAppInstallStore.clearAllInstalled();
      await _refreshAll(showLoading: false);
      if (!mounted) {
        return;
      }
      _showDone('已清理小程序数据');
    });
  }

  Future<void> _handleRemoveMiniApp(RiverMiniAppStorageItem item) async {
    final confirmed = await _confirmClearDialog(
      title: '删除小程序',
      message: '确定删除“${item.appName}”及其本地资源吗？',
    );
    if (confirmed != true) {
      return;
    }
    await _runBusy('miniapp_${item.appId}', () async {
      await _miniAppInstallStore.removeInstalledById(item.appId);
      await _refreshAll(showLoading: false);
      if (!mounted) {
        return;
      }
      _showDone('已删除${item.appName}');
    });
  }

  Future<void> _showCategoryEntries(CacheCategoryInfo category) async {
    if (category.path.startsWith('memory://')) {
      _showDone('内存缓存无文件明细，可直接清理');
      return;
    }

    final entries = await AppCacheService.listTopEntries(
      categoryPath: category.path,
    );
    if (!mounted) {
      return;
    }
    final accent = _categoryColor(category.id, context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryEntriesSheet(
        category: category,
        entries: entries,
        accent: accent,
        icon: _categoryIcon(category.id),
        formatBytes: _formatBytes,
        formatDateTime: _formatDateTime,
      ),
    );
  }

  Future<void> _showLargestEntries() async {
    final categories = _overview.categories
        .where((item) => !item.path.startsWith('memory://'))
        .toList();
    final all = <_MergedEntry>[];

    for (final category in categories) {
      final list = await AppCacheService.listTopEntries(
        categoryPath: category.path,
        limit: 12,
      );
      for (final item in list) {
        all.add(_MergedEntry(category: category.title, entry: item));
      }
    }

    all.sort((a, b) => b.entry.bytes.compareTo(a.entry.bytes));
    final top = all.take(40).toList();

    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _LargestEntriesSheet(entries: top, formatBytes: _formatBytes),
    );
  }

  Future<bool?> _confirmClearDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDone(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  IconData _categoryIcon(String id) {
    switch (id) {
      case AppCacheService.imageDiskCacheCategoryId:
        return Icons.image_outlined;
      case AppCacheService.imageMemoryCacheCategoryId:
        return Icons.memory_rounded;
      case AppCacheService.tempCacheCategoryId:
        return Icons.thermostat_outlined;
      case AppCacheService.appCacheCategoryId:
        return Icons.storage_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _categoryColor(String id, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (id) {
      case AppCacheService.imageDiskCacheCategoryId:
        return scheme.primary;
      case AppCacheService.imageMemoryCacheCategoryId:
        return scheme.secondary;
      case AppCacheService.tempCacheCategoryId:
        return scheme.tertiary;
      case AppCacheService.appCacheCategoryId:
        return scheme.outline;
      default:
        return scheme.primary;
    }
  }

  List<_SmartCategory> _buildSmartCategories(BuildContext context) {
    final imageDisk =
        _findCategory(AppCacheService.imageDiskCacheCategoryId)?.bytes ?? 0;
    final imageMemory =
        _findCategory(AppCacheService.imageMemoryCacheCategoryId)?.bytes ?? 0;
    final temp = _findCategory(AppCacheService.tempCacheCategoryId)?.bytes ?? 0;
    final app = _findCategory(AppCacheService.appCacheCategoryId)?.bytes ?? 0;

    return [
      _SmartCategory(
        id: 'quick_clear',
        title: '快速可清理',
        subtitle: '图片磁盘 + 临时',
        bytes: imageDisk + temp,
        icon: Icons.auto_fix_high_rounded,
        color: _categoryColor(
          AppCacheService.imageDiskCacheCategoryId,
          context,
        ),
        categoryIds: const [
          AppCacheService.imageDiskCacheCategoryId,
          AppCacheService.tempCacheCategoryId,
        ],
      ),
      _SmartCategory(
        id: 'image_total',
        title: '图片相关',
        subtitle: '磁盘 + 内存',
        bytes: imageDisk + imageMemory,
        icon: Icons.photo_library_outlined,
        color: _categoryColor(
          AppCacheService.imageMemoryCacheCategoryId,
          context,
        ),
        categoryIds: const [
          AppCacheService.imageDiskCacheCategoryId,
          AppCacheService.imageMemoryCacheCategoryId,
        ],
      ),
      _SmartCategory(
        id: 'runtime_only',
        title: '运行时缓存',
        subtitle: '当前会话',
        bytes: imageMemory,
        icon: Icons.bolt_rounded,
        color: _categoryColor(AppCacheService.tempCacheCategoryId, context),
        categoryIds: const [AppCacheService.imageMemoryCacheCategoryId],
      ),
      _SmartCategory(
        id: 'persistent_only',
        title: '持久缓存',
        subtitle: '应用侧持久内容',
        bytes: app,
        icon: Icons.folder_special_outlined,
        color: _categoryColor(AppCacheService.appCacheCategoryId, context),
        categoryIds: const [AppCacheService.appCacheCategoryId],
      ),
    ];
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd $hh:$min';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 2)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _overview.categories;
    final smartCategories = _buildSmartCategories(context);
    final quickClear = smartCategories.firstWhere(
      (it) => it.id == 'quick_clear',
    );

    return Scaffold(
      appBar: const MineSettingsAppBar(
        title: '存储空间',
        subtitle: '应用缓存空间管理与清理',
        icon: Icons.sd_storage_rounded,
        heroTagPrefix: 'mine_settings_storage',
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _SettingsSection(
              title: '缓存总览',
              subtitle: '分类占用与动态统计',
              child: _StorageSummaryCard(
                loading: _loading,
                totalBytesText: _formatBytes(_overview.totalBytes),
                categories: categories,
                categoryColor: (id) => _categoryColor(id, context),
                formatBytes: _formatBytes,
                onRefresh: _loading ? null : _refreshAll,
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: '分类管理',
              subtitle: '按类别查看、清理与智能分组',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < categories.length; i++) ...[
                        _CategoryTile(
                          category: categories[i],
                          bytesText: _formatBytes(categories[i].bytes),
                          icon: _categoryIcon(categories[i].id),
                          color: _categoryColor(categories[i].id, context),
                          totalBytes: _overview.totalBytes,
                          busy: _isBusy('category_${categories[i].id}'),
                          onTap: () => _showCategoryEntries(categories[i]),
                          onClear: _loading
                              ? null
                              : () => _handleClearCategory(categories[i]),
                        ),
                        if (i != categories.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '智能分组',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: smartCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = smartCategories[index];
                        return _SmartCategoryCard(
                          item: item,
                          bytesText: _formatBytes(item.bytes),
                          busy: _isBusy('smart_${item.id}'),
                          onClear: _loading
                              ? null
                              : () => _handleClearSmart(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: '小程序管理',
              subtitle: '已安装小程序与本地资源',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.16,
                          ),
                          child: Icon(
                            Icons.widgets_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '已安装 ${_miniAppOverview.appCount} 个',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '占用 ${_formatBytes(_miniAppOverview.totalBytes)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _loading ? null : _handleClearMiniApps,
                          icon: _isBusy('miniapp_clear_all')
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_sweep_outlined,
                                  size: 16,
                                ),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_miniAppOverview.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        '暂无已安装小程序',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _miniAppOverview.items
                          .map((item) {
                            final installedAt = item.installedAtMillis <= 0
                                ? '未知时间'
                                : _formatDateTime(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      item.installedAtMillis,
                                    ),
                                  );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    12,
                                    6,
                                    8,
                                    6,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.widgets_outlined,
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    item.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '安装于 $installedAt',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatBytes(item.bytes),
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                      IconButton(
                                        tooltip: '删除',
                                        onPressed:
                                            _isBusy('miniapp_${item.appId}')
                                            ? null
                                            : () => _handleRemoveMiniApp(item),
                                        icon: _isBusy('miniapp_${item.appId}')
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: '管理工具',
              subtitle: '多维清理与分析工具',
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _ToolCard(
                    icon: Icons.delete_sweep_outlined,
                    color: theme.colorScheme.error,
                    title: '一键清理',
                    subtitle: _formatBytes(_overview.totalBytes),
                    busy: _isBusy('tool_clear_all'),
                    onTap: _loading ? null : _handleClearAllCache,
                  ),
                  _ToolCard(
                    icon: Icons.auto_fix_high_rounded,
                    color: theme.colorScheme.primary,
                    title: '快速清理',
                    subtitle: '图片磁盘 + 临时',
                    busy: _isBusy('smart_quick_clear'),
                    onTap: _loading
                        ? null
                        : () => _handleClearSmart(quickClear),
                  ),
                  _ToolCard(
                    icon: Icons.leaderboard_rounded,
                    color: theme.colorScheme.primary,
                    title: '大文件排行',
                    subtitle: '查看占用详情',
                    onTap: _showLargestEntries,
                  ),
                  _ToolCard(
                    icon: Icons.refresh_rounded,
                    color: theme.colorScheme.tertiary,
                    title: '刷新统计',
                    subtitle: '实时重算缓存',
                    onTap: _refreshAll,
                  ),
                  _ToolCard(
                    icon: Icons.memory_rounded,
                    color: _categoryColor(
                      AppCacheService.imageMemoryCacheCategoryId,
                      context,
                    ),
                    title: '释放图片内存',
                    subtitle: _formatBytes(
                      _findCategory(
                            AppCacheService.imageMemoryCacheCategoryId,
                          )?.bytes ??
                          0,
                    ),
                    busy: _isBusy(
                      'category_${AppCacheService.imageMemoryCacheCategoryId}',
                    ),
                    onTap: () {
                      final category = _findCategory(
                        AppCacheService.imageMemoryCacheCategoryId,
                      );
                      if (category != null) {
                        _handleClearCategory(category);
                      }
                    },
                  ),
                  _ToolCard(
                    icon: Icons.storage_outlined,
                    color: _categoryColor(
                      AppCacheService.appCacheCategoryId,
                      context,
                    ),
                    title: '应用缓存清理',
                    subtitle: _formatBytes(
                      _findCategory(
                            AppCacheService.appCacheCategoryId,
                          )?.bytes ??
                          0,
                    ),
                    busy: _isBusy(
                      'category_${AppCacheService.appCacheCategoryId}',
                    ),
                    onTap: () {
                      final category = _findCategory(
                        AppCacheService.appCacheCategoryId,
                      );
                      if (category != null) {
                        _handleClearCategory(category);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
