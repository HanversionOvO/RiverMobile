part of 'topic_detail_page.dart';

class _MarkdownImage extends StatefulWidget {
  const _MarkdownImage({
    required this.url,
    this.headers,
    required this.viewerItems,
    required this.initialIndex,
    required this.heroTag,
    this.enableHero = true,
  });

  final String url;
  final Map<String, String>? headers;
  final List<RiverImageViewerItem> viewerItems;
  final int initialIndex;
  final String heroTag;
  final bool enableHero;

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  bool _retryWithoutCookie = false;
  bool _fallbackToDirectImage = false;

  @override
  Widget build(BuildContext context) {
    final baseHeaders = _headersForImageUrl(widget.url, widget.headers);
    final hasCookie = (baseHeaders?['Cookie'] ?? '').trim().isNotEmpty;
    final isRiverSideImage = _isRiverSideImageUrl(widget.url);
    final requestHeaders = _retryWithoutCookie
        ? _stripCookieHeader(baseHeaders)
        : baseHeaders;

    final image = _fallbackToDirectImage
        ? _buildDirectImage(context, requestHeaders, hasCookie)
        : _buildCachedImage(
            context,
            requestHeaders,
            hasCookie,
            isRiverSideImage,
          );

    final content = GestureDetector(
      onTap: () => _openPreview(requestHeaders),
      child: widget.enableHero
          ? Hero(tag: widget.heroTag, child: image)
          : image,
    );
    return content;
  }

  void _openPreview(Map<String, String>? headers) {
    final items = List<RiverImageViewerItem>.from(widget.viewerItems);
    if (widget.initialIndex >= 0 && widget.initialIndex < items.length) {
      final current = items[widget.initialIndex];
      final effectiveHeaders = headers ?? current.headers;
      items[widget.initialIndex] = RiverImageViewerItem(
        url: current.url,
        headers: effectiveHeaders,
        heroTag: current.heroTag,
        imageProvider: _buildPreviewImageProvider(effectiveHeaders),
      );
    }

    RiverImageViewerPage.open(
      context,
      items: items,
      initialIndex: widget.initialIndex,
    );
  }

  ImageProvider<Object> _buildPreviewImageProvider(
    Map<String, String>? headers,
  ) {
    if (_fallbackToDirectImage) {
      return NetworkImage(widget.url, headers: headers);
    }
    return CachedNetworkImageProvider(
      widget.url,
      headers: headers,
      cacheKey: _buildImageCacheKey(widget.url, headers),
    );
  }

  Widget _buildCachedImage(
    BuildContext context,
    Map<String, String>? requestHeaders,
    bool hasCookie,
    bool isRiverSideImage,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: widget.url,
        httpHeaders: requestHeaders,
        cacheKey: _buildImageCacheKey(widget.url, requestHeaders),
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => _buildLoadingPlaceholder(context),
        errorWidget: (context, url, error) {
          if (!_retryWithoutCookie && hasCookie) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _retryWithoutCookie = true;
              });
            });
            return _buildLoadingPlaceholder(context);
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
            return _buildLoadingPlaceholder(context);
          }
          return _buildErrorPlaceholder(context);
        },
      ),
    );
  }

  Widget _buildDirectImage(
    BuildContext context,
    Map<String, String>? headers,
    bool hasCookie,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        widget.url,
        headers: headers,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _buildLoadingPlaceholder(context);
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
            return _buildLoadingPlaceholder(context);
          }
          return _buildErrorPlaceholder(context);
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(height: 6),
          Text(
            '\u56fe\u7247\u52a0\u8f7d\u5931\u8d25',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
