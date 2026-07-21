import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../models/consumer.dart' as models;
import '../providers/consumer_provider.dart';

class ConsumerListScreen extends ConsumerWidget {
  const ConsumerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UI reads the AsyncValue state from the Riverpod provider
    final consumersAsync = ref.watch(consumerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Consumers'),
      ),
      body: consumersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorState(message: err.toString()),
        data: (consumers) { // Fixed: Using standard variable identifier
          if (consumers.isEmpty) return const _EmptyState();
          
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: consumers.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) => _ConsumerRow(
              consumer: consumers[index], // Fixed parameter signature
            ),
          );
        },
      ),
    );
  }
}

class _ConsumerRow extends StatelessWidget {
  final models.Consumer consumer; // Fixed: Prefixed the type, not the variable
  
  const _ConsumerRow({required this.consumer});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.meterCapture, extra: consumer.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, 
          vertical: AppSpacing.sm,
        ),
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
              child: const Icon(Icons.bolt, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(consumer.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(consumer.consumerNo, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    consumer.address,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No consumers assigned', 
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load consumers\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}