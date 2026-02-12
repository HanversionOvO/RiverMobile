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

@immutable
class RiverSidePresenceUser {
  const RiverSidePresenceUser({required this.id, required this.username});

  final int id;
  final String username;
}

@immutable
class RiverSidePresenceChannelState {
  const RiverSidePresenceChannelState({
    required this.channelName,
    required this.lastMessageId,
    required this.count,
    required this.users,
    required this.countOnly,
  });

  final String channelName;
  final int lastMessageId;
  final int count;
  final List<RiverSidePresenceUser> users;
  final bool countOnly;
}
