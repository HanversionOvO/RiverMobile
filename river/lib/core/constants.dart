import 'package:river/core/config/server_config.dart';

String get riverSideBaseUrl => RiverServerConfig.instance.baseUrl;
String get riverSideLoginUrl => '$riverSideBaseUrl/login';
String get riverSideSessionCurrentUrl =>
    '$riverSideBaseUrl/session/current.json';
String get riverUpdateManifestUrl =>
    RiverServerConfig.instance.updateManifestUrl;
String get riverMiniAppsManifestUrl =>
    RiverServerConfig.instance.miniAppsManifestUrl;
String get riverSideHost => RiverServerConfig.instance.host;

bool isRiverSideHost(String? host) {
  return RiverServerConfig.instance.isForumHost(host);
}
