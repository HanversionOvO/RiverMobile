part of 'topic_detail_page.dart';

class _PostContent extends StatelessWidget {
  const _PostContent({
    required this.markdown,
    required this.topicId,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    this.onMentionTap,
    this.onTopicLinkTap,
    this.enableImageHero = true,
    this.enableTextSelection = true,
    this.replyToPostNumber,
    this.replyToUsername,
  });

  final String markdown;
  final int topicId;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<int>? onTopicLinkTap;
  final bool enableImageHero;
  final bool enableTextSelection;
  final int? replyToPostNumber;
  final String? replyToUsername;

  @override
  Widget build(BuildContext context) {
    final blocks = _parsePostContentBlocks(markdown, topicId);
    final hasQuoteBlock = blocks.any((block) => block is _QuoteBlock);
    final replyPostNumber = replyToPostNumber ?? 0;
    final canInjectReplyHint = replyPostNumber > 0 && !hasQuoteBlock;
    final mergedBlocks = <_PostContentBlock>[
      if (canInjectReplyHint)
        _QuoteBlock(
          ref: _QuoteRef(
            username: (replyToUsername ?? '').trim().isEmpty
                ? _TopicDetailPageState._labelUnknownUser
                : (replyToUsername ?? '').trim(),
            topicId: topicId,
            postNumber: replyPostNumber,
          ),
          contentMarkdown: '',
        ),
      ...blocks,
    ];

    if (mergedBlocks.isEmpty) {
      return const _MarkdownContent(
        markdown: _TopicDetailPageState._labelEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < mergedBlocks.length; i++) ...[
          if (mergedBlocks[i] is _MarkdownBlock)
            _MarkdownContent(
              markdown: (mergedBlocks[i] as _MarkdownBlock).markdown,
              cookieHeader: cookieHeader,
              emojiUrls: emojiUrls,
              onMentionTap: onMentionTap,
              onTopicLinkTap: onTopicLinkTap,
              enableImageHero: enableImageHero,
              enableTextSelection: enableTextSelection,
            )
          else
            _QuotePreviewCard(
              quote: mergedBlocks[i] as _QuoteBlock,
              onTap: () => onQuoteTap(mergedBlocks[i] as _QuoteBlock),
            ),
          if (i != mergedBlocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _QuotePreviewCard extends StatelessWidget {
  const _QuotePreviewCard({required this.quote, required this.onTap});

  final _QuoteBlock quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = _toPlainPreview(quote.contentMarkdown);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.reply_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u56de\u590d @${quote.ref.username} \u7684 #${quote.ref.postNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview.isEmpty
                          ? '\u67e5\u770b\u88ab\u56de\u590d\u5185\u5bb9'
                          : preview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  const _MarkdownContent({
    required this.markdown,
    this.cookieHeader,
    this.emojiUrls = const <String, String>{},
    this.onMentionTap,
    this.onTopicLinkTap,
    this.enableImageHero = true,
    this.enableTextSelection = true,
  });

  final String markdown;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<int>? onTopicLinkTap;
  final bool enableImageHero;
  final bool enableTextSelection;

  @override
  Widget build(BuildContext context) {
    final data = markdown.trim().isEmpty
        ? _TopicDetailPageState._labelEmpty
        : markdown;
    final chunks = _splitMarkdownRenderChunks(data);
    if (chunks.isNotEmpty &&
        chunks.any((chunk) => chunk is _MarkdownVideoChunk)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < chunks.length; i++) ...[
            if (chunks[i] case final _MarkdownTextChunk textChunk)
              _buildMarkdownBody(context, textChunk.markdown)
            else if (chunks[i] case final _MarkdownVideoChunk videoChunk)
              _InlineVideoSourceCard(video: videoChunk.video),
            if (i != chunks.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return _buildMarkdownBody(context, data);
  }

  Widget _buildMarkdownBody(BuildContext context, String data) {
    final headers = _buildImageHeaders(cookieHeader);
    final galleryItems = _buildMarkdownGalleryItems(
      markdown: data,
      headers: headers,
    );
    var imageBuilderIndex = 0;
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = textTheme.bodyMedium;
    final inlineSyntaxes = <md.InlineSyntax>[
      if (emojiUrls.isNotEmpty) _EmojiInlineSyntax(emojiUrls),
      if (onMentionTap != null) _MentionInlineSyntax(),
    ];
    final builders = <String, MarkdownElementBuilder>{
      if (emojiUrls.isNotEmpty) 'emoji': _EmojiBuilder(headers: headers),
      if (onMentionTap != null)
        'mention': _MentionBuilder(onTap: onMentionTap!),
      'a': _TopicAwareLinkBuilder(
        onTapMention: onMentionTap,
        onTapTopicLink: onTopicLinkTap,
        onTapExternalLink: _openLink,
      ),
    };
    return MarkdownBody(
      data: data,
      selectable: enableTextSelection,
      inlineSyntaxes: inlineSyntaxes,
      builders: builders,
      sizedImageBuilder: (config) {
        final resolvedUrl = _resolveForumUrl('${config.uri}');
        final imageIndex = imageBuilderIndex++;
        final fallbackHeroTag = _buildMarkdownHeroTag(
          markdown: data,
          index: imageIndex,
          imageUrl: resolvedUrl,
        );
        final viewerItems = galleryItems.isNotEmpty
            ? galleryItems
            : <RiverImageViewerItem>[
                RiverImageViewerItem(
                  url: resolvedUrl,
                  headers: headers,
                  heroTag: fallbackHeroTag,
                ),
              ];
        final initialIndex = galleryItems.isNotEmpty
            ? _resolveGalleryInitialIndex(
                items: galleryItems,
                url: resolvedUrl,
                preferredIndex: imageIndex,
              )
            : 0;

        return _MarkdownImage(
          url: resolvedUrl,
          headers: headers,
          viewerItems: viewerItems,
          initialIndex: initialIndex,
          heroTag: viewerItems[initialIndex].heroTag,
          enableHero: enableImageHero,
        );
      },
      onTapLink: (_, href, _) {},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        blockquote: baseStyle?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _openLink(String? href) async {
    final raw = href?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InlineVideoSourceCard extends StatefulWidget {
  const _InlineVideoSourceCard({required this.video});

  final _VideoSourceDescriptor video;

  @override
  State<_InlineVideoSourceCard> createState() => _InlineVideoSourceCardState();
}

class _InlineVideoSourceCardState extends State<_InlineVideoSourceCard> {
  WebViewController? _controller;
  bool _loading = false;
  double _aspectRatio = 16 / 9;

  Future<void> _activatePlayer() async {
    if (_controller != null) {
      return;
    }
    final controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.black);
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) {
            return;
          }
          setState(() => _loading = false);
          if (widget.video.directVideo) {
            _requestDirectVideoMeta(controller);
          }
        },
      ),
    );
    if (widget.video.directVideo) {
      await controller.addJavaScriptChannel(
        'RiverVideoMeta',
        onMessageReceived: (message) {
          _applyVideoMeta(message.message);
        },
      );
    }
    setState(() {
      _loading = true;
      _controller = controller;
    });
    if (widget.video.directVideo) {
      final html =
          '<!doctype html><html><head><meta name="viewport" '
          'content="width=device-width, initial-scale=1.0, maximum-scale=1.0"></head>'
          '<body style="margin:0;background:#000;overflow:hidden;">'
          '<video id="rv_video" controls playsinline webkit-playsinline '
          'style="width:100%;height:100%;object-fit:contain;background:#000;" '
          'src="${widget.video.embedUrl}"></video>'
          '<script>'
          'const v=document.getElementById("rv_video");'
          'function sendMeta(){'
          'if(!v)return;'
          'const w=v.videoWidth||0;const h=v.videoHeight||0;'
          'if(w>0&&h>0&&window.RiverVideoMeta){RiverVideoMeta.postMessage(w+","+h);}'
          '}'
          'v.addEventListener("loadedmetadata",sendMeta);'
          'v.addEventListener("resize",sendMeta);'
          'setTimeout(sendMeta, 120);'
          'setTimeout(sendMeta, 600);'
          '</script>'
          '</body></html>';
      await controller.loadHtmlString(html);
      return;
    }
    final uri = Uri.tryParse(widget.video.embedUrl);
    if (uri != null) {
      await controller.loadRequest(uri);
      return;
    }
    await controller.loadHtmlString(
      '<!doctype html><html><body style="margin:0;background:#000;"></body></html>',
    );
  }

  Future<void> _requestDirectVideoMeta(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(
        '(() => {'
        'const v=document.getElementById("rv_video")||document.querySelector("video");'
        'if(!v){return "";}'
        'const w=v.videoWidth||0;const h=v.videoHeight||0;'
        'return (w>0&&h>0)?(w+","+h):"";'
        '})()',
      );
      _applyVideoMeta('$result');
    } catch (_) {
      // Ignore: metadata may not be available on some devices at this moment.
    }
  }

  void _applyVideoMeta(String raw) {
    final clean = raw.replaceAll('"', '').trim();
    if (clean.isEmpty) {
      return;
    }
    final parts = clean.split(',');
    if (parts.length != 2) {
      return;
    }
    final width = double.tryParse(parts[0].trim()) ?? 0;
    final height = double.tryParse(parts[1].trim()) ?? 0;
    if (width <= 0 || height <= 0) {
      return;
    }
    final ratio = (width / height).clamp(9 / 16, 21 / 9);
    if (!mounted || (ratio - _aspectRatio).abs() < 0.005) {
      return;
    }
    setState(() {
      _aspectRatio = ratio;
    });
  }

  Future<void> _openSource() async {
    await launchUrl(
      Uri.parse(widget.video.sourceUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: widget.video.directVideo ? _aspectRatio : 16 / 9,
            child: _controller == null
                ? Material(
                    color: Colors.black,
                    child: InkWell(
                      onTap: _activatePlayer,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击播放 ${widget.video.providerLabel}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(controller: _controller!),
                      ),
                      if (_loading)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.video.providerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '外部打开',
                  onPressed: _openSource,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
