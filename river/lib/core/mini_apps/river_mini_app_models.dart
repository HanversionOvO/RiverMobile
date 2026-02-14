class RiverMiniAppEntry {
  const RiverMiniAppEntry({
    required this.id,
    required this.name,
    required this.url,
    this.version = '',
    this.packageUrl = '',
    this.packageSha256 = '',
    this.packageBytes = 0,
    this.iconUrl = '',
    this.description = '',
    this.tags = const <String>[],
    this.requiresAuth = false,
    this.enabled = true,
    this.order = 0,
    this.bridgeVersion = '1.0.0',
    this.localEntryFilePath = '',
    this.installedAtMillis = 0,
  });

  final String id;
  final String name;
  final String url;
  final String version;
  final String packageUrl;
  final String packageSha256;
  final int packageBytes;
  final String iconUrl;
  final String description;
  final List<String> tags;
  final bool requiresAuth;
  final bool enabled;
  final int order;
  final String bridgeVersion;
  final String localEntryFilePath;
  final int installedAtMillis;

  bool get isInstalled => localEntryFilePath.trim().isNotEmpty;

  RiverMiniAppEntry copyWith({
    String? id,
    String? name,
    String? url,
    String? version,
    String? packageUrl,
    String? packageSha256,
    int? packageBytes,
    String? iconUrl,
    String? description,
    List<String>? tags,
    bool? requiresAuth,
    bool? enabled,
    int? order,
    String? bridgeVersion,
    String? localEntryFilePath,
    int? installedAtMillis,
  }) {
    return RiverMiniAppEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      version: version ?? this.version,
      packageUrl: packageUrl ?? this.packageUrl,
      packageSha256: packageSha256 ?? this.packageSha256,
      packageBytes: packageBytes ?? this.packageBytes,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      bridgeVersion: bridgeVersion ?? this.bridgeVersion,
      localEntryFilePath: localEntryFilePath ?? this.localEntryFilePath,
      installedAtMillis: installedAtMillis ?? this.installedAtMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'version': version,
      'package_url': packageUrl,
      'package_sha256': packageSha256,
      'package_bytes': packageBytes,
      'icon': iconUrl,
      'description': description,
      'tags': tags,
      'requires_auth': requiresAuth,
      'enabled': enabled,
      'order': order,
      'bridge_version': bridgeVersion,
      'local_entry_file_path': localEntryFilePath,
      'installed_at_millis': installedAtMillis,
    };
  }

  static RiverMiniAppEntry fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw
              .map((item) => '$item'.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return RiverMiniAppEntry(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      url: '${json['url'] ?? ''}'.trim(),
      version: '${json['version'] ?? ''}'.trim(),
      packageUrl: '${json['package_url'] ?? json['packageUrl'] ?? ''}'.trim(),
      packageSha256: '${json['package_sha256'] ?? json['packageSha256'] ?? ''}'
          .trim()
          .toLowerCase(),
      packageBytes: _readInt(
        json['package_bytes'] ?? json['package_size'] ?? json['packageSize'],
      ),
      iconUrl: '${json['icon'] ?? json['icon_url'] ?? ''}'.trim(),
      description: '${json['description'] ?? ''}'.trim(),
      tags: tags,
      requiresAuth: _readBool(json['requires_auth'] ?? json['requiresAuth']),
      enabled: _readBool(json['enabled'], fallback: true),
      order: _readInt(json['order']),
      bridgeVersion:
          '${json['bridge_version'] ?? json['bridgeVersion'] ?? '1.0.0'}'
              .trim(),
      localEntryFilePath: '${json['local_entry_file_path'] ?? ''}'.trim(),
      installedAtMillis: _readInt(json['installed_at_millis']),
    );
  }

  static bool _readBool(dynamic raw, {bool fallback = false}) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final text = '$raw'.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return fallback;
  }

  static int _readInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse('$raw') ?? fallback;
  }
}

class RiverMiniAppManifest {
  const RiverMiniAppManifest({
    required this.sourceUrl,
    required this.entries,
    this.version = '',
    this.updatedAt = '',
  });

  final String sourceUrl;
  final String version;
  final String updatedAt;
  final List<RiverMiniAppEntry> entries;
}
