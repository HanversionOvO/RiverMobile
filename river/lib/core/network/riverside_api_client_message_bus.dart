part of 'riverside_api_client.dart';

extension RiverSideApiClientMessageBusMethods on RiverSideApiClient {
  Future<List<RiverSideMessageBusEvent>> fetchMessageBusEvents({
    required String clientId,
    required Map<String, int> channelsLastId,
    String? cookieHeader,
    bool disableLongPolling = false,
    Duration timeout = const Duration(seconds: 55),
    int? sequence,
  }) async {
    if (clientId.trim().isEmpty || channelsLastId.isEmpty) {
      return const <RiverSideMessageBusEvent>[];
    }

    final query = disableLongPolling ? '?dlp=t' : '';
    final uri = Uri.parse('$riverSideBaseUrl/message-bus/$clientId/poll$query');
    final body = <String, String>{
      for (final entry in channelsLastId.entries) entry.key: '${entry.value}',
    };
    if (sequence != null) {
      body['__seq'] = '$sequence';
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              ..._buildJsonHeaders(cookieHeader: cookieHeader),
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': riverSideBaseUrl,
              'Dont-Chunk': 'true',
            },
            body: body,
            encoding: utf8,
          )
          .timeout(timeout);
    } on TimeoutException {
      return const <RiverSideMessageBusEvent>[];
    }

    if (response.statusCode == 403) {
      throw const RiverSideApiException(
        'Login session expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw RiverSideApiException(
        'Failed to poll message bus, HTTP ${response.statusCode}',
      );
    }

    final rawBody = utf8.decode(response.bodyBytes).trim();
    if (rawBody.isEmpty) {
      return const <RiverSideMessageBusEvent>[];
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is! List) {
      throw const RiverSideApiException('Invalid message bus response format');
    }

    final events = <RiverSideMessageBusEvent>[];
    for (final raw in decoded) {
      final map = _toStringMap(raw);
      if (map.isEmpty) {
        continue;
      }

      final channel = (map['channel'] ?? '').toString().trim();
      final messageId = _asInt(map['message_id']) ?? -1;
      final globalId = _asInt(map['global_id']) ?? -1;
      if (channel.isEmpty) {
        continue;
      }
      events.add(
        RiverSideMessageBusEvent(
          channel: channel,
          messageId: messageId,
          globalId: globalId,
          data: map['data'],
        ),
      );
    }

    return events;
  }
}
