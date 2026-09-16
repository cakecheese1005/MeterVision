import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/constants.dart';
import '../core/local_store.dart';
import '../core/network/connectivity_service.dart';
import '../models/consumer.dart';

abstract class ConsumerRepository {
  /// Paging is an implementation concern, so it stays off the interface.
  /// Adding optional named parameters in an override is legal in Dart, which
  /// lets [ApiConsumerRepository.getConsumers] take `page`/`pageSize` without
  /// forcing every implementation (or every caller) to know about them.
  Future<List<Consumer>> getConsumers();
}

/// Talks to `GET /consumers/` and caches the result in Hive.
///
/// ---------------------------------------------------------------------
/// WHY THIS IS THE FULL LIST AND NOT THE OFFICER'S ROUND
/// ---------------------------------------------------------------------
///
/// The screen is titled "Assigned Consumers", but the current backend has no
/// endpoint that returns an officer's assignments. `GET /consumers/officer/
/// {officer_id}` and `ConsumerService.get_officer_consumers` were both removed
/// in this revision, even though the `officer_assignments` table is still in
/// migration 003 and is still seeded.
///
/// So this fetches the paginated full list. That is acceptable for development
/// against four seeded consumers and NOT acceptable in production, where an
/// officer would be scrolling every consumer in Punjab.
///
/// When the endpoint returns, the change is small: take the officer id from
/// the auth state and call `/consumers/officer/$officerId`. The cache, the
/// provider and the screen all stay as they are.
///
/// Offline-first: a network failure falls back to the last cached page rather
/// than throwing, so a field officer without signal still sees their round.
/// A genuine server or auth error still propagates as an [ApiException].
class ApiConsumerRepository implements ConsumerRepository {
  final ApiClient _client;
  final LocalStore _store;
  final ConnectivityService _connectivity;

  ApiConsumerRepository(this._client, this._store, this._connectivity);

  @override
  Future<List<Consumer>> getConsumers({
    int page = 1,
    int pageSize = 50,
  }) async {
    // Serve the cache straight away when there is demonstrably no transport,
    // rather than making a field officer watch a 15s timeout expire first.
    if (!await _connectivity.isOnline()) {
      final cached = _store.getCachedConsumers();
      if (cached.isNotEmpty) return cached;
    }

    try {
      final raw = await _client.get(
        ApiConstants.consumers,
        // Backend clamps page_size to 100 (ConsumerService.get_all_consumers).
        query: {'page': page, 'page_size': pageSize.clamp(1, 100)},
      );

      final consumers = ApiClient.asList(raw).map(Consumer.fromJson).toList();

      // Only overwrite the cache on a genuinely successful fetch, and only
      // for the first page - otherwise paging forward would wipe the cache
      // down to whatever the last page happened to contain.
      if (page == 1) {
        await _store.cacheConsumers(consumers);
      }

      return consumers;
    } on ApiException catch (e) {
      if (e.isNetworkFailure) {
        final cached = _store.getCachedConsumers();
        if (cached.isNotEmpty) return cached;
      }
      rethrow;
    }
  }

  /// POST /consumers/search
  ///
  /// `ConsumerSearchRequest` gained `consumer_number` in this backend
  /// revision. All four fields are optional and are applied as case-insensitive
  /// partial matches (`ilike %value%`).
  Future<List<Consumer>> search({
    String? consumerNumber,
    String? accountNumber,
    String? consumerName,
    String? subdivision,
  }) async {
    final raw = await _client.post(
      ApiConstants.consumersSearch,
      body: {
        'consumer_number': consumerNumber,
        'account_number': accountNumber,
        'consumer_name': consumerName,
        'subdivision': subdivision,
      }..removeWhere((_, v) => v == null || v.trim().isEmpty),
    );

    return ApiClient.asList(raw).map(Consumer.fromJson).toList();
  }

  /// GET /consumers/{id}
  Future<Consumer> getConsumer(String id) async {
    final raw = await _client.get('${ApiConstants.consumers}$id');
    return Consumer.fromJson(ApiClient.asMap(raw));
  }
}

/// Kept for widget tests and for running the UI without a backend.
/// Not wired into `consumerRepositoryProvider`.
class MockConsumerRepository implements ConsumerRepository {
  @override
  Future<List<Consumer>> getConsumers({int page = 1, int pageSize = 50}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return const [
      Consumer(
        id: 'c1',
        consumerNumber: 'PSPCL-C-0001',
        accountNumber: 'ACC-10001',
        consumerName: 'Harpreet Singh',
        address: 'Model Town, Ludhiana, Punjab',
        meterNumber: 'MTR-D-0001',
        meterType: MeterType.digital,
        subdivision: 'Ludhiana Central',
      ),
      Consumer(
        id: 'c2',
        consumerNumber: 'PSPCL-C-0003',
        accountNumber: 'ACC-10003',
        consumerName: 'Gurpreet Singh',
        address: 'Gill Road, Ludhiana, Punjab',
        meterNumber: 'MTR-E-0003',
        meterType: MeterType.electroMechanical,
        subdivision: 'Ludhiana South',
      ),
    ];
  }
}