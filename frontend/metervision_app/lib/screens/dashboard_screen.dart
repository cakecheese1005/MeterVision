import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tile(context, 'Consumers', Icons.people_outline, AppRoutes.consumerList),
            const SizedBox(height: AppSpacing.sm),
            _tile(context, 'Sync Status', Icons.sync, AppRoutes.sync),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, IconData icon, String route) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
