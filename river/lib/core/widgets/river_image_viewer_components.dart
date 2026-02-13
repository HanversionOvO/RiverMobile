part of 'river_image_viewer.dart';

class _ViewerActionTile extends StatelessWidget {
  const _ViewerActionTile({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: [
              if (icon != null)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              else
                const SizedBox(width: 30, height: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
  const _ViewerZoomableImage({required this.item, required this.onLongPress});

  final RiverImageViewerItem item;
  final VoidCallback onLongPress;

  @override
  State<_ViewerZoomableImage> createState() => _ViewerZoomableImageState();
}

class _ViewerZoomableImageState extends State<_ViewerZoomableImage>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapMinScale = 1;
  static const double _doubleTapMidScale = 2;
  static const double _doubleTapMaxScale = 4;
  static const double _miniMapShowScale = 2;
  static const List<double> _doubleTapScaleSequence = <double>[
    _doubleTapMidScale,
    _doubleTapMaxScale,
    _doubleTapMidScale,
    _doubleTapMinScale,
  ];

  bool _retryWithoutCookie = false;
  bool _fallbackToDirectImage = false;
  bool _useProvidedImage = true;
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _matrixAnimationController;
  Animation<Matrix4>? _matrixAnimation;
  TapDownDetails? _doubleTapDetails;
  Size _viewportSize = Size.zero;
  Size? _imagePixelSize;
  Object? _imageProviderIdentity;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  int _doubleTapCycleIndex = 0;
  bool _showMiniMapOverlay = true;
  Timer? _miniMapFadeTimer;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onMatrixChanged);
    _matrixAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final animation = _matrixAnimation;
          if (animation != null) {
            _transformController.value = animation.value;
          }
        });
  }

  @override
  void dispose() {
    _miniMapFadeTimer?.cancel();
    _detachImageStream();
    _transformController.removeListener(_onMatrixChanged);
    _matrixAnimationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCookie = (widget.item.headers?['Cookie'] ?? '').trim().isNotEmpty;
    final isRiverSideImage = _isRiverSideImageUrl(widget.item.url);
    final requestHeaders = _retryWithoutCookie
        ? _headersWithoutCookie(widget.item.headers)
        : widget.item.headers;
    _resolveImagePixelSize(requestHeaders);

    final image = _fallbackToDirectImage
        ? _buildDirectImage(requestHeaders, hasCookie)
        : _buildCachedImage(requestHeaders, hasCookie, isRiverSideImage);

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
          onLongPress: widget.onLongPress,
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
                      onInteractionStart: (_) {
                        _syncDoubleTapCycleToScale(_currentScale);
                        _showMiniMapTemporarily();
                      },
                      onInteractionUpdate: (_) {
                        _showMiniMapTemporarily();
                      },
                      onInteractionEnd: (_) {
                        _syncDoubleTapCycleToScale(_currentScale);
                        _showMiniMapTemporarily();
                      },
                      child: child!,
                    ),
                  ),
                  if (scale >= _miniMapShowScale)
                    IgnorePointer(
                      ignoring: !_showMiniMapOverlay,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        opacity: _showMiniMapOverlay ? 1 : 0,
                        child: _MiniMapPanel(
                          imageUrl: widget.item.url,
                          headers: requestHeaders,
                          viewportSize: _viewportSize,
                          matrix: _transformController.value,
                          imagePixelSize: _imagePixelSize,
                          onPanUpdate: _onMiniMapPanUpdate,
                        ),
                      ),
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

  void _onMatrixChanged() {
    final scale = _currentScale;
    if (scale < _miniMapShowScale) {
      _miniMapFadeTimer?.cancel();
      if (!_showMiniMapOverlay && mounted) {
        setState(() {
          _showMiniMapOverlay = true;
        });
      }
    }
  }

  void _syncDoubleTapCycleToScale(double scale) {
    if ((scale - _doubleTapMinScale).abs() < 0.08) {
      _doubleTapCycleIndex = 0;
      return;
    }
    if ((scale - _doubleTapMaxScale).abs() < 0.12) {
      _doubleTapCycleIndex = 2;
      return;
    }
    if ((scale - _doubleTapMidScale).abs() < 0.12) {
      if (_doubleTapCycleIndex == 0 || _doubleTapCycleIndex == 2) {
        _doubleTapCycleIndex = 1;
      }
      return;
    }
    if (scale < _doubleTapMidScale) {
      _doubleTapCycleIndex = 0;
      return;
    }
    _doubleTapCycleIndex = 2;
  }

  void _showMiniMapTemporarily() {
    if (_currentScale < _miniMapShowScale) {
      return;
    }
    if (!_showMiniMapOverlay && mounted) {
      setState(() {
        _showMiniMapOverlay = true;
      });
    }
    _miniMapFadeTimer?.cancel();
    _miniMapFadeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _currentScale < _miniMapShowScale) {
        return;
      }
      setState(() {
        _showMiniMapOverlay = false;
      });
    });
  }

  void _onDoubleTap() {
    if (_viewportSize.width <= 0 || _viewportSize.height <= 0) {
      return;
    }

    final currentScale = _currentScale;
    _syncDoubleTapCycleToScale(currentScale);
    final targetScale = _doubleTapScaleSequence[_doubleTapCycleIndex];
    _doubleTapCycleIndex =
        (_doubleTapCycleIndex + 1) % _doubleTapScaleSequence.length;
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

    _showMiniMapTemporarily();
    _animateToMatrix(_composeMatrix(targetScale, clamped.dx, clamped.dy));
  }

  void _animateToMatrix(Matrix4 target) {
    _matrixAnimationController.stop();
    _matrixAnimation =
        Matrix4Tween(begin: _transformController.value, end: target).animate(
          CurvedAnimation(
            parent: _matrixAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _matrixAnimationController.forward(from: 0);
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
    _showMiniMapTemporarily();
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

  ImageProvider<Object>? _currentImageProvider(Map<String, String>? headers) {
    if (_useProvidedImage && widget.item.imageProvider != null) {
      return widget.item.imageProvider;
    }
    return CachedNetworkImageProvider(
      widget.item.url,
      headers: headers,
      cacheKey: _buildImageCacheKey(widget.item.url, headers),
    );
  }

  void _resolveImagePixelSize(Map<String, String>? headers) {
    final provider = _currentImageProvider(headers);
    if (provider == null) {
      return;
    }
    final identity = provider.toString();
    if (_imageProviderIdentity == identity) {
      return;
    }
    _detachImageStream();
    _imageProviderIdentity = identity;
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) {
        return;
      }
      final next = Size(width, height);
      if (_imagePixelSize == next) {
        return;
      }
      setState(() {
        _imagePixelSize = next;
      });
    });
    stream.addListener(listener);
    _imageStream = stream;
    _imageStreamListener = listener;
  }

  void _detachImageStream() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  Widget _buildProvidedImage() {
    final provider = widget.item.imageProvider;
    if (provider == null) {
      return const SizedBox.shrink();
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        if (_useProvidedImage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _useProvidedImage = false;
            });
          });
        }
        return _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildCachedImage(
    Map<String, String>? headers,
    bool hasCookie,
    bool isRiverSideImage,
  ) {
    if (_useProvidedImage && widget.item.imageProvider != null) {
      return _buildProvidedImage();
    }
    return CachedNetworkImage(
      imageUrl: widget.item.url,
      httpHeaders: headers,
      cacheKey: _buildImageCacheKey(widget.item.url, headers),
      fit: BoxFit.contain,
      // Disable fade animation to avoid a visual "reload" after Hero transition.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
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
        if (!_fallbackToDirectImage && (hasCookie || isRiverSideImage)) {
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
    required this.imagePixelSize,
    required this.onPanUpdate,
  });

  final String imageUrl;
  final Map<String, String>? headers;
  final Size viewportSize;
  final Matrix4 matrix;
  final Size? imagePixelSize;
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
    final imageAspect =
        imagePixelSize == null ||
            imagePixelSize!.width <= 0 ||
            imagePixelSize!.height <= 0
        ? width / height
        : imagePixelSize!.width / imagePixelSize!.height;
    const maxMiniMapWidth = 116.0;
    const maxMiniMapHeight = 188.0;
    const minMiniMapSize = 56.0;
    var miniMapWidth = maxMiniMapWidth;
    var miniMapHeight = miniMapWidth / imageAspect;
    if (miniMapHeight > maxMiniMapHeight) {
      miniMapHeight = maxMiniMapHeight;
      miniMapWidth = miniMapHeight * imageAspect;
    }
    if (miniMapWidth > maxMiniMapWidth) {
      miniMapWidth = maxMiniMapWidth;
      miniMapHeight = miniMapWidth / imageAspect;
    }
    if (miniMapWidth < minMiniMapSize) {
      miniMapWidth = minMiniMapSize;
      miniMapHeight = miniMapWidth / imageAspect;
    }
    if (miniMapHeight < minMiniMapSize) {
      miniMapHeight = minMiniMapSize;
      miniMapWidth = miniMapHeight * imageAspect;
    }

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
                  child: ColoredBox(
                    color: Colors.black45,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: headers,
                      cacheKey: _buildImageCacheKey(imageUrl, headers),
                      fit: BoxFit.contain,
                    ),
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
