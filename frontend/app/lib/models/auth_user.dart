import '../core/constants.dart';

/// The authenticated officer.
///
/// `POST /auth/login` returns `LoginData` (id lives under `user_id`) while
/// `GET /auth/me` returns `UserProfile` (id lives under `id`), so [fromJson]
/// accepts both shapes.
class AuthUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phoneNumber;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
  });

  bool get isOfficer => role == UserRole.officer;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['user_id'] ?? json['id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: UserRoleX.fromWire(json['role']?.toString()),
      phoneNumber: json['phone_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.wireValue,
        'phone_number': phoneNumber,
      };
}

/// Tokens + identity, exactly as returned by `POST /auth/login`.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'bearer',
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      user: AuthUser.fromJson(json),
    );
  }
}
