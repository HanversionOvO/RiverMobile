class RiverSideUserEmailState {
  const RiverSideUserEmailState({
    required this.primaryEmail,
    required this.secondaryEmails,
    required this.unconfirmedEmails,
  });

  final String primaryEmail;
  final List<String> secondaryEmails;
  final List<String> unconfirmedEmails;
}

class RiverSideTitleBadgeOption {
  const RiverSideTitleBadgeOption({
    required this.userBadgeId,
    required this.badgeId,
    required this.name,
    required this.icon,
    required this.imageUrl,
    required this.description,
    required this.grantedAt,
  });

  final int userBadgeId;
  final int badgeId;
  final String name;
  final String icon;
  final String imageUrl;
  final String description;
  final DateTime? grantedAt;
}

class RiverSideUserAuthToken {
  const RiverSideUserAuthToken({
    required this.id,
    required this.clientIp,
    required this.location,
    required this.browser,
    required this.device,
    required this.os,
    required this.icon,
    required this.createdAt,
    required this.seenAt,
    required this.isActive,
  });

  final int id;
  final String clientIp;
  final String location;
  final String browser;
  final String device;
  final String os;
  final String icon;
  final DateTime? createdAt;
  final DateTime? seenAt;
  final bool isActive;
}

class RiverSideAccountSettingsSnapshot {
  const RiverSideAccountSettingsSnapshot({
    required this.username,
    required this.userId,
    required this.displayName,
    required this.title,
    required this.bioRaw,
    required this.hideProfile,
    required this.hidePresence,
    required this.canEdit,
    required this.canEditName,
    required this.canEditEmail,
    required this.canChangeBio,
    required this.canIgnoreUsers,
    required this.ignoredUsernames,
    required this.authTokens,
    required this.emailState,
  });

  final String username;
  final int? userId;
  final String displayName;
  final String title;
  final String bioRaw;
  final bool hideProfile;
  final bool hidePresence;
  final bool canEdit;
  final bool canEditName;
  final bool canEditEmail;
  final bool canChangeBio;
  final bool canIgnoreUsers;
  final List<String> ignoredUsernames;
  final List<RiverSideUserAuthToken> authTokens;
  final RiverSideUserEmailState emailState;

  RiverSideAccountSettingsSnapshot copyWith({
    String? username,
    int? userId,
    String? displayName,
    String? title,
    String? bioRaw,
    bool? hideProfile,
    bool? hidePresence,
    bool? canEdit,
    bool? canEditName,
    bool? canEditEmail,
    bool? canChangeBio,
    bool? canIgnoreUsers,
    List<String>? ignoredUsernames,
    List<RiverSideUserAuthToken>? authTokens,
    RiverSideUserEmailState? emailState,
  }) {
    return RiverSideAccountSettingsSnapshot(
      username: username ?? this.username,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      title: title ?? this.title,
      bioRaw: bioRaw ?? this.bioRaw,
      hideProfile: hideProfile ?? this.hideProfile,
      hidePresence: hidePresence ?? this.hidePresence,
      canEdit: canEdit ?? this.canEdit,
      canEditName: canEditName ?? this.canEditName,
      canEditEmail: canEditEmail ?? this.canEditEmail,
      canChangeBio: canChangeBio ?? this.canChangeBio,
      canIgnoreUsers: canIgnoreUsers ?? this.canIgnoreUsers,
      ignoredUsernames: ignoredUsernames ?? this.ignoredUsernames,
      authTokens: authTokens ?? this.authTokens,
      emailState: emailState ?? this.emailState,
    );
  }
}
