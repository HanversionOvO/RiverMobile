import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RiverSideWebViewSupport {
  static const MethodChannel _channel = MethodChannel('river/webview_support');
  static const int _minimumRecommendedMajorVersion = 80;

  static Future<RiverSideWebViewSupportResult> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const RiverSideWebViewSupportResult(canUseEmbeddedWebView: true);
    }

    try {
      final version = await _channel.invokeMethod<String>('getWebViewVersion');
      final major = _extractMajorVersion(version);
      final supported =
          major != null && major >= _minimumRecommendedMajorVersion;
      return RiverSideWebViewSupportResult(
        canUseEmbeddedWebView: supported,
        detectedVersion: version,
      );
    } on PlatformException {
      return const RiverSideWebViewSupportResult(canUseEmbeddedWebView: false);
    }
  }

  static int? _extractMajorVersion(String? version) {
    if (version == null || version.isEmpty) {
      return null;
    }

    final majorText = version.split('.').first;
    return int.tryParse(majorText);
  }
}

class RiverSideWebViewSupportResult {
  const RiverSideWebViewSupportResult({
    required this.canUseEmbeddedWebView,
    this.detectedVersion,
  });

  final bool canUseEmbeddedWebView;
  final String? detectedVersion;
}
