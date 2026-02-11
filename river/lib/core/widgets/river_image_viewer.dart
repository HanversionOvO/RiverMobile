import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/navigation/river_page_route.dart';

part 'river_image_viewer_components.dart';

class RiverImageViewerItem {
  const RiverImageViewerItem({
    required this.url,
    this.headers,
    required this.heroTag,
    this.imageProvider,
  });

  final String url;
  final Map<String, String>? headers;
  final String heroTag;
  final ImageProvider<Object>? imageProvider;
}

typedef RiverImageViewerActionHandler =
    Future<void> Function(BuildContext context, RiverImageViewerItem item);

class RiverImageViewerAction {
  const RiverImageViewerAction({
    required this.id,
    required this.label,
    this.icon,
    required this.onSelected,
  });

  final String id;
  final String label;
  final IconData? icon;
  final RiverImageViewerActionHandler onSelected;
}

class RiverImageViewerPage extends StatefulWidget {
  const RiverImageViewerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.extraActions = const <RiverImageViewerAction>[],
  });

  final List<RiverImageViewerItem> items;
  final int initialIndex;
  final List<RiverImageViewerAction> extraActions;

  static Future<void> open(
    BuildContext context, {
    required List<RiverImageViewerItem> items,
    int initialIndex = 0,
    List<RiverImageViewerAction> extraActions =
        const <RiverImageViewerAction>[],
  }) async {
    if (items.isEmpty) {
      return;
    }
    final safeIndex = initialIndex.clamp(0, items.length - 1);
    await Navigator.of(context).push(
      riverPageRoute<void>(
        enableFullScreenSwipeBack: false,
        builder: (_) => RiverImageViewerPage(
          items: items,
          initialIndex: safeIndex,
          extraActions: extraActions,
        ),
      ),
    );
  }

  @override
  State<RiverImageViewerPage> createState() => _RiverImageViewerPageState();
}

class _RiverImageViewerPageState extends State<RiverImageViewerPage> {
  static const String _actionSaveOriginal = 'save_original';

  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  Future<void> _showImageActions(RiverImageViewerItem item) async {
    final actions = <RiverImageViewerAction>[
      RiverImageViewerAction(
        id: _actionSaveOriginal,
        label: '\u4fdd\u5b58\u539f\u56fe',
        icon: Icons.download_outlined,
        onSelected: (context, selected) => _saveOriginalImage(selected),
      ),
      ...widget.extraActions,
    ];
    if (actions.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<RiverImageViewerAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: actions.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == actions.length) {
                return ListTile(
                  title: const Text('\u53d6\u6d88'),
                  onTap: () => Navigator.of(sheetContext).pop(),
                );
              }
              final action = actions[index];
              return ListTile(
                leading: action.icon == null ? null : Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(sheetContext).pop(action),
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    try {
      await selected.onSelected(context, item);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is StateError
          ? error.message.toString()
          : '\u64cd\u4f5c\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveOriginalImage(RiverImageViewerItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) {
      throw StateError('\u56fe\u7247\u5730\u5740\u65e0\u6548');
    }
    final granted = await _ensureStoragePermission();
    if (!mounted) {
      return;
    }
    if (!granted) {
      throw StateError(
        '\u672a\u83b7\u5f97\u76f8\u518c\u6743\u9650\uff0c\u65e0\u6cd5\u4fdd\u5b58\u56fe\u7247',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u6b63\u5728\u4fdd\u5b58\u539f\u56fe...')),
    );
    final bytes = await _downloadImageBytes(uri, item.headers);
    final name = _guessImageFileName(uri);
    final result = await ImageGallerySaverPlus.saveImage(
      Uint8List.fromList(bytes),
      quality: 100,
      name: name,
    );
    final outcome = _parseSaveResult(result);
    if (!outcome.success) {
      throw StateError(
        outcome.message ?? '\u7cfb\u7edf\u76f8\u518c\u4fdd\u5b58\u5931\u8d25',
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u539f\u56fe\u5df2\u4fdd\u5b58\u5230\u7cfb\u7edf\u76f8\u518c',
        ),
      ),
    );
  }

  Future<bool> _ensureStoragePermission() async {
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    // Android 10+ can write MediaStore without storage runtime permission.
    // Keep this non-blocking and let the plugin return a concrete failure reason.
    return true;
  }

  String _guessImageFileName(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final sanitized = last.split('?').first.trim();
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    return 'river_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  Future<List<int>> _downloadImageBytes(
    Uri uri,
    Map<String, String>? sourceHeaders,
  ) async {
    final candidates = _buildDownloadHeaderCandidates(uri, sourceHeaders);
    final statuses = <int>[];
    for (final headers in candidates) {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      statuses.add(response.statusCode);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    }
    final joined = statuses.isEmpty ? 'unknown' : statuses.join('/');
    throw StateError(
      '\u56fe\u7247\u4e0b\u8f7d\u5931\u8d25\uff08HTTP $joined\uff09',
    );
  }

  List<Map<String, String>?> _buildDownloadHeaderCandidates(
    Uri uri,
    Map<String, String>? sourceHeaders,
  ) {
    final candidates = <Map<String, String>?>[];
    void add(Map<String, String>? headers) {
      final normalized = _normalizeHeaders(headers);
      final key = normalized == null
          ? '<none>'
          : normalized.entries.map((e) => '${e.key}=${e.value}').join('&');
      final exists = candidates.any((item) {
        final current = _normalizeHeaders(item);
        final currentKey = current == null
            ? '<none>'
            : current.entries.map((e) => '${e.key}=${e.value}').join('&');
        return currentKey == key;
      });
      if (!exists) {
        candidates.add(normalized);
      }
    }

    final stripped = _headersWithoutCookie(sourceHeaders);
    final browserHeaders = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Referer': '${uri.scheme}://${uri.host}/',
    };
    add(sourceHeaders);
    add(stripped);
    add({...?stripped, ...browserHeaders});
    add(browserHeaders);
    return candidates;
  }

  Map<String, String>? _normalizeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return null;
    }
    final normalized = <String, String>{};
    headers.forEach((key, value) {
      final k = key.trim();
      final v = value.trim();
      if (k.isEmpty || v.isEmpty) {
        return;
      }
      normalized[k] = v;
    });
    return normalized.isEmpty ? null : normalized;
  }

  ({bool success, String? message}) _parseSaveResult(dynamic result) {
    if (result is bool) {
      return (
        success: result,
        message: result
            ? null
            : '\u7cfb\u7edf\u76f8\u518c\u4fdd\u5b58\u5931\u8d25',
      );
    }
    if (result is Map) {
      final map = <String, dynamic>{};
      result.forEach((key, value) {
        map['$key'] = value;
      });
      final isSuccess =
          map['isSuccess'] == true ||
          map['success'] == true ||
          (map['filePath']?.toString().trim().isNotEmpty ?? false);
      if (isSuccess) {
        return (success: true, message: null);
      }
      final errorMessage = (map['errorMessage'] ?? map['error'] ?? '')
          .toString()
          .trim();
      return (
        success: false,
        message: errorMessage.isEmpty
            ? '\u7cfb\u7edf\u76f8\u518c\u4fdd\u5b58\u5931\u8d25'
            : errorMessage,
      );
    }
    return (
      success: false,
      message: '\u7cfb\u7edf\u76f8\u518c\u4fdd\u5b58\u5931\u8d25',
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final current = _currentIndex + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleOverlay,
              behavior: HitTestBehavior.opaque,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Center(
                    child: Hero(
                      tag: item.heroTag,
                      child: _ViewerZoomableImage(
                        item: item,
                        onLongPress: () => _showImageActions(item),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showOverlay ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          '$current / $count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showOverlay ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: _PageIndicator(
                  itemCount: widget.items.length,
                  currentIndex: _currentIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isRiverSideImageUrl(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').trim().toLowerCase();
  if (host.isEmpty) {
    return false;
  }
  final forumHost = Uri.parse(riverSideBaseUrl).host.toLowerCase();
  return host == forumHost || host.endsWith('.$forumHost');
}

Map<String, String>? _headersWithoutCookie(Map<String, String>? source) {
  if (source == null || source.isEmpty) {
    return source;
  }
  final next = <String, String>{};
  source.forEach((key, value) {
    if (key.toLowerCase() == 'cookie') {
      return;
    }
    next[key] = value;
  });
  return next;
}

String _buildImageCacheKey(String url, Map<String, String>? headers) {
  final cookie = (headers?['Cookie'] ?? '').trim();
  if (cookie.isEmpty) {
    return url;
  }
  return '$url#auth';
}
