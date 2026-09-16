import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/constants.dart';
import '../models/auth_user.dart';
import '../services/auth_repository.dart';
import 'core_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Explicit lifecycle so the router and splash screen can distinguish
/// "still checking" from "definitely logged out".
enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.authenticating;
  bool get hasError => errorMessage != null;

  /// True while the app has not yet decided who, if anyone, is signed in.
  bool get isResolving => status == AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      // Deliberately not `??` - passing null clears the error.
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  /// Called from the splash screen. Restores the persisted session, then
  /// revalidates it against `GET /auth/me` when the network allows.
  Future<void> bootstrap() async {
    final cached = await _repository.restoreSession();

    if (cached == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // A stored session for a non-officer should not resume into the field app.
    if (!cached.isOfficer) {
      await _repository.logout();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _wrongRoleMessage(cached.role),
      );
      return;
    }

    // Optimistically authenticate from storage so the app is usable offline.
    state = AuthState(status: AuthStatus.authenticated, user: cached);

    try {
      final fresh = await _repository.me();

      if (!fresh.isOfficer) {
        await _repository.logout();
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: _wrongRoleMessage(fresh.role),
        );
        return;
      }

      state = AuthState(status: AuthStatus.authenticated, user: fresh);
    } on ApiException catch (e) {
      // A rejected token means log out; anything else (no signal, server
      // down) must not lock a field officer out of the offline queue.
      if (e.isUnauthorized) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Enter your email and password.',
      );
      return false;
    }

    state = const AuthState(status: AuthStatus.authenticating);

    try {
      final user = await _repository.login(email: email, password: password);

      // ---------------------------------------------------------------
      // Role gate.
      //
      // This app is the Field Officer client. Admin uses the React dashboard
      // and LCR has its own workflow, and neither has any usable surface here.
      //
      // The backend does not enforce this: `require_role()` exists in
      // core/security.py and is not applied to a single route, so a valid
      // admin or lcr token would sail straight through every endpoint the app
      // calls. Until that changes, this check is the only thing standing
      // between a dashboard account and a half-broken field UI.
      // ---------------------------------------------------------------
      if (!user.isOfficer) {
        await _repository.logout();
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: _wrongRoleMessage(user.role),
        );
        return false;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.displayMessage,
      );
      return false;
    } catch (e) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  static String _wrongRoleMessage(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'This is the Field Officer app. Admin accounts should use the '
            'web dashboard.';
      case UserRole.lcr:
        return 'This is the Field Officer app. LCR accounts should use the '
            'verification dashboard.';
      case UserRole.officer:
        return 'Your account is not permitted to use this app.';
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Invoked by ApiClient when a refresh attempt fails.
  void onSessionExpired() {
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Your session has expired. Please log in again.',
    );
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.watch(authRepositoryProvider));

  // Let the 401 handler inside ApiClient push the app back to logged-out.
  ref.watch(apiClientProvider).onSessionExpired = () async {
    notifier.onSessionExpired();
  };

  return notifier;
});

/// Convenience selector for widgets that only need the officer's identity.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});
