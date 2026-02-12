part of 'chat_detail_page.dart';

extension _ChatDetailPageView on _ChatDetailPageState {
  String _normalizeEmojiKey(String raw) {
    final value = raw.trim();
    if (value.startsWith(':') && value.endsWith(':') && value.length > 2) {
      return value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  String _displayName(RiverSideChatMessageItem item) {
    final value = item.displayName.trim();
    if (value.isNotEmpty) {
      return value;
    }
    final username = item.username.trim();
    return username.isEmpty ? _ChatDetailPageState._labelUnknownUser : username;
  }

  Widget _emojiTokenWidget(String emojiName, {double size = 18}) {
    final key = _normalizeEmojiKey(emojiName);
    final url = _emojiUrls[key] ?? _emojiUrls[key.toLowerCase()];
    if (url != null && url.trim().isNotEmpty) {
      final resolved = _resolveForumUrl(url);
      return CachedNetworkImage(
        imageUrl: resolved,
        httpHeaders: _headersForUrl(resolved),
        width: size,
        height: size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (context, imageUrl, error) => Text(
          _ChatDetailPageState._fallbackReactionSymbols[key] ?? ':$key:',
          style: TextStyle(fontSize: size - 1),
        ),
      );
    }
    return Text(
      _ChatDetailPageState._fallbackReactionSymbols[key] ?? ':$key:',
      style: TextStyle(fontSize: size - 1),
    );
  }

  String _stripHtml(String source) {
    if (source.isEmpty) {
      return '';
    }
    return source
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _resolveForumUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return value;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('/')) {
      return '$riverSideBaseUrl$value';
    }
    return '$riverSideBaseUrl/$value';
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
}

class _ChatEmojiInlineSyntax extends md.InlineSyntax {
  _ChatEmojiInlineSyntax(this.emojiUrls) : super(r':([a-zA-Z0-9_+\-]+):');

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

class _ChatEmojiBuilder extends MarkdownElementBuilder {
  _ChatEmojiBuilder({required this.resolveUrl, required this.headersForUrl});

  final String Function(String raw) resolveUrl;
  final Map<String, String>? Function(String resolvedUrl) headersForUrl;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final url = (element.attributes['data-url'] ?? '').trim();
    if (url.isEmpty) {
      return Text(':${element.textContent}:', style: preferredStyle);
    }
    final resolved = resolveUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: CachedNetworkImage(
        imageUrl: resolved,
        httpHeaders: headersForUrl(resolved),
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
