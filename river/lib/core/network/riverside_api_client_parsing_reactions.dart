part of 'riverside_api_client.dart';

extension RiverSideApiClientParsingReactionsMethods on RiverSideApiClient {
  RiverSidePostReactionState? _parsePostReactionStateFromPostPayload(
    Map<String, dynamic> post,
  ) {
    final postId = _asInt(post['id']);
    if (postId == null) {
      return null;
    }
    return RiverSidePostReactionState(
      postId: postId,
      reactions: _extractPostReactions(post['reactions']),
      currentUserReaction: _extractCurrentUserReaction(
        post['current_user_reaction'],
      ),
      reactionUsersCount: _asInt(post['reaction_users_count']) ?? 0,
    );
  }

  List<RiverSidePostReaction> _extractPostReactions(dynamic rawReactions) {
    if (rawReactions is! List) {
      return const <RiverSidePostReaction>[];
    }

    final result = <RiverSidePostReaction>[];
    for (final rawReaction in rawReactions) {
      final reaction = _toStringMap(rawReaction);
      final id = (reaction['id'] ?? reaction['reaction_value'] ?? '')
          .toString()
          .trim();
      if (id.isEmpty) {
        continue;
      }
      result.add(
        RiverSidePostReaction(
          id: id,
          type: (reaction['type'] ?? reaction['reaction_type'] ?? 'emoji')
              .toString()
              .trim(),
          count:
              _asInt(reaction['count'] ?? reaction['reaction_users_count']) ??
              0,
        ),
      );
    }
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  RiverSideCurrentUserReaction? _extractCurrentUserReaction(dynamic raw) {
    final reaction = _toStringMap(raw);
    if (reaction.isEmpty) {
      return null;
    }
    final id = (reaction['id'] ?? reaction['reaction_value'] ?? '')
        .toString()
        .trim();
    if (id.isEmpty) {
      return null;
    }
    return RiverSideCurrentUserReaction(
      id: id,
      type: (reaction['type'] ?? reaction['reaction_type'] ?? 'emoji')
          .toString()
          .trim(),
      canUndo: _asBool(reaction['can_undo']),
    );
  }

  Set<String> _asStringSet(dynamic value) {
    if (value is! Iterable) {
      return const <String>{};
    }
    final set = <String>{};
    for (final item in value) {
      final text = '$item'.trim();
      if (text.isNotEmpty) {
        set.add(text);
      }
    }
    return set;
  }
}
