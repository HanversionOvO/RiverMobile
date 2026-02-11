part of 'topic_detail_page.dart';

class _PostContent extends StatelessWidget {
  const _PostContent({
    required this.markdown,
    required this.topicId,
    required this.cookieHeader,
    required this.emojiUrls,
    required this.onQuoteTap,
    this.enableImageHero = true,
  });

  final String markdown;
  final int topicId;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final ValueChanged<_QuoteBlock> onQuoteTap;
  final bool enableImageHero;

  @override
  Widget build(BuildContext context) {
    final blocks = _parsePostContentBlocks(markdown, topicId);
    if (blocks.isEmpty) {
      return const _MarkdownContent(
        markdown: _TopicDetailPageState._labelEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (blocks[i] is _MarkdownBlock)
            _MarkdownContent(
              markdown: (blocks[i] as _MarkdownBlock).markdown,
              cookieHeader: cookieHeader,
              emojiUrls: emojiUrls,
              enableImageHero: enableImageHero,
            )
          else
            _QuotePreviewCard(
              quote: blocks[i] as _QuoteBlock,
              onTap: () => onQuoteTap(blocks[i] as _QuoteBlock),
            ),
          if (i != blocks.length - 1) const SizedBox(height: 10),
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
    this.enableImageHero = true,
  });

  final String markdown;
  final String? cookieHeader;
  final Map<String, String> emojiUrls;
  final bool enableImageHero;

  @override
  Widget build(BuildContext context) {
    final data = markdown.trim().isEmpty
        ? _TopicDetailPageState._labelEmpty
        : markdown;
    final headers = _buildImageHeaders(cookieHeader);
    final galleryItems = _buildMarkdownGalleryItems(
      markdown: data,
      headers: headers,
    );
    var imageBuilderIndex = 0;
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = textTheme.bodyMedium;
    return MarkdownBody(
      data: data,
      selectable: true,
      inlineSyntaxes: emojiUrls.isEmpty
          ? null
          : <md.InlineSyntax>[_EmojiInlineSyntax(emojiUrls)],
      builders: emojiUrls.isEmpty
          ? const <String, MarkdownElementBuilder>{}
          : <String, MarkdownElementBuilder>{
              'emoji': _EmojiBuilder(headers: headers),
            },
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
      onTapLink: (_, href, _) {
        _openLink(href == null ? null : _resolveForumUrl(href));
      },
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
