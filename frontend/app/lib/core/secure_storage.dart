import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single owner of everything sensitive on the device.
///
/// Only [ApiClient] and [AuthRepository] should talk to this class —
/// screens and providers never read tokens directly.
class SecureStorage {
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kName = 'name';
  static const _kEmail = 'email';
  static const _kRole = 'role';
  static const _kDeviceId = 'device_id';

  final FlutterSecureStorage _storage;

  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // ---------------------------------------------------------------
  // Tokens
  // ---------------------------------------------------------------

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  // ---------------------------------------------------------------
  // Session (tokens + identity returned by POST /auth/login)
  // ---------------------------------------------------------------

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kUserId, value: userId),
      _storage.write(key: _kName, value: name),
      _storage.write(key: _kEmail, value: email),
      _storage.write(key: _kRole, value: role),
    ]);
  }

  Future<Map<String, String?>> readSession() async {
    return {
      'access_token': await _storage.read(key: _kAccessToken),
      'refresh_token': await _storage.read(key: _kRefreshToken),
      'user_id': await _storage.read(key: _kUserId),
      'name': await _storage.read(key: _kName),
      'email': await _storage.read(key: _kEmail),
      'role': await _storage.read(key: _kRole),
    };
  }

  /// Used by the splash bootstrap to decide login vs dashboard without
  /// waiting on a network round-trip.
  Future<bool> hasSession() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------
  // Device identity
  //
  // Deliberately survives [clear]: the device is the same handset before
  // and after a logout, and the backend uses device_id to attribute queued
  // rows in sync_queue.
  // ---------------------------------------------------------------

  Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);

  Future<void> saveDeviceId(String deviceId) =>
      _storage.write(key: _kDeviceId, value: deviceId);

  /// Clears the session only. See the note above on [readDeviceId].
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kName),
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kRole),
    ]);
  }
}
