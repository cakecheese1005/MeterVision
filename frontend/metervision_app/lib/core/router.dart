import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/consumer_list_screen.dart';
import '../screens/meter_capture_screen.dart';
import '../screens/ocr_verification_screen.dart';
import '../screens/submit_reading_screen.dart';
import '../screens/sync_screen.dart';

/// Bundled args for routes that need more than one value passed via `extra`.
class OcrVerificationArgs {
  final String consumerId;
  final String imagePath;
  const OcrVerificationArgs({required this.consumerId, required this.imagePath});
}

class SubmitReadingArgs {
  final String consumerId;
  final String imagePath;
  final String reading;
  final double? ocrConfidence;
  const SubmitReadingArgs({
    required this.consumerId,
    required this.imagePath,
    required this.reading,
    this.ocrConfidence,
  });
}

/// Route path constants — avoids magic strings scattered across screens.
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const consumerList = '/consumers';
  static const meterCapture = '/meter-capture'; // expects consumerId as extra
  static const ocrVerification = '/ocr-verification'; // expects OcrVerificationArgs as extra
  static const submitReading = '/submit-reading'; // expects SubmitReadingArgs as extra
  static const sync = '/sync';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.consumerList,
      builder: (context, state) => const ConsumerListScreen(),
    ),
    GoRoute(
      path: AppRoutes.meterCapture,
      // consumerId passed via `extra` when navigating from ConsumerList
      builder: (context, state) {
        final consumerId = state.extra as String?;
        return MeterCaptureScreen(consumerId: consumerId ?? '');
      },
    ),
    GoRoute(
      path: AppRoutes.ocrVerification,
      builder: (context, state) {
        final args = state.extra as OcrVerificationArgs;
        return OcrVerificationScreen(consumerId: args.consumerId, imagePath: args.imagePath);
      },
    ),
    GoRoute(
      path: AppRoutes.submitReading,
      builder: (context, state) {
        final args = state.extra as SubmitReadingArgs;
        return SubmitReadingScreen(
          consumerId: args.consumerId,
          imagePath: args.imagePath,
          reading: args.reading,
          ocrConfidence: args.ocrConfidence,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.sync,
      builder: (context, state) => const SyncScreen(),
    ),
  ],
);