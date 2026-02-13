class RiverServerConfig {
  RiverServerConfig._();

  static final RiverServerConfig instance = RiverServerConfig._();

  static const String defaultBaseUrl = 'https://river-side.cc';
  static const String defaultUpdateManifestUrl =
      'https://gitee.com/hanversion/river-mobile-update/raw/master/updater.json';

  String _baseUrl = defaultBaseUrl;
  String _updateManifestUrl = defaultUpdateManifestUrl;

  String get baseUrl => _baseUrl;
  String get updateManifestUrl => _updateManifestUrl;
  String get host => Uri.parse(_baseUrl).host.toLowerCase();

  void apply({required String baseUrl, required String updateManifestUrl}) {
    _baseUrl = normalizeBaseUrl(baseUrl);
    _updateManifestUrl = normalizeUrl(updateManifestUrl);
  }

  void updateBaseUrl(String value) {
    _baseUrl = normalizeBaseUrl(value);
  }

  void setUpdateManifestUrl(String value) {
    _updateManifestUrl = normalizeUrl(value);
  }

  static String normalizeBaseUrl(String input) {
    final normalized = normalizeUrl(input);
    final uri = Uri.parse(normalized);
    if (uri.host.isEmpty) {
      throw const FormatException('Invalid host');
    }
    return _removeTrailingSlash(uri.toString());
  }

  static String normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('Empty url');
    }
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Invalid url');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const FormatException('Unsupported scheme');
    }
    return _removeTrailingSlash(uri.toString());
  }

  bool isForumHost(String? hostValue) {
    final host = hostValue?.trim().toLowerCase() ?? '';
    if (host.isEmpty) {
      return false;
    }
    return host == this.host || host.endsWith('.${this.host}');
  }

  static String _removeTrailingSlash(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }
}
