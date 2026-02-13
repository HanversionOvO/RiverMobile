import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemFontsBridge {
  SystemFontsBridge._();

  static const MethodChannel _channel = MethodChannel('river/system_fonts');

  static Future<List<String>> getSystemFonts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <String>[];
    }
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getSystemFonts',
      );
      if (result == null) {
        return const <String>[];
      }
      final fonts =
          result
              .map((item) => item?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return fonts;
    } catch (_) {
      return const <String>[];
    }
  }
}
