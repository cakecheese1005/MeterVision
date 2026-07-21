import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Field Officer Login', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              const TextField(decoration: InputDecoration(labelText: 'Employee ID')),
              const SizedBox(height: AppSpacing.md),
              const TextField(decoration: InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                // TODO: wire to AuthService.login() -> Supabase JWT
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('LOG IN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
