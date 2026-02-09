import 'package:flutter/services.dart';
import 'package:river/core/constants.dart';

class RiverSideCookieBridge {
  RiverSideCookieBridge();

  static const MethodChannel _channel = MethodChannel('river/webview_cookies');

  Future<String?> getRiverSideCookies() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getCookies',
        <String, Object>{'url': riverSideBaseUrl},
      );
      if (raw == null) {
        return null;
      }

      final value = raw.trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAllCookies() async {
    try {
      await _channel.invokeMethod<bool>('clearAllCookies');
    } catch (_) {
      // Ignore in unsupported platforms/tests.
    }
  }

  Future<void> setRiverSideCookies(String cookieHeader) async {
    final source = cookieHeader.trim();
    if (source.isEmpty) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('setCookies', <String, Object>{
        'url': riverSideBaseUrl,
        'cookieHeader': source,
      });
    } catch (_) {
      // Ignore in unsupported platforms/tests.
    }
  }
}
