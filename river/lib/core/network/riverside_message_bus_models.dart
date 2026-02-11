import 'package:flutter/foundation.dart';

@immutable
class RiverSideMessageBusEvent {
  const RiverSideMessageBusEvent({
    required this.channel,
    required this.messageId,
    required this.globalId,
    required this.data,
  });

  final String channel;
  final int messageId;
  final int globalId;
  final dynamic data;

  bool get isStatus => channel == '/__status';
}
