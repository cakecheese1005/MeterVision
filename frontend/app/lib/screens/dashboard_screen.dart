import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref, sync.pendingCount),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null) _OfficerCard(name: user.name, email: user.email),
            const SizedBox(height: AppSpacing.md),
            _tile(
              context,
              label: 'Consumers',
              icon: Icons.people_outline,
              route: AppRoutes.consumerList,
            ),
            const SizedBox(height: AppSpacing.sm),
            _tile(
              context,
              label: 'Sync Status',
              icon: isOnline ? Icons.sync : Icons.cloud_off_outlined,
              route: AppRoutes.sync,
              badgeCount: sync.pendingCount,
              badgeColor:
                  sync.hasDeadLettered ? AppColors.error : AppColors.pending,
              subtitle: _syncSubtitle(sync, isOnline),
            ),
          ],
        ),
      ),
    );
  }

  static String _syncSubtitle(SyncState sync, bool isOnline) {
    if (sync.isSyncing) return 'Syncing...';
    if (sync.hasDeadLettered) {
      return '${sync.deadLettered.length} need attention';
    }
    if (sync.pendingCount == 0) return 'All readings uploaded';
    return isOnline
        ? '${sync.pendingCount} waiting to upload'
        : '${sync.pendingCount} queued — offline';
  }

  Widget _tile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
    String? subtitle,
    int badgeCount = 0,
    Color badgeColor = AppColors.pending,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(route),
      ),
    );
  }

  /// Logging out clears the tokens but NOT the Hive queue, so warn plainly if
  /// there is unsynced work — the next officer to sign in on this handset
  /// would otherwise inherit it.
  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    int pendingCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          pendingCount > 0
              ? 'You have $pendingCount reading'
                  '${pendingCount == 1 ? "" : "s"} that have not been uploaded '
                  'yet. They will stay on this device, but will not sync until '
                  'you log back in.'
              : 'You will need your email and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // The router's redirect handles navigation once auth state flips.
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _OfficerCard extends StatelessWidget {
  final String name;
  final String email;

  const _OfficerCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.badge_outlined,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    'Field Officer',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
