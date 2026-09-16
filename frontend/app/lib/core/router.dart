import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/capture_result.dart';
import '../providers/auth_provider.dart';
import '../screens/consumer_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/meter_capture_screen.dart';
import '../screens/ocr_verification_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/submit_reading_screen.dart';
import '../screens/sync_screen.dart';

/// Bundled args for routes that need more than one value passed via `extra`.
class OcrVerificationArgs {
  final CaptureResult capture;
  const OcrVerificationArgs({required this.capture});
}

class SubmitReadingArgs {
  final CaptureResult capture;
  final String reading;
  final double? ocrConfidence;

  const SubmitReadingArgs({
    required this.capture,
    required this.reading,
    this.ocrConfidence,
  });
}

/// Route paths.
///
/// ---------------------------------------------------------------------
/// WHY THE WORKFLOW ROUTES ARE NESTED UNDER /dashboard
/// ---------------------------------------------------------------------
///
/// They used to be flat top-level routes: `/consumers`, `/meter-capture`,
/// `/submit-reading` and so on. That looks tidier but it breaks the back
/// button, because with flat routes `context.go()` REPLACES the whole
/// navigation stack with a single page.
///
/// Concretely: the submit screen finishes with `context.go(consumerList)` to
/// return the officer to their round. With flat routes that collapsed
/// [dashboard, consumers, capture, verify, submit] down to just [consumers] -
/// so the dashboard no longer existed underneath, the AppBar had nothing to
/// pop to, and back either did nothing or exited the app.
///
/// Nesting fixes it at the source. GoRouter builds one page per path segment,
/// so `go('/dashboard/consumers')` always produces [dashboard, consumers] no
/// matter how you arrived, and every screen has a working back button by
/// construction rather than by remembering to use `push` everywhere.
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';

  static const consumerList = '/dashboard/consumers';

  /// expects consumerId as `extra`
  static const meterCapture = '/dashboard/consumers/capture';

  /// expects OcrVerificationArgs as `extra`
  static const ocrVerification = '/dashboard/consumers/capture/verify';

  /// expects SubmitReadingArgs as `extra`
  static const submitReading = '/dashboard/consumers/capture/verify/submit';

  static const sync = '/dashboard/sync';
}

/// Bridges Riverpod's [authProvider] to GoRouter's `refreshListenable`, so a
/// change in auth status re-runs the redirect below.
class _AuthChangeNotifier extends ChangeNotifier {
  late final ProviderSubscription<AuthState> _subscription;

  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// The router is a provider so the redirect can read auth state.
///
/// Created once and kept alive for the app's lifetime - rebuilding a GoRouter
/// would reset the navigation stack on every auth change.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,

    // ---------------------------------------------------------------
    // Auth guard.
    //
    // Previously the splash screen handled this with a `context.go` on first
    // launch, which meant a deep link straight to /dashboard while logged out
    // rendered the screen. Centralising it here makes every route protected by
    // construction rather than by whichever screen remembered to check.
    // ---------------------------------------------------------------
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;

      final atSplash = location == AppRoutes.splash;
      final atLogin = location == AppRoutes.login;

      // Still restoring the stored session - hold on the splash so no screen
      // flashes before we know who is signed in.
      if (auth.isResolving) {
        return atSplash ? null : AppRoutes.splash;
      }

      // Mid-login. Stay put; the login screen owns its own spinner.
      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) {
        return atLogin ? null : AppRoutes.login;
      }

      // Signed in: splash and login have nothing left to show.
      if (atSplash || atLogin) return AppRoutes.dashboard;

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Everything below /dashboard is a child route, so each level gets its
      // own page in the stack and its own back button.
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'sync',
            builder: (context, state) => const SyncScreen(),
          ),
          GoRoute(
            path: 'consumers',
            builder: (context, state) => const ConsumerListScreen(),
            routes: [
              GoRoute(
                path: 'capture',
                builder: (context, state) {
                  // Defensive rather than `state.extra as String?`.
                  //
                  // With nested routes, a `go()` to a DESCENDANT of this route
                  // builds this page too and hands it that descendant's extra.
                  // A hard cast would throw a TypeError on what is really just
                  // a navigation edge case (deep link, hot reload, restored
                  // state), so unrecognised args fall through to a screen the
                  // officer can back out of.
                  final consumerId = state.extra;
                  if (consumerId is! String || consumerId.isEmpty) {
                    return const _MissingRouteArgs(
                      what: 'consumer',
                      detail: 'Pick a consumer from the list to start a '
                          'reading.',
                    );
                  }
                  return MeterCaptureScreen(consumerId: consumerId);
                },
                routes: [
                  GoRoute(
                    path: 'verify',
                    builder: (context, state) {
                      final args = state.extra;
                      if (args is! OcrVerificationArgs) {
                        return const _MissingRouteArgs(
                          what: 'captured photo',
                          detail: 'Capture a meter photo before verifying a '
                              'reading.',
                        );
                      }
                      return OcrVerificationScreen(capture: args.capture);
                    },
                    routes: [
                      GoRoute(
                        path: 'submit',
                        builder: (context, state) {
                          final args = state.extra;
                          if (args is! SubmitReadingArgs) {
                            return const _MissingRouteArgs(
                              what: 'reading',
                              detail: 'Confirm a meter reading before '
                                  'submitting.',
                            );
                          }
                          return SubmitReadingScreen(
                            capture: args.capture,
                            reading: args.reading,
                            ocrConfidence: args.ocrConfidence,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Shown when a route is reached without the arguments it needs.
///
/// Only reachable through a deep link, a restored navigation state, or hot
/// reload mid-workflow - never through normal use. It exists so those cases
/// produce something the officer can back out of instead of a red error screen.
class _MissingRouteArgs extends StatelessWidget {
  final String what;
  final String detail;

  const _MissingRouteArgs({required this.what, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MeterVision')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline, size: 36),
              const SizedBox(height: 12),
              Text(
                'No $what selected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.consumerList),
                child: const Text('BACK TO CONSUMERS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}