import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consumer.dart' as models;
import '../services/consumer_repository.dart';
import 'core_providers.dart';

final consumerRepositoryProvider = Provider<ConsumerRepository>((ref) {
  return ApiConsumerRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
    ref.watch(connectivityServiceProvider),
  );
});

/// The officer's consumer list.
///
/// `autoDispose` so it is re-fetched when the officer returns to the list
/// rather than serving an indefinitely stale page, and so it does not survive
/// a logout into the next user's session. Pull-to-refresh invalidates it
/// explicitly.
final consumerListProvider =
    FutureProvider.autoDispose<List<models.Consumer>>((ref) async {
  final repo = ref.watch(consumerRepositoryProvider);
  return repo.getConsumers();
});

/// Single consumer, used by the reading screens to show who the reading is for
/// instead of a bare UUID. Served from the already-loaded list where possible.
final consumerByIdProvider =
    Provider.family<models.Consumer?, String>((ref, consumerId) {
  final list = ref.watch(consumerListProvider).valueOrNull;
  if (list == null) return null;

  for (final consumer in list) {
    if (consumer.id == consumerId) return consumer;
  }
  return null;
});