import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/meter_reading_draft.dart';
import '../services/reading_repository.dart';
import '../services/sync_repository.dart';
import 'core_providers.dart';
import 'reading_provider.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final store = ref.watch(localStoreProvider);
  final imageService = ref.watch(imageServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  return SyncRepository(
    client,
    store,
    ApiReadingRepository(client, store, imageService, connectivity),
    imageService,
    ref.watch(deviceIdentityProvider),
    connectivity,
  );
});

/// Emits the CURRENT connectivity state immediately, then every change.
///
/// This matters at launch: `onConnectivityChanged` alone only fires on
/// transitions, so an app that starts online and stays online would never
/// learn that it is online.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).stream;
});

class SyncState {
  final bool isSyncing;
  final List<MeterReadingDraft> pending;
  final SyncReport? lastReport;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  const SyncState({
    this.isSyncing = false,
    this.pending = const [],
    this.lastReport,
    this.errorMessage,
    this.lastSyncedAt,
  });

  int get pendingCount => pending.length;
  bool get hasPending => pending.isNotEmpty;

  /// Drafts that have exhausted their retry budget and need manual action.
  List<MeterReadingDraft> get deadLettered =>
      pending.where((d) => d.isDeadLettered).toList();

  /// Drafts still being retried automatically.
  List<MeterReadingDraft> get active =>
      pending.where((d) => !d.isDeadLettered).toList();

  bool get hasDeadLettered => deadLettered.isNotEmpty;

  SyncState copyWith({
    bool? isSyncing,
    List<MeterReadingDraft>? pending,
    SyncReport? lastReport,
    String? errorMessage,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pending: pending ?? this.pending,
      lastReport: lastReport ?? this.lastReport,
      // Deliberately not `??` - passing null clears the error.
      errorMessage: errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncRepository _repository;
  StreamSubscription<void>? _queueSubscription;

  SyncNotifier(this._repository) : super(const SyncState()) {
    refreshQueue();
    _queueSubscription = _repository.watchQueue().listen((_) => refreshQueue());
  }

  void refreshQueue() {
    if (!mounted) return;
    state = state.copyWith(pending: _repository.pendingLocal());
  }

  /// Drains the local queue. Re-entrant calls are ignored so a connectivity
  /// event during a manual sync cannot start a second pass.
  Future<void> syncNow() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final report = await _repository.syncAll();

      if (!mounted) return;

      state = state.copyWith(
        isSyncing: false,
        pending: _repository.pendingLocal(),
        lastReport: report,
        lastSyncedAt: DateTime.now(),
        errorMessage: report.isClean ? null : report.summary,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isSyncing: false,
        pending: _repository.pendingLocal(),
        errorMessage: e.displayMessage,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isSyncing: false,
        pending: _repository.pendingLocal(),
        errorMessage: 'Sync failed unexpectedly.',
      );
    }
  }

  /// Puts a dead-lettered draft back in the automatic retry rotation.
  Future<void> retryItem(String localId) async {
    await _repository.resetRetries(localId);
    refreshQueue();
    await syncNow();
  }

  /// Permanently discards a draft. Destructive - the UI must confirm first.
  Future<void> discardItem(String localId) async {
    await _repository.discard(localId);
    refreshQueue();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final notifier = SyncNotifier(ref.watch(syncRepositoryProvider));

  // ---------------------------------------------------------------
  // Auto-drain the queue as soon as the device comes back online.
  //
  // `ref.listen` inside a provider body only runs while the provider is
  // alive, and a provider is only alive while something is watching it.
  // This one is kept alive by `SyncBootstrap` at the root of the widget
  // tree - see main.dart. Without that, none of this ever runs.
  // ---------------------------------------------------------------
  ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
    final wasOnline = previous?.valueOrNull ?? false;
    final isOnline = next.valueOrNull ?? false;

    if (!wasOnline && isOnline) {
      notifier.syncNow();
    }
  });

  return notifier;
});

/// GET /sync/pending - what the *server* still considers outstanding.
///
/// Distinct from the local queue, which is what has not been sent yet. Note
/// that rows only appear here for readings pushed through `/sync/*`; the app's
/// primary path is `/readings/create`, which does not write to `sync_queue`.
/// Kept as a binding for the endpoint rather than surfaced in the UI, where it
/// would currently always read as empty and mislead.
final serverPendingSyncProvider =
    FutureProvider.autoDispose<List<SyncQueueItem>>((ref) async {
  return ref.watch(syncRepositoryProvider).getServerPending();
});