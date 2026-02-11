import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:river/core/platform/riverside_cookie_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountStore extends ChangeNotifier {
  AccountStore({
    required RiverSideApiClient riverSideApiClient,
    required RiverSideCookieBridge riverSideCookieBridge,
  }) : _riverSideApiClient = riverSideApiClient,
       _riverSideCookieBridge = riverSideCookieBridge;

  static const String _storageKeyAccounts = 'river.accounts.v1';
  static const String _storageKeyActiveRiverSide =
      'river.active.riverside.username';
  static const String _storageKeyRiverSideCookies =
      'river.riverside.cookies.v1';
  static const String _legacyStorageKeyRiverSideUserApiCredentials =
      'river.riverside.user_api_credentials.v1';

  final RiverSideApiClient _riverSideApiClient;
  final RiverSideCookieBridge _riverSideCookieBridge;

  SharedPreferences? _prefs;
  bool _initialized = false;

  final Map<AccountProvider, List<UserAccount>> _accounts = {
    AccountProvider.riverSide: <UserAccount>[],
    AccountProvider.qingShuiHePan: <UserAccount>[],
  };

  final Map<String, String> _riverSideCookiesByUsername = <String, String>{};

  String? _activeRiverSideUsername;

  RiverSideApiClient get riverSideApiClient => _riverSideApiClient;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;

    final rawAccounts = _prefs?.getString(_storageKeyAccounts);
    if (rawAccounts != null && rawAccounts.isNotEmpty) {
      try {
        final all = decodeAccounts(rawAccounts);
        for (final account in all) {
          final target = _accounts[account.provider];
          if (target == null) {
            continue;
          }

          final exists = target.any(
            (value) =>
                value.username.toLowerCase() == account.username.toLowerCase(),
          );
          if (!exists) {
            target.add(account);
          }
        }
      } catch (_) {
        await _prefs?.remove(_storageKeyAccounts);
      }
    }

    final rawCookies = _prefs?.getString(_storageKeyRiverSideCookies);
    if (rawCookies != null && rawCookies.isNotEmpty) {
      _restoreCookieMap(rawCookies);
    }

    _activeRiverSideUsername = _prefs?.getString(_storageKeyActiveRiverSide);
    _ensureValidActiveAccount();
    await _prefs?.remove(_legacyStorageKeyRiverSideUserApiCredentials);
    notifyListeners();
  }

  List<UserAccount> accountsOf(AccountProvider provider) {
    final list = _accounts[provider] ?? const <UserAccount>[];
    return List<UserAccount>.unmodifiable(list);
  }

  bool get hasRiverSideAccount =>
      (_accounts[AccountProvider.riverSide]?.isNotEmpty ?? false);

  String? get activeRiverSideUsername => _activeRiverSideUsername;

  UserAccount? get activeRiverSideAccount {
    final username = _activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return null;
    }

    for (final account
        in _accounts[AccountProvider.riverSide] ?? const <UserAccount>[]) {
      if (account.username.toLowerCase() == username.toLowerCase()) {
        return account;
      }
    }

    return null;
  }

  bool isActiveRiverSideAccount(String username) {
    final active = _activeRiverSideUsername;
    if (active == null || active.isEmpty) {
      return false;
    }
    return active.toLowerCase() == username.toLowerCase();
  }

  String? riverSideCookieHeaderFor(String username) {
    final normalized = _normalizeUsername(username);
    if (normalized.isEmpty) {
      return null;
    }
    return _riverSideCookiesByUsername[normalized];
  }

  Future<void> upsertRiverSideCookieHeader({
    required String username,
    required String cookieHeader,
    bool applyToWebView = false,
  }) async {
    final normalized = _normalizeUsername(username);
    final cookie = cookieHeader.trim();
    if (normalized.isEmpty || cookie.isEmpty) {
      return;
    }

    _riverSideCookiesByUsername[normalized] = cookie;
    await _persist();

    if (applyToWebView) {
      await _applyRiverSideCookiesForUsername(username);
    }
  }

  Future<bool> switchActiveRiverSideAccount(String username) async {
    final target = _accounts[AccountProvider.riverSide]?.firstWhere(
      (account) => account.username.toLowerCase() == username.toLowerCase(),
      orElse: () => const UserAccount(
        provider: AccountProvider.riverSide,
        username: '',
        displayName: '',
        avatarUrl: '',
      ),
    );

    if (target == null || target.username.isEmpty) {
      return false;
    }

    final previousActive = _activeRiverSideUsername;
    final switchingToNewAccount =
        previousActive != null &&
        previousActive.isNotEmpty &&
        previousActive.toLowerCase() != target.username.toLowerCase();

    if (switchingToNewAccount) {
      try {
        await captureAndPersistCurrentRiverSideCookies(previousActive);
      } catch (_) {
        // Keep switching flow resilient even if capturing cookies fails.
      }
    }

    await _applyRiverSideCookiesForUsername(target.username);

    _activeRiverSideUsername = target.username;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> upsertRiverSideAccount(UserAccount account) async {
    if (account.provider != AccountProvider.riverSide) {
      return;
    }

    _upsertAccount(account);
    _ensureValidActiveAccount();
    await _persist();
    notifyListeners();
  }

  Future<AddAccountResult> addRiverSideAccount(String rawUsername) async {
    final username = rawUsername.trim();
    if (username.isEmpty) {
      return const AddAccountResult(
        success: false,
        message: 'Username is empty',
      );
    }

    try {
      final profile = await _riverSideApiClient.fetchUserProfile(username);
      _upsertAccount(profile);
      _ensureValidActiveAccount();
      await _persist();
      notifyListeners();
      return AddAccountResult(
        success: true,
        message: 'Saved RiverSide account: ${profile.displayName}',
      );
    } on RiverSideApiException catch (error) {
      return AddAccountResult(success: false, message: error.message);
    } catch (_) {
      return const AddAccountResult(
        success: false,
        message: 'Failed to add RiverSide account',
      );
    }
  }

  Future<void> clearWebViewCookies() async {
    await _riverSideCookieBridge.clearAllCookies();
  }

  Future<void> captureAndPersistActiveRiverSideCookies() async {
    final username = _activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return;
    }
    await captureAndPersistCurrentRiverSideCookies(username);
  }

  Future<void> captureAndPersistCurrentRiverSideCookies(String username) async {
    final normalized = _normalizeUsername(username);
    if (normalized.isEmpty) {
      return;
    }

    String? cookieHeader;
    for (var i = 0; i < 15; i++) {
      cookieHeader = await _riverSideCookieBridge.getRiverSideCookies();
      if (cookieHeader != null && cookieHeader.trim().isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return;
    }

    final normalizedCookie = cookieHeader.trim();
    if (!_looksLikeAuthenticatedCookie(normalizedCookie)) {
      return;
    }

    try {
      final current = await _riverSideApiClient.fetchCurrentUserByCookie(
        cookieHeader: normalizedCookie,
        fallbackLogin: username,
      );
      if (_normalizeUsername(current.username) != normalized) {
        return;
      }
    } catch (_) {
      return;
    }

    _riverSideCookiesByUsername[normalized] = normalizedCookie;
    await _persist();
  }

  Future<void> syncActiveRiverSideCookieToWebView() async {
    final username = _activeRiverSideUsername;
    if (username == null || username.isEmpty) {
      return;
    }

    await _applyRiverSideCookiesForUsername(username);
  }

  Future<void> removeRiverSideAccounts(Iterable<String> usernames) async {
    final removeSet = usernames
        .map(_normalizeUsername)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (removeSet.isEmpty) {
      return;
    }

    final riverAccounts = _accounts[AccountProvider.riverSide];
    if (riverAccounts == null || riverAccounts.isEmpty) {
      return;
    }

    riverAccounts.removeWhere(
      (account) => removeSet.contains(_normalizeUsername(account.username)),
    );
    _riverSideCookiesByUsername.removeWhere(
      (key, _) => removeSet.contains(_normalizeUsername(key)),
    );

    _ensureValidActiveAccount();

    final active = _activeRiverSideUsername;
    if (active == null || active.isEmpty) {
      await _riverSideCookieBridge.clearAllCookies();
    } else {
      await _applyRiverSideCookiesForUsername(active);
    }

    await _persist();
    notifyListeners();
  }

  void _ensureValidActiveAccount() {
    final riverAccounts =
        _accounts[AccountProvider.riverSide] ?? const <UserAccount>[];

    if (riverAccounts.isEmpty) {
      _activeRiverSideUsername = null;
      return;
    }

    final active = _activeRiverSideUsername;
    if (active == null || active.isEmpty) {
      _activeRiverSideUsername = riverAccounts.first.username;
      return;
    }

    final exists = riverAccounts.any(
      (account) => account.username.toLowerCase() == active.toLowerCase(),
    );

    if (!exists) {
      _activeRiverSideUsername = riverAccounts.first.username;
    }
  }

  Future<void> _applyRiverSideCookiesForUsername(String username) async {
    final normalized = _normalizeUsername(username);
    if (normalized.isEmpty) {
      return;
    }

    try {
      await _riverSideCookieBridge.clearAllCookies();
      final cookieHeader = _riverSideCookiesByUsername[normalized];
      if (cookieHeader == null || cookieHeader.isEmpty) {
        return;
      }
      await _riverSideCookieBridge.setRiverSideCookies(cookieHeader);
    } catch (_) {
      // Keep account switching flow resilient even if cookie sync fails.
    }
  }

  void _restoreCookieMap(String rawSource) {
    try {
      final decoded = jsonDecode(rawSource);
      if (decoded is! Map) {
        return;
      }

      for (final entry in decoded.entries) {
        final key = _normalizeUsername('${entry.key}');
        final value = '${entry.value}'.trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        _riverSideCookiesByUsername[key] = value;
      }
    } catch (_) {
      // Ignore malformed cookie cache.
    }
  }

  String _normalizeUsername(String source) {
    return source.trim().toLowerCase();
  }

  bool _looksLikeAuthenticatedCookie(String cookieHeader) {
    final source = cookieHeader.toLowerCase();
    return source.contains('_forum_session=') || source.contains('_t=');
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();

    final merged = <UserAccount>[
      ..._accounts[AccountProvider.riverSide] ?? const <UserAccount>[],
      ..._accounts[AccountProvider.qingShuiHePan] ?? const <UserAccount>[],
    ];

    await _prefs?.setString(_storageKeyAccounts, encodeAccounts(merged));

    if (_activeRiverSideUsername == null || _activeRiverSideUsername!.isEmpty) {
      await _prefs?.remove(_storageKeyActiveRiverSide);
    } else {
      await _prefs?.setString(
        _storageKeyActiveRiverSide,
        _activeRiverSideUsername!,
      );
    }

    await _prefs?.setString(
      _storageKeyRiverSideCookies,
      jsonEncode(_riverSideCookiesByUsername),
    );
  }

  void _upsertAccount(UserAccount account) {
    final target = _accounts[account.provider];
    if (target == null) {
      return;
    }

    final index = target.indexWhere(
      (value) => value.username.toLowerCase() == account.username.toLowerCase(),
    );

    if (index >= 0) {
      target[index] = account;
    } else {
      target.add(account);
    }
  }
}
