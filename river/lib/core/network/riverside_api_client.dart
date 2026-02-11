import 'dart:convert';

import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:river/core/network/riverside_notification_models.dart';
import 'package:river/core/network/riverside_search_models.dart';
import 'package:river/core/network/riverside_topic_models.dart';

part 'riverside_api_client_profile.dart';
part 'riverside_api_client_topics.dart';
part 'riverside_api_client_posts.dart';
part 'riverside_api_client_reactions.dart';
part 'riverside_api_client_categories_emojis.dart';
part 'riverside_api_client_notifications.dart';
part 'riverside_api_client_chat.dart';
part 'riverside_api_client_chat_parsing.dart';
part 'riverside_api_client_search.dart';
part 'riverside_api_client_parsing.dart';
part 'riverside_api_client_parsing_uploads.dart';
part 'riverside_api_client_parsing_reactions.dart';

class RiverSideApiClient {
  final Map<String, Map<int, String>> _categoryNameCacheByCookieKey =
      <String, Map<int, String>>{};
  final Map<String, Map<int, RiverSideCategoryOption>>
  _categoryOptionCacheByCookieKey =
      <String, Map<int, RiverSideCategoryOption>>{};
  final Map<String, Map<String, String>> _emojiUrlCacheByCookieKey =
      <String, Map<String, String>>{};
  final Map<String, Map<String, List<String>>> _emojiGroupsCacheByCookieKey =
      <String, Map<String, List<String>>>{};
  final Map<String, String> _csrfTokenCacheByCookieKey = <String, String>{};
}

class RiverSideCreateTopicResult {
  const RiverSideCreateTopicResult({
    required this.topicId,
    this.postId,
    this.postNumber,
  });

  final int topicId;
  final int? postId;
  final int? postNumber;
}

class RiverSideApiException implements Exception {
  const RiverSideApiException(this.message);

  final String message;
}
