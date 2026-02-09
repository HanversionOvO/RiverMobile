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

class _ViewerZoomableImageState extends State<_ViewerZoomableImage>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapMinScale = 1;
  static const double _doubleTapMidScale = 2;
  static const double _doubleTapMaxScale = 4;
  static const double _miniMapShowScale = 2;

  bool _retryWithoutCookie = false;
  bool _fallbackToDirectImage = false;
  final TransformationController _transformController =
      TransformationController();
  AnimationController? _matrixAnimationController;
  TapDownDetails? _doubleTapDetails;
  Size _viewportSize = Size.zero;

  @override
  void dispose() {
    _matrixAnimationController?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCookie = (widget.item.headers?['Cookie'] ?? '').trim().isNotEmpty;
    final requestHeaders = _retryWithoutCookie
        ? _headersWithoutCookie(widget.item.headers)
        : widget.item.headers;

    final image = _fallbackToDirectImage
        ? _buildDirectImage(requestHeaders, hasCookie)
        : _buildCachedImage(requestHeaders, hasCookie);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        _viewportSize = Size(width, height);
        final imageChild = SizedBox(width: width, height: height, child: image);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            _doubleTapDetails = details;
          },
          onDoubleTap: _onDoubleTap,
          child: AnimatedBuilder(
            animation: _transformController,
            child: imageChild,
            builder: (context, child) {
              final scale = _currentScale;
              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1,
                      maxScale: 4,
                      child: child!,
                    ),
                  ),
                  if (scale >= _miniMapShowScale)
                    _MiniMapPanel(
                      imageUrl: widget.item.url,
                      headers: requestHeaders,
                      viewportSize: _viewportSize,
                      matrix: _transformController.value,
                      onPanUpdate: _onMiniMapPanUpdate,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  double get _currentScale {
    return _transformController.value.getMaxScaleOnAxis();
  }

  double get _currentTranslateX => _transformController.value.storage[12];

  double get _currentTranslateY => _transformController.value.storage[13];

  void _onDoubleTap() {
    if (_viewportSize.width <= 0 || _viewportSize.height <= 0) {
      return;
    }

    final currentScale = _currentScale;
    final targetScale = _nextScale(currentScale);
    final tapPosition =
        _doubleTapDetails?.localPosition ??
        Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentTx = _currentTranslateX;
    final currentTy = _currentTranslateY;

    final contentX = (tapPosition.dx - currentTx) / currentScale;
    final contentY = (tapPosition.dy - currentTy) / currentScale;
    final targetTx = tapPosition.dx - contentX * targetScale;
    final targetTy = tapPosition.dy - contentY * targetScale;
    final clamped = _clampTranslation(
      scale: targetScale,
      tx: targetTx,
      ty: targetTy,
    );

    _animateToMatrix(_composeMatrix(targetScale, clamped.dx, clamped.dy));
  }

  double _nextScale(double currentScale) {
    if (currentScale < _doubleTapMidScale - 0.01) {
      return _doubleTapMidScale;
    }
    if (currentScale < _doubleTapMaxScale - 0.01) {
      return _doubleTapMaxScale;
    }
    if (currentScale > _doubleTapMidScale + 0.01) {
      return _doubleTapMidScale;
    }
    return _doubleTapMinScale;
  }

  void _animateToMatrix(Matrix4 target) {
    _matrixAnimationController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    final animation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    animation.addListener(() {
      _transformController.value = animation.value;
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
        if (_matrixAnimationController == controller) {
          _matrixAnimationController = null;
        }
      }
    });
    _matrixAnimationController = controller;
    controller.forward();
  }

  void _onMiniMapPanUpdate(Offset delta, Size miniMapSize) {
    final scale = _currentScale;
    if (scale < _miniMapShowScale) {
      return;
    }
    final width = _viewportSize.width;
    final height = _viewportSize.height;
    if (width <= 0 ||
        height <= 0 ||
        miniMapSize.width <= 0 ||
        miniMapSize.height <= 0) {
      return;
    }

    final currentLeft = (-_currentTranslateX / scale).clamp(
      0,
      width - width / scale,
    );
    final currentTop = (-_currentTranslateY / scale).clamp(
      0,
      height - height / scale,
    );
    final deltaContentX = delta.dx / miniMapSize.width * width;
    final deltaContentY = delta.dy / miniMapSize.height * height;

    final nextLeft = (currentLeft + deltaContentX).clamp(
      0,
      width - width / scale,
    );
    final nextTop = (currentTop + deltaContentY).clamp(
      0,
      height - height / scale,
    );
    final targetTx = -nextLeft * scale;
    final targetTy = -nextTop * scale;
    final clamped = _clampTranslation(scale: scale, tx: targetTx, ty: targetTy);
    _transformController.value = _composeMatrix(scale, clamped.dx, clamped.dy);
  }

  Offset _clampTranslation({
    required double scale,
    required double tx,
    required double ty,
  }) {
    final width = _viewportSize.width;
    final height = _viewportSize.height;
    final minTx = width * (1 - scale);
    final minTy = height * (1 - scale);
    final clampedTx = tx.clamp(minTx, 0.0).toDouble();
    final clampedTy = ty.clamp(minTy, 0.0).toDouble();
    return Offset(clampedTx, clampedTy);
  }

  Matrix4 _composeMatrix(double scale, double tx, double ty) {
    final matrix = Matrix4.identity();
    matrix.storage[0] = scale;
    matrix.storage[5] = scale;
    matrix.storage[12] = tx;
    matrix.storage[13] = ty;
    return matrix;
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

class _MiniMapPanel extends StatelessWidget {
  const _MiniMapPanel({
    required this.imageUrl,
    required this.headers,
    required this.viewportSize,
    required this.matrix,
    required this.onPanUpdate,
  });

  final String imageUrl;
  final Map<String, String>? headers;
  final Size viewportSize;
  final Matrix4 matrix;
  final void Function(Offset delta, Size miniMapSize) onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];
    final width = viewportSize.width;
    final height = viewportSize.height;
    if (width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }
    final miniMapWidth = 88.0;
    final miniMapHeight = (miniMapWidth * (height / width))
        .clamp(96, 160)
        .toDouble();

    final visibleContentWidth = width / scale;
    final visibleContentHeight = height / scale;
    final contentLeft = (-tx / scale).clamp(0, width - visibleContentWidth);
    final contentTop = (-ty / scale).clamp(0, height - visibleContentHeight);

    final indicatorLeft = (contentLeft / width * miniMapWidth).toDouble();
    final indicatorTop = (contentTop / height * miniMapHeight).toDouble();
    final indicatorWidth = (visibleContentWidth / width * miniMapWidth)
        .clamp(18, miniMapWidth)
        .toDouble();
    final indicatorHeight = (visibleContentHeight / height * miniMapHeight)
        .clamp(18, miniMapHeight)
        .toDouble();

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (details) {
            onPanUpdate(details.delta, Size(miniMapWidth, miniMapHeight));
          },
          child: Container(
            width: miniMapWidth,
            height: miniMapHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white54),
              color: Colors.black54,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    httpHeaders: headers,
                    cacheKey: _buildImageCacheKey(imageUrl, headers),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: indicatorLeft,
                  top: indicatorTop,
                  child: Container(
                    width: indicatorWidth,
                    height: indicatorHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      color: Colors.white.withValues(alpha: 0.10),
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
