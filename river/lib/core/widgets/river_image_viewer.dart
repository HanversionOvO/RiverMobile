import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RiverImageViewerItem {
  const RiverImageViewerItem({
    required this.url,
    this.headers,
    required this.heroTag,
  });

  final String url;
  final Map<String, String>? headers;
  final String heroTag;
}

class RiverImageViewerPage extends StatefulWidget {
  const RiverImageViewerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<RiverImageViewerItem> items;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<RiverImageViewerItem> items,
    int initialIndex = 0,
  }) async {
    if (items.isEmpty) {
      return;
    }
    final safeIndex = initialIndex.clamp(0, items.length - 1);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RiverImageViewerPage(items: items, initialIndex: safeIndex),
      ),
    );
  }

  @override
  State<RiverImageViewerPage> createState() => _RiverImageViewerPageState();
}

class _RiverImageViewerPageState extends State<RiverImageViewerPage> {
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
                      child: _ViewerZoomableImage(item: item),
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.itemCount, required this.currentIndex});

  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(itemCount, (index) {
              final active = index == currentIndex;
              return Container(
                width: active ? 14 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ViewerZoomableImage extends StatefulWidget {
  const _ViewerZoomableImage({required this.item});

  final RiverImageViewerItem item;

  @override
  State<_ViewerZoomableImage> createState() => _ViewerZoomableImageState();
}

class _ViewerZoomableImageState extends State<_ViewerZoomableImage> {
  bool _retryWithoutCookie = false;
  bool _fallbackToDirectImage = false;

  @override
  Widget build(BuildContext context) {
    final hasCookie = (widget.item.headers?['Cookie'] ?? '').trim().isNotEmpty;
    final requestHeaders = _retryWithoutCookie
        ? _headersWithoutCookie(widget.item.headers)
        : widget.item.headers;

    final image = _fallbackToDirectImage
        ? _buildDirectImage(requestHeaders, hasCookie)
        : _buildCachedImage(requestHeaders, hasCookie);
    return InteractiveViewer(minScale: 1, maxScale: 4, child: image);
  }

  Widget _buildCachedImage(Map<String, String>? headers, bool hasCookie) {
    return CachedNetworkImage(
      imageUrl: widget.item.url,
      httpHeaders: headers,
      cacheKey: _buildImageCacheKey(widget.item.url, headers),
      fit: BoxFit.contain,
      placeholder: (context, imageUrl) => _buildLoadingPlaceholder(),
      errorWidget: (context, imageUrl, error) {
        if (!_retryWithoutCookie && hasCookie) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _retryWithoutCookie = true;
            });
          });
          return _buildLoadingPlaceholder();
        }
        if (!_fallbackToDirectImage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _fallbackToDirectImage = true;
            });
          });
          return _buildLoadingPlaceholder();
        }
        return _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildDirectImage(Map<String, String>? headers, bool hasCookie) {
    return Image.network(
      widget.item.url,
      headers: headers,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return _buildLoadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_retryWithoutCookie && hasCookie) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _retryWithoutCookie = true;
              _fallbackToDirectImage = true;
            });
          });
          return _buildLoadingPlaceholder();
        }
        return _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildErrorPlaceholder() {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 36,
        ),
      ),
    );
  }
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
