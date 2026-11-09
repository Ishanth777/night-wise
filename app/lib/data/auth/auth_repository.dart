import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';
import '../../core/models/models.dart';

/// Auth flows (plan §15.1). Tokens live only in secure storage; the UI never
/// sees the refresh token.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore store})
      : _api = api,
        _store = store;

  final ApiClient _api;
  final TokenStore _store;

  Future<Session?> restore() => _store.read();

  Future<Session> login({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    final session = Session.fromJson(_asMap(data));
    await _store.write(session);
    return session;
  }

  Future<Session> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await _api.post('/auth/register', data: {
      'email': email.trim(),
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    });
    final session = Session.fromJson(_asMap(data));
    await _store.write(session);
    return session;
  }

  Future<void> logout() async {
    final session = await _store.read();
    if (session != null) {
      try {
        await _api.post('/auth/logout', data: {'refreshToken': session.refreshToken});
      } catch (_) {
        // Best-effort revocation; local sign-out must always succeed.
      }
    }
    await _store.clear();
  }

  /// Hard-deletes the account. Server anonymizes authored reports (plan §15.2).
  Future<void> deleteAccount() async {
    await _api.delete('/auth/account');
    await _store.clear();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    throw StateError('Unexpected auth response');
  }
}
