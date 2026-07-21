import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.white, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'MeterVision',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              // TODO: replace with auth-check + auto-navigate once AuthService exists
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Continue', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
