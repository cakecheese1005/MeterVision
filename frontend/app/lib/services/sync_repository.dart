import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/constants.dart';
import '../core/device/device_identity.dart';
import '../core/local_store.dart';
import '../core/network/connectivity_service.dart';
import '../models/meter_reading_draft.dart';
import 'image_service.dart';
import 'reading_repository.dart';

/// One row of the backend `sync_queue` table
/// (`app.models.sync.SyncQueueResponse`).
class SyncQueueItem {
  final String id;
  final String readingId;
  final String? deviceId;
  final SyncStatus status;
  final int retryCount;
  final DateTime? createdAt;

  const SyncQueueItem({
    required this.id,
    required this.readingId,
    required this.status,
    this.deviceId,
    this.retryCount = 0,
    this.createdAt,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id']?.toString() ?? '',
      readingId: json['reading_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString(),
      status: SyncStatusX.fromWire(json['status']?.toString()),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// Outcome of a full sync pass, for the sync screen to render.
class SyncReport {
  final int attempted;
  final int succeeded;
  final int failed;

  /// Skipped because they are inside their backoff window or dead-lettered.
  final int skipped;

  /// True when the pass stopped early because the device went offline.
  final bool stoppedOffline;

  final List<String> errors;

  const SyncReport({
    this.attempted = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.skipped = 0,
    this.stoppedOffline = false,
    this.errors = const [],
  });

  bool get isClean => failed == 0 && !stoppedOffline;
  bool get didNothing => attempted == 0;

  String get summary {
    if (stoppedOffline) {
      return succeeded > 0
          ? 'Synced $succeeded, then lost connection.'
          : 'No connection.';
    }
    if (didNothing) return 'Nothing to sync.';
    if (failed == 0) return 'Synced $succeeded of $attempted.';
    return 'Synced $succeeded, $failed failed.';
  }
}

/// Drains the local Hive queue into the backend.
///
/// The local queue is the source of truth for *unsent* work; `/sync/pending`
/// reports what the server still considers outstanding. Both are exposed.
///
/// Retry policy:
///   * a draft is attempted at most [ApiConstants.maxSyncRetries] times
///     (5, matching `settings.MAX_SYNC_RETRIES` on the backend)
///   * failures back off exponentially - 1, 2, 4, 8, 16 minutes, capped at 30
///   * once exhausted the draft is dead-lettered: it stops being retried but
///     stays in the box and is surfaced in the UI for manual action, so a
///     capture is never silently discarded
///   * a network failure aborts the whole pass immediately rather than
///     burning every draft's retry budget against a dead connection
class SyncRepository {
  final ApiClient _client;
  final LocalStore _store;
  final ApiReadingRepository _readingRepository;
  final ImageService _imageService;
  final DeviceIdentity _deviceIdentity;
  final ConnectivityService _connectivity;

  SyncRepository(
    this._client,
    this._store,
    this._readingRepository,
    this._imageService,
    this._deviceIdentity,
    this._connectivity,
  );

  // =================================================================
  // Local queue
  // =================================================================

  List<MeterReadingDraft> pendingLocal() => _store.getUnsyncedReadings();

  /// Drafts that have exhausted their retries and need a human.
  List<MeterReadingDraft> deadLettered() =>
      _store.getUnsyncedReadings().where((d) => d.isDeadLettered).toList();

  int get pendingCount => _store.pendingCount;

  Stream<void> watchQueue() => _store.watchPendingReadings();

  /// Puts a dead-lettered draft back in play. Called from the sync screen's
  /// per-item retry button.
  Future<void> resetRetries(String localId) async {
    final draft = _store.getPendingReading(localId);
    if (draft == null) return;

    await _store.upsertPendingReading(
      draft.copyWith(
        syncStatus: SyncStatus.pending,
        retryCount: 0,
        clearLastError: true,
        clearNextAttempt: true,
      ),
    );
  }

  /// Permanently discards a draft. Only reachable through an explicit,
  /// confirmed user action in the sync screen.
  Future<void> discard(String localId) => _store.removePendingReading(localId);

  /// Replays every eligible queued draft.
  ///
  /// Safe to call repeatedly: a draft that already has a `readingId` resumes at
  /// the image-upload step rather than inserting a second `meter_readings` row.
  Future<SyncReport> syncAll() async {
    final now = DateTime.now();
    final queue = _store.getUnsyncedReadings();

    if (queue.isEmpty) return const SyncReport();

    final eligible = queue.where((d) => d.isEligible(now)).toList();
    final skipped = queue.length - eligible.length;

    if (eligible.isEmpty) {
      return SyncReport(skipped: skipped);
    }

    // Pre-flight check. Without it, a sync pass with no signal spends 15s per
    // draft discovering the obvious, and the officer stares at a spinner for
    // the length of the queue.
    if (!await _connectivity.isOnline()) {
      return SyncReport(skipped: queue.length, stoppedOffline: true);
    }

    var succeeded = 0;
    var failed = 0;
    var stoppedOffline = false;
    final errors = <String>[];

    for (final draft in eligible) {
      try {
        await _syncOne(draft);
        succeeded++;
      } on ApiException catch (e) {
        // Offline: not this draft's fault. Leave its retry budget untouched
        // and stop the pass - there is no point hammering a dead connection.
        if (e.isNetworkFailure) {
          stoppedOffline = true;
          break;
        }

        failed++;
        errors.add(e.displayMessage);

        final attempt = draft.retryCount + 1;
        final exhausted = attempt >= ApiConstants.maxSyncRetries;

        await _store.upsertPendingReading(
          draft.copyWith(
            syncStatus: SyncStatus.failed,
            retryCount: attempt,
            lastError: e.displayMessage,
            nextAttemptAt: exhausted
                ? null
                : DateTime.now().add(MeterReadingDraft.backoffFor(attempt)),
          ),
        );
      }
    }

    return SyncReport(
      attempted: eligible.length,
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
      stoppedOffline: stoppedOffline,
      errors: errors,
    );
  }

  Future<void> _syncOne(MeterReadingDraft draft) async {
    var current = draft;

    // Step 1 - create the reading, unless it already exists server-side.
    if (current.readingId == null || current.readingId!.isEmpty) {
      final created = await _readingRepository.createReading(current);

      current = current.copyWith(readingId: created.id);

      // Persist before attempting the upload, so a crash here does not cause
      // a duplicate insert on the next pass.
      await _store.upsertPendingReading(current);
    }

    // Step 2 - upload the photo.
    //
    // ApiImageService throws if the server returns an empty image_id, so
    // reaching the next line means the photo is genuinely stored.
    await _imageService.uploadImage(
      readingId: current.readingId!,
      filePath: current.imagePath,
      latitude: current.latitude ?? 0.0,
      longitude: current.longitude ?? 0.0,
    );

    // Step 3 - both halves are on the server; the draft's work is done.
    if (current.localId != null) {
      await _store.removePendingReading(current.localId!);
    }
  }

  // =================================================================
  // Server-side queue
  // =================================================================

  /// GET /sync/pending
  Future<List<SyncQueueItem>> getServerPending() async {
    final raw = await _client.get(ApiConstants.syncPending);
    return ApiClient.asList(raw).map(SyncQueueItem.fromJson).toList();
  }

  /// POST /sync/mark-synced/{sync_id}
  Future<SyncQueueItem> markSynced(String syncId) async {
    final raw = await _client.post('${ApiConstants.syncMarkSynced}/$syncId');
    return SyncQueueItem.fromJson(ApiClient.asMap(raw));
  }

  /// POST /sync/mark-failed/{sync_id}
  Future<SyncQueueItem> markFailed(String syncId) async {
    final raw = await _client.post('${ApiConstants.syncMarkFailed}/$syncId');
    return SyncQueueItem.fromJson(ApiClient.asMap(raw));
  }

  /// POST /sync/retry-failed
  Future<List<SyncQueueItem>> retryFailed() async {
    final raw = await _client.post(ApiConstants.syncRetryFailed);
    return ApiClient.asList(raw).map(SyncQueueItem.fromJson).toList();
  }

  /// POST /sync/bulk?device_id=... - pushes drafts as `OfflineReading` payloads.
  ///
  /// NOT used by [syncAll], which goes through `/readings/create` so that the
  /// photo can be attached. `/sync/bulk` accepts `image_path` and then never
  /// writes it, so a reading synced this way arrives with no photo and no
  /// record that one was expected.
  ///
  /// Kept for a future server-side catch-up path, and because `device_id`
  /// attribution only exists on this route.
  Future<List<SyncQueueItem>> bulkSync(List<MeterReadingDraft> drafts) async {
    final deviceId = await _deviceIdentity.deviceId();

    final raw = await _client.post(
      ApiConstants.syncBulk,
      query: {'device_id': deviceId},
      body: {
        'readings': drafts.map((d) => d.toOfflineReadingJson()).toList(),
      },
    );

    return ApiClient.asList(raw).map(SyncQueueItem.fromJson).toList();
  }
}