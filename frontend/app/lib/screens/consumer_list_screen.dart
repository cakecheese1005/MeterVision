import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
// MeterTypeX.label is an extension, and extensions are only in scope in files
// that import the library declaring them — importing consumer.dart is not
// enough, even though Consumer.meterType is typed MeterType.
import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/consumer.dart' as models;
import '../providers/consumer_provider.dart';

class ConsumerListScreen extends ConsumerStatefulWidget {
  const ConsumerListScreen({super.key});

  @override
  ConsumerState<ConsumerListScreen> createState() => _ConsumerListScreenState();
}

class _ConsumerListScreenState extends ConsumerState<ConsumerListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Client-side filter over the already-loaded page.
  ///
  /// Deliberately not `POST /consumers/search`: that would hit the network on
  /// every keystroke, and the whole point of this screen is that it works with
  /// no signal. The server-side search is available on the repository for when
  /// a round grows past what fits in one page.
  List<models.Consumer> _filter(List<models.Consumer> all) {
    if (_query.isEmpty) return all;

    final q = _query.toLowerCase();

    return all.where((c) {
      return c.consumerName.toLowerCase().contains(q) ||
          c.consumerNumber.toLowerCase().contains(q) ||
          c.accountNumber.toLowerCase().contains(q) ||
          c.meterNumber.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final consumersAsync = ref.watch(consumerListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Consumers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search name, consumer no. or meter no.',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: consumersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => _ErrorState(
                error: err,
                onRetry: () => ref.invalidate(consumerListProvider),
              ),
              data: (consumers) {
                final filtered = _filter(consumers);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(consumerListProvider);
                    await ref.read(consumerListProvider.future);
                  },
                  child: filtered.isEmpty
                      ? _EmptyState(hasQuery: _query.isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) => _ConsumerRow(
                            consumer: filtered[index],
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumerRow extends StatelessWidget {
  final models.Consumer consumer;

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
                  Text(
                    consumer.consumerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        consumer.displayReference,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (consumer.meterType != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '· ${consumer.meterType!.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
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
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    // Must stay scrollable so RefreshIndicator still works when empty.
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              const Icon(Icons.people_outline,
                  size: 36, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasQuery ? 'No matching consumers' : 'No consumers assigned',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasQuery
                    ? 'Try a different name or number.'
                    : 'Pull down to refresh.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // ApiException already carries a message written for a human. Anything
    // else gets a generic line rather than a raw toString in the officer's face.
    final message = error is ApiException
        ? (error as ApiException).displayMessage
        : 'Could not load consumers.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }
}
