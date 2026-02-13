import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:river/app/app_settings_controller.dart';

class RiverAiService {
  const RiverAiService(this.settings);

  final AppSettingsController settings;

  Future<String> generate({
    required String instruction,
    required String currentText,
    String? referenceText,
  }) async {
    if (!settings.aiConfigured) {
      throw const RiverAiException('请先在“我的 - AI设置”中完成 API 配置');
    }

    final endpoint = Uri.parse(settings.aiBaseUrl);
    final payload = _buildPayload(
      instruction: instruction,
      currentText: currentText,
      referenceText: referenceText,
      stream: false,
    );

    final response = await http
        .post(
          endpoint,
          headers: _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RiverAiException('AI 服务请求失败（HTTP ${response.statusCode}）');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RiverAiException('AI 返回格式无效');
    }
    final content = _extractContentFromChatResponse(decoded);
    if (content.isEmpty) {
      throw const RiverAiException('AI 未返回有效内容');
    }
    return content;
  }

  Stream<String> generateStream({
    required String instruction,
    required String currentText,
    String? referenceText,
  }) async* {
    if (!settings.aiConfigured) {
      throw const RiverAiException('请先在“我的 - AI设置”中完成 API 配置');
    }

    final endpoint = Uri.parse(settings.aiBaseUrl);
    final payload = _buildPayload(
      instruction: instruction,
      currentText: currentText,
      referenceText: referenceText,
      stream: true,
    );

    final client = http.Client();
    try {
      final request = http.Request('POST', endpoint)
        ..headers.addAll(_headers())
        ..body = jsonEncode(payload);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final raw = await response.stream.bytesToString();
        throw RiverAiException(
          'AI 服务请求失败（HTTP ${response.statusCode}）'
          '${raw.trim().isEmpty ? '' : '：$raw'}',
        );
      }

      await for (final chunk in _parseSseContentChunks(response.stream)) {
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _buildPayload({
    required String instruction,
    required String currentText,
    String? referenceText,
    required bool stream,
  }) {
    final userPrompt = _buildUserPrompt(
      instruction: instruction,
      currentText: currentText,
      referenceText: referenceText,
    );
    return <String, dynamic>{
      'model': settings.aiModel,
      'stream': stream,
      'temperature': settings.aiTemperature,
      'messages': <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': settings.aiSystemPrompt,
        },
        <String, String>{
          'role': 'user',
          'content': userPrompt,
        },
      ],
    };
  }

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${settings.aiApiKey}',
    };
  }

  String _buildUserPrompt({
    required String instruction,
    required String currentText,
    String? referenceText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('任务：$instruction');
    buffer.writeln('输出要求：仅输出最终可直接发送/粘贴的正文内容，不要解释。');
    if ((referenceText ?? '').trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('被回复内容：');
      buffer.writeln(referenceText!.trim());
    }
    buffer.writeln();
    buffer.writeln('当前编辑器内容：');
    buffer.writeln(currentText.trim().isEmpty ? '（空）' : currentText.trim());
    return buffer.toString().trim();
  }

  String _extractContentFromChatResponse(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = (message['content'] ?? '').toString().trim();
          if (content.isNotEmpty) {
            return content;
          }
        }
        final fallbackContent = (first['text'] ?? '').toString().trim();
        if (fallbackContent.isNotEmpty) {
          return fallbackContent;
        }
      }
    }
    return (decoded['content'] ?? '').toString().trim();
  }

  Stream<String> _parseSseContentChunks(
    Stream<List<int>> byteStream,
  ) async* {
    await for (final line
        in byteStream.transform(utf8.decoder).transform(const LineSplitter())) {
      final raw = line.trim();
      if (raw.isEmpty || !raw.startsWith('data:')) {
        continue;
      }
      final data = raw.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') {
        continue;
      }
      Map<String, dynamic> decoded;
      try {
        final parsed = jsonDecode(data);
        if (parsed is! Map<String, dynamic>) {
          continue;
        }
        decoded = parsed;
      } catch (_) {
        continue;
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        continue;
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        continue;
      }
      final delta = first['delta'];
      if (delta is Map<String, dynamic>) {
        final content = (delta['content'] ?? '').toString();
        if (content.isNotEmpty) {
          yield content;
        }
      }
    }
  }
}

class RiverAiException implements Exception {
  const RiverAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
