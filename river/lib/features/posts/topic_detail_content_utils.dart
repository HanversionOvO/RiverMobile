part of 'topic_detail_page.dart';

abstract class _PostContentBlock {
  const _PostContentBlock();
}

class _MarkdownBlock extends _PostContentBlock {
  const _MarkdownBlock(this.markdown);

  final String markdown;
}

class _QuoteBlock extends _PostContentBlock {
  const _QuoteBlock({required this.ref, required this.contentMarkdown});

  final _QuoteRef ref;
  final String contentMarkdown;
}

class _QuoteRef {
  const _QuoteRef({
    required this.username,
    required this.topicId,
    required this.postNumber,
  });

  final String username;
  final int topicId;
  final int postNumber;
}

List<_PostContentBlock> _parsePostContentBlocks(String source, int topicId) {
  final content = source.trim();
  if (content.isEmpty) {
    return const <_PostContentBlock>[];
  }

  final matches = RegExp(
    r'\[quote="([^"]+)"\]([\s\S]*?)\[/quote\]',
    caseSensitive: false,
  ).allMatches(content);

  if (matches.isEmpty) {
    return <_PostContentBlock>[_MarkdownBlock(content)];
  }

  final blocks = <_PostContentBlock>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      final markdown = content.substring(cursor, match.start).trim();
      if (markdown.isNotEmpty) {
        blocks.add(_MarkdownBlock(markdown));
      }
    }

    final header = (match.group(1) ?? '').trim();
    final quoted = (match.group(2) ?? '').trim();
    blocks.add(
      _QuoteBlock(
        ref: _parseQuoteRef(header, topicId),
        contentMarkdown: quoted,
      ),
    );
    cursor = match.end;
  }

  if (cursor < content.length) {
    final markdown = content.substring(cursor).trim();
    if (markdown.isNotEmpty) {
      blocks.add(_MarkdownBlock(markdown));
    }
  }

  return blocks;
}

_QuoteRef _parseQuoteRef(String header, int fallbackTopicId) {
  var username = _TopicDetailPageState._labelUnknownUser;
  final parts = header.split(',');
  if (parts.isNotEmpty) {
    final first = parts.first.trim();
    if (first.isNotEmpty && !first.contains(':')) {
      username = first;
    }
  }

  final postNumber =
      _firstInt(RegExp(r'post:\s*(\d+)', caseSensitive: false), header) ?? 0;
  final topicId =
      _firstInt(RegExp(r'topic:\s*(\d+)', caseSensitive: false), header) ??
      fallbackTopicId;

  return _QuoteRef(
    username: username,
    topicId: topicId,
    postNumber: postNumber,
  );
}

int? _firstInt(RegExp pattern, String source) {
  final match = pattern.firstMatch(source);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

String _toPlainPreview(String markdown) {
  return markdown
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      .replaceAll(RegExp(r'[`*_>#-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _stripQuotedMarkdown(String markdown) {
  final source = markdown.trim();
  if (source.isEmpty) {
    return source;
  }
  var stripped = source;
  stripped = stripped.replaceAll(
    RegExp(r'\[quote(?:="[^"]*")?\][\s\S]*?\[/quote\]', caseSensitive: false),
    '',
  );
  stripped = stripped.replaceAll(
    RegExp(
      r'<aside\b[^>]*class="[^"]*\bquote\b[^"]*"[^>]*>[\s\S]*?</aside>',
      caseSensitive: false,
    ),
    '',
  );
  stripped = stripped.replaceAll(
    RegExp(
      r'^(?:[^\n]{0,120}:\s*\n)?(?:>\s?.*(?:\n|$))+',
      caseSensitive: false,
    ),
    '',
  );
  return stripped.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

class _EmojiInlineSyntax extends md.InlineSyntax {
  _EmojiInlineSyntax(this.emojiUrls) : super(r':([a-zA-Z0-9_+\-]+):');

  final Map<String, String> emojiUrls;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final key = (match.group(1) ?? '').trim();
    if (key.isEmpty) {
      return false;
    }
    final url = emojiUrls[key] ?? emojiUrls[key.toLowerCase()];
    if (url == null || url.isEmpty) {
      return false;
    }

    final element = md.Element.text('emoji', key);
    element.attributes['data-url'] = url;
    parser.addNode(element);
    return true;
  }
}

class _MentionInlineSyntax extends md.InlineSyntax {
  _MentionInlineSyntax() : super(r'(?<![\w/`])@([a-zA-Z0-9_\-\.]{2,32})');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final username = (match.group(1) ?? '').trim();
    if (username.isEmpty) {
      return false;
    }
    final element = md.Element.text('mention', '@$username');
    element.attributes['data-username'] = username;
    parser.addNode(element);
    return true;
  }
}

class _MentionBuilder extends MarkdownElementBuilder {
  _MentionBuilder({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final username = (element.attributes['data-username'] ?? '').trim();
    if (username.isEmpty) {
      return Text(element.textContent, style: preferredStyle);
    }
    return _InlinePillLink(
      icon: Icons.alternate_email_rounded,
      label: '@$username',
      onTap: () => onTap(username),
    );
  }
}

class _TopicAwareLinkBuilder extends MarkdownElementBuilder {
  _TopicAwareLinkBuilder({
    this.onTapMention,
    this.onTapTopicLink,
    required this.onTapExternalLink,
  });

  final ValueChanged<String>? onTapMention;
  final ValueChanged<int>? onTapTopicLink;
  final ValueChanged<String?> onTapExternalLink;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = (element.attributes['href'] ?? '').trim();
    if (href.isEmpty) {
      return Text(element.textContent, style: preferredStyle);
    }
    final resolved = _resolveForumUrl(href);

    final mentionUsername = _tryParseMentionUsernameFromUrl(resolved);
    if (mentionUsername != null && onTapMention != null) {
      final label = element.textContent.trim();
      final shown = label.isEmpty
          ? '@$mentionUsername'
          : (label.startsWith('@') ? label : '@$mentionUsername');
      return _InlinePillLink(
        icon: Icons.alternate_email_rounded,
        label: shown,
        onTap: () => onTapMention!(mentionUsername),
      );
    }

    final topicId = _tryParseTopicIdFromUrl(resolved);
    if (topicId != null && onTapTopicLink != null) {
      final label = element.textContent.trim();
      return _InlinePillLink(
        icon: Icons.article_outlined,
        label: label.isEmpty ? '帖子 #$topicId' : label,
        onTap: () => onTapTopicLink!(topicId),
      );
    }

    return InkWell(
      onTap: () => onTapExternalLink(resolved),
      child: Text(
        element.textContent.trim().isEmpty ? resolved : element.textContent,
        style: preferredStyle?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _InlinePillLink extends StatelessWidget {
  const _InlinePillLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
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

String? _tryParseMentionUsernameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host.isNotEmpty && !isRiverSideHost(host)) {
    return null;
  }
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  final parts = segments.toList(growable: false);
  if (parts.length < 2 || parts.first != 'u') {
    return null;
  }
  final username = parts[1].split('.').first.trim();
  if (username.isEmpty) {
    return null;
  }
  return username;
}

int? _tryParseTopicIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host.isNotEmpty && !isRiverSideHost(host)) {
    return null;
  }
  final parts = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty || parts.first != 't') {
    return null;
  }
  for (var i = parts.length - 1; i >= 1; i--) {
    final parsed = int.tryParse(parts[i]);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return null;
}

class _EmojiBuilder extends MarkdownElementBuilder {
  _EmojiBuilder({required this.headers});

  final Map<String, String>? headers;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final url = (element.attributes['data-url'] ?? '').trim();
    if (url.isEmpty) {
      return Text(':${element.textContent}:', style: preferredStyle);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: CachedNetworkImage(
        imageUrl: _resolveForumUrl(url),
        httpHeaders: headers,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (context, imageUrl, error) =>
            Text(':${element.textContent}:', style: preferredStyle),
      ),
    );
  }
}

Map<String, String>? _buildImageHeaders(String? cookieHeader) {
  final cookie = cookieHeader?.trim();
  if (cookie == null || cookie.isEmpty) {
    return <String, String>{'Referer': riverSideBaseUrl};
  }
  return <String, String>{'Cookie': cookie, 'Referer': riverSideBaseUrl};
}

Map<String, String>? _headersForImageUrl(
  String url,
  Map<String, String>? headers,
) {
  if (headers == null || headers.isEmpty) {
    return headers;
  }
  final uri = Uri.tryParse(url);
  final host = (uri?.host ?? '').trim().toLowerCase();
  if (host.isEmpty || isRiverSideHost(host)) {
    return headers;
  }
  return null;
}

bool _isRiverSideImageUrl(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').trim().toLowerCase();
  if (host.isEmpty) {
    return false;
  }
  final forumHost = Uri.parse(riverSideBaseUrl).host.toLowerCase();
  return host == forumHost || host.endsWith('.$forumHost');
}

Map<String, String>? _stripCookieHeader(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) {
    return headers;
  }
  final next = <String, String>{};
  headers.forEach((key, value) {
    if (key.toLowerCase() == 'cookie') {
      return;
    }
    next[key] = value;
  });
  return next.isEmpty ? null : next;
}

String _buildImageCacheKey(String url, Map<String, String>? headers) {
  final cookie = (headers?['Cookie'] ?? '').trim();
  if (cookie.isEmpty) {
    return url;
  }
  return '$url#auth';
}

List<RiverImageViewerItem> _buildMarkdownGalleryItems({
  required String markdown,
  required Map<String, String>? headers,
}) {
  final rawUrls = _extractMarkdownImageUrls(markdown);
  if (rawUrls.isEmpty) {
    return const <RiverImageViewerItem>[];
  }

  final items = <RiverImageViewerItem>[];
  for (var i = 0; i < rawUrls.length; i++) {
    final resolved = _resolveForumUrl(rawUrls[i]);
    if (resolved.isEmpty) {
      continue;
    }
    items.add(
      RiverImageViewerItem(
        url: resolved,
        headers: _headersForImageUrl(resolved, headers),
        heroTag: _buildMarkdownHeroTag(
          markdown: markdown,
          index: i,
          imageUrl: resolved,
        ),
      ),
    );
  }
  return items;
}

int _resolveGalleryInitialIndex({
  required List<RiverImageViewerItem> items,
  required String url,
  required int preferredIndex,
}) {
  if (items.isEmpty) {
    return 0;
  }
  if (preferredIndex >= 0 &&
      preferredIndex < items.length &&
      items[preferredIndex].url == url) {
    return preferredIndex;
  }

  for (var i = preferredIndex; i < items.length; i++) {
    if (items[i].url == url) {
      return i;
    }
  }
  for (var i = 0; i < preferredIndex && i < items.length; i++) {
    if (items[i].url == url) {
      return i;
    }
  }
  if (preferredIndex < 0) {
    return 0;
  }
  if (preferredIndex >= items.length) {
    return items.length - 1;
  }
  return preferredIndex;
}

String _buildMarkdownHeroTag({
  required String markdown,
  required int index,
  required String imageUrl,
}) {
  return 'topic-md-gallery-${markdown.hashCode}-$index-${imageUrl.hashCode}';
}

List<String> _extractMarkdownImageUrls(String markdown) {
  if (markdown.trim().isEmpty) {
    return const <String>[];
  }

  final urls = <String>[];
  final pattern = RegExp(
    r'''!\[[^\]]*\]\(([^)]+)\)|<img[^>]+src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(markdown)) {
    var raw = (match.group(1) ?? match.group(2) ?? '').trim();
    if (raw.isEmpty) {
      continue;
    }

    if (raw.startsWith('<') && raw.endsWith('>') && raw.length > 2) {
      raw = raw.substring(1, raw.length - 1).trim();
    }
    final spaceIndex = raw.indexOf(RegExp(r'\s'));
    if (spaceIndex > 0) {
      raw = raw.substring(0, spaceIndex).trim();
    }
    if (raw.isEmpty) {
      continue;
    }
    urls.add(raw);
  }

  return urls;
}

abstract class _MarkdownRenderChunk {
  const _MarkdownRenderChunk();
}

class _MarkdownTextChunk extends _MarkdownRenderChunk {
  const _MarkdownTextChunk(this.markdown);

  final String markdown;
}

class _MarkdownVideoChunk extends _MarkdownRenderChunk {
  const _MarkdownVideoChunk(this.video);

  final _VideoSourceDescriptor video;
}

class _VideoSourceDescriptor {
  const _VideoSourceDescriptor({
    required this.sourceUrl,
    required this.embedUrl,
    required this.providerLabel,
    required this.directVideo,
  });

  final String sourceUrl;
  final String embedUrl;
  final String providerLabel;
  final bool directVideo;
}

List<_MarkdownRenderChunk> _splitMarkdownRenderChunks(String markdown) {
  final source = markdown.trim();
  if (source.isEmpty) {
    return const <_MarkdownRenderChunk>[];
  }

  final chunks = <_MarkdownRenderChunk>[];
  final urlPattern = RegExp(r'(https?:\/\/[^\s<>()]+)', caseSensitive: false);
  final buffer = StringBuffer();
  var cursor = 0;

  void flushTextBuffer() {
    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      chunks.add(_MarkdownTextChunk(text));
    }
    buffer.clear();
  }

  for (final match in urlPattern.allMatches(source)) {
    if (match.start > cursor) {
      buffer.write(source.substring(cursor, match.start));
    }

    final rawUrl = (match.group(0) ?? '').trim();
    final beforeChar = match.start > 0 ? source[match.start - 1] : '\n';
    final afterChar = match.end < source.length ? source[match.end] : '\n';
    final standaloneBefore = RegExp(r'\s').hasMatch(beforeChar);
    final standaloneAfter = RegExp(r'[\s\]\)!?,.;:]').hasMatch(afterChar);
    if (!standaloneBefore || !standaloneAfter) {
      buffer.write(rawUrl);
      cursor = match.end;
      continue;
    }
    final split = _splitUrlAndTrailing(rawUrl);
    final resolvedUrl = _resolveForumUrl(split.item1);
    final descriptor = _parseVideoSourceDescriptor(resolvedUrl);

    if (descriptor == null) {
      buffer.write(rawUrl);
    } else {
      flushTextBuffer();
      chunks.add(_MarkdownVideoChunk(descriptor));
      if (split.item2.isNotEmpty) {
        buffer.write(split.item2);
      }
    }

    cursor = match.end;
  }

  if (cursor < source.length) {
    buffer.write(source.substring(cursor));
  }
  flushTextBuffer();
  return chunks;
}

({String item1, String item2}) _splitUrlAndTrailing(String rawUrl) {
  var url = rawUrl;
  var trailing = '';
  while (url.isNotEmpty &&
      RegExp(r'[),.!?;:]$').hasMatch(url) &&
      !RegExp(r'[\w/]$').hasMatch(url)) {
    trailing = '${url[url.length - 1]}$trailing';
    url = url.substring(0, url.length - 1);
  }
  return (item1: url, item2: trailing);
}

_VideoSourceDescriptor? _parseVideoSourceDescriptor(String resolvedUrl) {
  if (resolvedUrl.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null) {
    return null;
  }

  final host = uri.host.toLowerCase();
  final youtubeId = _extractYoutubeVideoId(uri);
  if (youtubeId != null) {
    return _VideoSourceDescriptor(
      sourceUrl: resolvedUrl,
      embedUrl:
          'https://www.youtube.com/embed/$youtubeId?playsinline=1&autoplay=0&rel=0&modestbranding=1',
      providerLabel: 'YouTube',
      directVideo: false,
    );
  }

  final bilibiliBv = _extractBilibiliBvId(uri);
  if (bilibiliBv != null) {
    return _VideoSourceDescriptor(
      sourceUrl: resolvedUrl,
      embedUrl:
          'https://player.bilibili.com/player.html?bvid=$bilibiliBv&high_quality=1&autoplay=0',
      providerLabel: 'Bilibili',
      directVideo: false,
    );
  }

  if (host.contains('b23.tv')) {
    return _VideoSourceDescriptor(
      sourceUrl: resolvedUrl,
      embedUrl: resolvedUrl,
      providerLabel: 'Bilibili',
      directVideo: false,
    );
  }

  final path = uri.path.toLowerCase();
  const directSuffixes = <String>['.mp4', '.m4v', '.mov', '.webm', '.m3u8'];
  if (directSuffixes.any(path.endsWith)) {
    return _VideoSourceDescriptor(
      sourceUrl: resolvedUrl,
      embedUrl: resolvedUrl,
      providerLabel: '视频',
      directVideo: true,
    );
  }

  return null;
}

String? _extractYoutubeVideoId(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    final parts = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (parts.isEmpty) {
      return null;
    }
    return parts.first;
  }
  if (!host.contains('youtube.com')) {
    return null;
  }
  final v = uri.queryParameters['v']?.trim();
  if (v != null && v.isNotEmpty) {
    return v;
  }
  final parts = uri.pathSegments.where((segment) => segment.isNotEmpty);
  if (parts.isEmpty) {
    return null;
  }
  final list = parts.toList(growable: false);
  if (list.first == 'shorts' || list.first == 'embed') {
    if (list.length >= 2) {
      return list[1];
    }
  }
  return null;
}

String? _extractBilibiliBvId(Uri uri) {
  final host = uri.host.toLowerCase();
  if (!host.contains('bilibili.com') && !host.contains('b23.tv')) {
    return null;
  }
  final queryBv = uri.queryParameters['bvid']?.trim();
  if (queryBv != null && queryBv.isNotEmpty) {
    return queryBv;
  }
  final joinedPath = '/${uri.pathSegments.join('/')}';
  final match = RegExp(r'BV[0-9A-Za-z]+').firstMatch(joinedPath);
  if (match == null) {
    return null;
  }
  return match.group(0);
}

String _resolveForumUrl(String source) {
  final raw = source.trim();
  if (raw.isEmpty) {
    return raw;
  }

  if (raw.startsWith('upload://')) {
    final short = raw.substring('upload://'.length);
    return '$riverSideBaseUrl/uploads/short-url/$short';
  }

  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return raw;
  }
  if (uri.hasScheme) {
    return raw;
  }
  if (raw.startsWith('//')) {
    return 'https:$raw';
  }
  if (raw.startsWith('/')) {
    return '$riverSideBaseUrl$raw';
  }
  return '$riverSideBaseUrl/$raw';
}

Color _onlineStateColor(bool? isOnline, BuildContext context) {
  if (isOnline == null) {
    return Theme.of(context).colorScheme.outline;
  }
  return isOnline ? Colors.green : Theme.of(context).colorScheme.outline;
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '--';
  }

  final local = value.toLocal();
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
