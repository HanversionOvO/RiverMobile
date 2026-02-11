import 'dart:async';
import 'dart:math';

import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/network/riverside_message_bus_models.dart';

typedef RiverSideMessageBusEventsCallback =
    void Function(List<RiverSideMessageBusEvent> events);

typedef RiverSideMessageBusErrorCallback = void Function(Object error);

class RiverSideMessageBusPoller {
  RiverSideMessageBusPoller({
    required RiverSideApiClient apiClient,
    required String cookieHeader,
    required Map<String, int> channelLastIds,
    this.onEvents,
    this.onError,
  }) : _apiClient = apiClient,
       _cookieHeader = cookieHeader.trim(),
       _channelLastIds = <String, int>{...channelLastIds};

  final RiverSideApiClient _apiClient;
  final String _cookieHeader;
  final RiverSideMessageBusEventsCallback? onEvents;
  final RiverSideMessageBusErrorCallback? onError;
  final String _clientId = _generateClientId();

  Map<String, int> _channelLastIds;
  bool _running = false;
  int _runToken = 0;

  bool get isRunning => _running;

  static Map<String, int> buildInitialChannels(
    Iterable<String> channels, {
    int initialLastId = -1,
  }) {
    final result = <String, int>{};
    for (final raw in channels) {
      final key = raw.trim();
      if (key.isEmpty) {
        continue;
      }
      result[key] = initialLastId;
    }
    return result;
  }

  void updateChannels(Map<String, int> channelLastIds) {
    _channelLastIds = <String, int>{...channelLastIds};
  }

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    final token = ++_runToken;
    _runLoop(token);
  }

  void stop() {
    _running = false;
    _runToken++;
  }

  Future<void> _runLoop(int token) async {
    var retryDelay = const Duration(milliseconds: 600);
    while (_running && token == _runToken) {
      if (_channelLastIds.isEmpty || _cookieHeader.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }

      try {
        final events = await _apiClient.fetchMessageBusEvents(
          clientId: _clientId,
          channelsLastId: _channelLastIds,
          cookieHeader: _cookieHeader,
        );
        if (!_running || token != _runToken) {
          return;
        }

        _applyEventsToLastIds(events);
        final nonStatusEvents = events
            .where((event) => !event.isStatus)
            .toList(growable: false);
        if (nonStatusEvents.isNotEmpty) {
          onEvents?.call(nonStatusEvents);
        }
        retryDelay = const Duration(milliseconds: 600);
      } catch (error) {
        if (!_running || token != _runToken) {
          return;
        }
        onError?.call(error);
        await Future<void>.delayed(retryDelay);
        retryDelay = Duration(
          milliseconds: min(retryDelay.inMilliseconds * 2, 8000),
        );
      }
    }
  }

  void _applyEventsToLastIds(List<RiverSideMessageBusEvent> events) {
    for (final event in events) {
      if (event.isStatus) {
        final dataMap = event.data is Map ? event.data as Map : null;
        if (dataMap == null) {
          continue;
        }
        for (final entry in dataMap.entries) {
          final channel = '${entry.key}'.trim();
          if (!_channelLastIds.containsKey(channel)) {
            continue;
          }
          final nextId = int.tryParse('${entry.value}') ?? -1;
          if (nextId >= 0) {
            _channelLastIds[channel] = nextId;
          }
        }
        continue;
      }

      final channel = event.channel;
      if (!_channelLastIds.containsKey(channel) || event.messageId < 0) {
        continue;
      }
      final previous = _channelLastIds[channel] ?? -1;
      if (event.messageId > previous) {
        _channelLastIds[channel] = event.messageId;
      }
    }
  }

  static String _generateClientId() {
    final random = Random.secure();
    const chars = '0123456789abcdef';
    final codes = List<int>.generate(
      24,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      growable: false,
    );
    return String.fromCharCodes(codes);
  }
}
