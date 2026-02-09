import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AccountProvider { riverSide, qingShuiHePan }

@immutable
class UserAccount {
  const UserAccount({
    required this.provider,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.userId,
    this.title = '',
  });

  final AccountProvider provider;
  final int? userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String title;

  UserAccount copyWith({
    AccountProvider? provider,
    int? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? title,
  }) {
    return UserAccount(
      provider: provider ?? this.provider,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider': provider.name,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'title': title,
    };
  }

  static UserAccount? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final map = raw.map((key, value) => MapEntry('$key', value));
    final providerName = (map['provider'] ?? '').toString();
    final provider = _providerFromString(providerName);
    if (provider == null) {
      return null;
    }

    final username = (map['username'] ?? '').toString().trim();
    if (username.isEmpty) {
      return null;
    }

    final displayName = (map['displayName'] ?? username).toString().trim();
    return UserAccount(
      provider: provider,
      userId: _asInt(map['userId']),
      username: username,
      displayName: displayName.isEmpty ? username : displayName,
      avatarUrl: (map['avatarUrl'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
    );
  }

  static AccountProvider? _providerFromString(String value) {
    for (final provider in AccountProvider.values) {
      if (provider.name == value) {
        return provider;
      }
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

@immutable
class AddAccountResult {
  const AddAccountResult({required this.success, required this.message});

  final bool success;
  final String message;
}

String encodeAccounts(List<UserAccount> accounts) {
  final payload = accounts.map((account) => account.toJson()).toList();
  return jsonEncode(payload);
}

List<UserAccount> decodeAccounts(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    return const <UserAccount>[];
  }

  final result = <UserAccount>[];
  for (final item in decoded) {
    final parsed = UserAccount.fromJson(item);
    if (parsed != null) {
      result.add(parsed);
    }
  }
  return result;
}
