import 'package:flutter/foundation.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/network/riverside_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountStore extends ChangeNotifier {
  AccountStore({required RiverSideApiClient riverSideApiClient})
      : _riverSideApiClient = riverSideApiClient;

  static const String _storageKeyAccounts = 'river.accounts.v1';
  static const String _storageKeyActiveRiverSide =
      'river.active.riverside.username';

  final RiverSideApiClient _riverSideApiClient;
  SharedPreferences? _prefs;
  bool _initialized = false;

  final Map<AccountProvider, List<UserAccount>> _accounts = {
    AccountProvider.riverSide: <UserAccount>[],
    AccountProvider.qingShuiHePan: <UserAccount>[],
  };

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

    _activeRiverSideUsername = _prefs?.getString(_storageKeyActiveRiverSide);
    _ensureValidActiveAccount();
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

    for (final account in _accounts[AccountProvider.riverSide] ??
        const <UserAccount>[]) {
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
      return const AddAccountResult(success: false, message: '用户名不能为空');
    }

    try {
      final profile = await _riverSideApiClient.fetchUserProfile(username);
      _upsertAccount(profile);
      _ensureValidActiveAccount();
      await _persist();
      notifyListeners();
      return AddAccountResult(
        success: true,
        message: '已保存 RiverSide 账号：${profile.displayName}',
      );
    } on RiverSideApiException catch (error) {
      return AddAccountResult(success: false, message: error.message);
    } catch (_) {
      return const AddAccountResult(success: false, message: '添加账号失败，请重试');
    }
  }

  void _ensureValidActiveAccount() {
    final riverAccounts = _accounts[AccountProvider.riverSide] ??
        const <UserAccount>[];

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
