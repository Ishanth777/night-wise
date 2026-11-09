import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Persists the auth session in the platform keychain / secure storage
/// (plan §15.1). Plain shared preferences are never used for tokens.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'nightwise.session.v1';

  final FlutterSecureStorage _storage;

  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return Session.fromJson(map.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Session session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // ignore — nothing to clear
    }
  }
}
