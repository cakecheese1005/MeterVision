import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/meter_reading_draft.dart';
import '../providers/sync_provider.dart';

/// The offline queue, and the only manual control over it.
///
/// Replaces a placeholder that rendered the literal string
/// "No pending uploads" regardless of what was actually queued.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: sync.isSyncing
                ? null
                : () => ref.read(syncProvider.notifier).syncNow(),
            icon: sync.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusBanner(
            isOnline: isOnline,
            isSyncing: sync.isSyncing,
            pendingCount: sync.pendingCount,
            lastSyncedAt: sync.lastSyncedAt,
            errorMessage: sync.errorMessage,
          ),
          const Divider(height: 1),
          Expanded(
            child: sync.pending.isEmpty
                ? const _EmptyQueue()
                : _QueueList(pending: sync.pending),
          ),
          if (sync.hasPending)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () => ref.read(syncProvider.notifier).syncNow(),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(
                      sync.isSyncing
                          ? 'SYNCING...'
                          : 'SYNC ${sync.pendingCount} '
                              '${sync.pendingCount == 1 ? "READING" : "READINGS"}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const _StatusBanner({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.lastSyncedAt,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final color = !isOnline
        ? AppColors.pending
        : (pendingCount == 0 ? AppColors.success : AppColors.primary);

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color),
              ),
              const Spacer(),
              Text(
                pendingCount == 0
                    ? 'Queue empty'
                    : '$pendingCount pending',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (lastSyncedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Last sync: ${DateFormat('d MMM, HH:mm').format(lastSyncedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!isOnline && pendingCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Readings will upload automatically when a connection returns.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  final List<MeterReadingDraft> pending;

  const _QueueList({required this.pending});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: pending.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _QueueRow(draft: pending[index]),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  final MeterReadingDraft draft;

  const _QueueRow({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dead = draft.isDeadLettered;

    final statusColor = dead
        ? AppColors.error
        : (draft.syncStatus == SyncStatus.failed
            ? AppColors.pending
            : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                dead ? Icons.report_problem_outlined : Icons.schedule,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading ${draft.meterReading}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy, HH:mm')
                          .format(draft.capturedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: dead
                    ? 'Needs attention'
                    : (draft.awaitingImageOnly
                        ? 'Photo pending'
                        : draft.syncStatus.label),
                color: statusColor,
              ),
            ],
          ),

          if (!draft.locationAvailable) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No GPS recorded',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          if (draft.retryCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Attempt ${draft.retryCount} of ${ApiConstants.maxSyncRetries}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          if (draft.lastError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              draft.lastError!,
              style: TextStyle(fontSize: 12, color: statusColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Dead-lettered drafts stop retrying automatically but are never
          // discarded silently — the officer decides.
          if (dead && draft.localId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(syncProvider.notifier)
                        .retryItem(draft.localId!),
                    child: const Text('RETRY'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextButton(
                    onPressed: () => _confirmDiscard(context, ref),
                    child: const Text(
                      'DISCARD',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this reading?'),
        content: Text(
          'Reading ${draft.meterReading} and its photo will be deleted from '
          'this device permanently. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'DISCARD',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && draft.localId != null) {
      await ref.read(syncProvider.notifier).discardItem(draft.localId!);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 40, color: AppColors.success),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything is synced',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No readings are waiting to upload.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
