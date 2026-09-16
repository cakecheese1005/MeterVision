import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../models/auth_user.dart';

/// Contract the AuthProvider depends on. Swapping in a fake for widget tests
/// means implementing this - no Dio or storage mocking required.
abstract class AuthRepository {
  Future<AuthUser> login({required String email, required String password});

  /// GET /auth/me
  Future<AuthUser> me();

  Future<void> logout();

  /// Reads the persisted session without hitting the network.
  /// Returns null when the officer has never logged in.
  Future<AuthUser?> restoreSession();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _client;
  final SecureStorage _storage;

  ApiAuthRepository(this._client, this._storage);

  // ---------------------------------------------------------------
  // POST /auth/login
  //
  // Response envelope:
  // { success, message, data: { access_token, refresh_token, token_type,
  //                             user_id, name, email, role }, timestamp }
  // ---------------------------------------------------------------
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final raw = await _client.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final data = ApiClient.asMap(raw);

    if (data.isEmpty || data['access_token'] == null) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Login response did not contain a token.',
      );
    }

    final session = AuthSession.fromJson(data);

    await _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userId: session.user.id,
      name: session.user.name,
      email: session.user.email,
      role: session.user.role.wireValue,
    );

    return session.user;
  }

  // ---------------------------------------------------------------
  // GET /auth/me
  // ---------------------------------------------------------------
  @override
  Future<AuthUser> me() async {
    final raw = await _client.get(ApiConstants.me);
    final data = ApiClient.asMap(raw);

    if (data.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Profile response was empty.',
      );
    }

    return AuthUser.fromJson(data);
  }

  // ---------------------------------------------------------------
  // POST /auth/logout
  //
  // JWTs are stateless server-side, so clearing local storage is what
  // actually ends the session. The call is best-effort.
  // ---------------------------------------------------------------
  @override
  Future<void> logout() async {
    try {
      await _client.post(ApiConstants.authLogout);
    } on ApiException {
      // Offline or already-expired token: local clear below still applies.
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final session = await _storage.readSession();

    final token = session['access_token'];
    final userId = session['user_id'];

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }

    return AuthUser(
      id: userId,
      name: session['name'] ?? '',
      email: session['email'] ?? '',
      role: UserRoleX.fromWire(session['role']),
    );
  }
}
