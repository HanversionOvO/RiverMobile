part of 'riverside_api_client.dart';

extension RiverSideApiClientParsingUploadsMethods on RiverSideApiClient {
  String _resolveUploadMarkdown({
    required String rawMarkdown,
    required String cookedHtml,
    required dynamic uploadsRaw,
  }) {
    if (rawMarkdown.isEmpty || !rawMarkdown.contains('upload://')) {
      return rawMarkdown;
    }

    final replacements = _extractUploadReplacementMap(uploadsRaw);
    if (replacements.isEmpty) {
      replacements.addAll(
        _extractUploadReplacementMapFromCooked(
          rawMarkdown: rawMarkdown,
          cookedHtml: cookedHtml,
        ),
      );
    }
    if (replacements.isEmpty) {
      return rawMarkdown;
    }

    return rawMarkdown.replaceAllMapped(
      RegExp(r'upload://[^\s)>\]]+', caseSensitive: false),
      (match) {
        final source = (match.group(0) ?? '').trim();
        if (source.isEmpty) {
          return source;
        }
        return replacements[source] ?? source;
      },
    );
  }

  Map<String, String> _extractUploadReplacementMap(dynamic uploadsRaw) {
    if (uploadsRaw is! List) {
      return <String, String>{};
    }

    final replacements = <String, String>{};
    for (final rawItem in uploadsRaw) {
      final item = _toStringMap(rawItem);
      if (item.isEmpty) {
        continue;
      }

      final url = _normalizeUploadUrl(
        (item['url'] ?? item['short_url'] ?? '').toString(),
      );
      if (url.isEmpty) {
        continue;
      }

      final shortUrl = (item['short_url'] ?? '').toString().trim();
      if (shortUrl.startsWith('upload://')) {
        replacements[shortUrl] = url;
        continue;
      }

      final token = _extractUploadToken(shortUrl);
      if (token.isNotEmpty) {
        replacements['upload://$token'] = url;
      }
    }
    return replacements;
  }

  Map<String, String> _extractUploadReplacementMapFromCooked({
    required String rawMarkdown,
    required String cookedHtml,
  }) {
    if (rawMarkdown.isEmpty || cookedHtml.isEmpty) {
      return <String, String>{};
    }

    final uploadTokens = RegExp(r'upload://[^\s)>\]]+', caseSensitive: false)
        .allMatches(rawMarkdown)
        .map((match) => match.group(0) ?? '')
        .where((it) {
          return it.trim().isNotEmpty;
        })
        .toList();
    if (uploadTokens.isEmpty) {
      return <String, String>{};
    }

    final cookedByToken = <String, String>{};
    final cookedUploadUrls = <String>[];

    // Prefer full-size lightbox URLs when available.
    for (final match in RegExp(
      r'<a[^>]+href\s*=\s*"([^"]+)"[^>]*>',
      caseSensitive: false,
    ).allMatches(cookedHtml)) {
      final tag = (match.group(0) ?? '').toLowerCase();
      if (_isEmojiHtmlTag(tag)) {
        continue;
      }
      final href = _normalizeUploadUrl(match.group(1) ?? '');
      if (!tag.contains('lightbox') || !_looksLikeUploadAssetUrl(href)) {
        continue;
      }
      final token = _extractUploadToken(href);
      if (token.isNotEmpty) {
        cookedByToken.putIfAbsent('upload://$token', () => href);
      }
      if (!cookedUploadUrls.contains(href)) {
        cookedUploadUrls.add(href);
      }
    }

    // Fallback to image src, but explicitly ignore avatar/non-upload assets.
    for (final match in RegExp(
      r'<img[^>]+src\s*=\s*"([^"]+)"[^>]*>',
      caseSensitive: false,
    ).allMatches(cookedHtml)) {
      final tag = (match.group(0) ?? '').toLowerCase();
      final src = _normalizeUploadUrl(match.group(1) ?? '');
      if (_isAvatarHtmlTag(tag, src) || _isEmojiHtmlTag(tag)) {
        continue;
      }
      if (!_looksLikeUploadAssetUrl(src)) {
        continue;
      }
      final token = _extractUploadToken(src);
      if (token.isNotEmpty) {
        cookedByToken.putIfAbsent('upload://$token', () => src);
      }
      if (!cookedUploadUrls.contains(src)) {
        cookedUploadUrls.add(src);
      }
    }

    final replacements = <String, String>{};
    for (final uploadToken in uploadTokens) {
      final resolved = cookedByToken[uploadToken];
      if (resolved != null && resolved.isNotEmpty) {
        replacements[uploadToken] = resolved;
      }
    }
    if (replacements.length == uploadTokens.length) {
      return replacements;
    }

    if (cookedUploadUrls.isEmpty) {
      return replacements;
    }

    final missingTokens = uploadTokens
        .where((token) {
          return !replacements.containsKey(token);
        })
        .toList(growable: false);
    final count = missingTokens.length < cookedUploadUrls.length
        ? missingTokens.length
        : cookedUploadUrls.length;
    final usedUrls = replacements.values.toSet();
    var cursor = 0;
    for (var i = 0; i < count; i++) {
      while (cursor < cookedUploadUrls.length &&
          usedUrls.contains(cookedUploadUrls[cursor])) {
        cursor++;
      }
      if (cursor >= cookedUploadUrls.length) {
        break;
      }
      replacements[missingTokens[i]] = cookedUploadUrls[cursor];
      usedUrls.add(cookedUploadUrls[cursor]);
      cursor++;
    }
    return replacements;
  }

  bool _isAvatarHtmlTag(String tag, String srcUrl) {
    if (tag.contains('avatar')) {
      return true;
    }
    return srcUrl.toLowerCase().contains('/user_avatar/');
  }

  bool _isEmojiHtmlTag(String tag) {
    if (tag.contains('emoji')) {
      return true;
    }
    final normalized = tag.replaceAll("'", '"');
    return normalized.contains('class="emoji') ||
        normalized.contains(' class="emoji ');
  }

  bool _looksLikeUploadAssetUrl(String url) {
    if (url.isEmpty) {
      return false;
    }
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    if (path.isEmpty) {
      return false;
    }
    if (path.contains('/user_avatar/')) {
      return false;
    }
    return path.contains('/uploads/') ||
        path.contains('/optimized/') ||
        path.contains('/original/');
  }

  String _normalizeUploadUrl(String source) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
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

  String _normalizeEmojiUrl(String source) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
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

  String _extractUploadToken(String source) {
    final raw = source.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('upload://')) {
      return raw.substring('upload://'.length);
    }
    const marker = '/uploads/short-url/';
    final markerIndex = raw.indexOf(marker);
    if (markerIndex >= 0) {
      return raw.substring(markerIndex + marker.length);
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.path.isEmpty) {
      return '';
    }
    final paths = uri.pathSegments;
    if (paths.length >= 3 &&
        paths[paths.length - 3] == 'uploads' &&
        paths[paths.length - 2] == 'short-url') {
      return paths.last;
    }
    return '';
  }

  String _sanitizeCookedAsPlainText(String source) {
    if (source.isEmpty) {
      return '';
    }

    return source
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&hellip;', '...')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
