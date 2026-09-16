import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/constants.dart';
import '../core/local_store.dart';
import '../core/network/connectivity_service.dart';
import '../models/meter_reading_draft.dart';
import 'image_service.dart';

/// Result of `POST /readings/create` (`app.models.reading.ReadingResponse`).
///
/// Backend fields: id, consumer_id, officer_id, reading_value,
/// previous_reading?, units_consumed?, status, created_at
///
/// `previous_reading` comes from `consumers.previous_reading` and
/// `units_consumed` is computed server-side as
/// `max(0, reading_value - previous_reading)`.
class SubmittedReading {
  final String id;
  final String consumerId;
  final String officerId;
  final double readingValue;
  final double? previousReading;
  final double? unitsConsumed;
  final ReadingStatus status;
  final DateTime? createdAt;

  const SubmittedReading({
    required this.id,
    required this.consumerId,
    required this.officerId,
    required this.readingValue,
    required this.status,
    this.previousReading,
    this.unitsConsumed,
    this.createdAt,
  });

  bool get hasUnits => unitsConsumed != null;

  factory SubmittedReading.fromJson(Map<String, dynamic> json) {
    return SubmittedReading(
      id: json['id']?.toString() ?? '',
      consumerId: json['consumer_id']?.toString() ?? '',
      officerId: json['officer_id']?.toString() ?? '',
      readingValue: (json['reading_value'] as num?)?.toDouble() ?? 0.0,
      previousReading: (json['previous_reading'] as num?)?.toDouble(),
      unitsConsumed: (json['units_consumed'] as num?)?.toDouble(),
      status: ReadingStatusX.fromWire(
        (json['status'] ?? json['reading_status'])?.toString(),
      ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// What actually happened when the officer pressed Submit.
///
/// Returning this instead of `void` is what lets the confirmation screen show
/// units consumed, flag a poor-quality photo, or say plainly that the reading
/// is queued for later. Previously all of that was parsed and discarded.
class SubmitOutcome {
  /// Null when the device was offline and the reading was queued instead.
  final SubmittedReading? reading;

  /// Null when the photo has not been uploaded yet.
  final UploadedImage? image;

  /// True when nothing reached the server and the draft is sitting in Hive.
  final bool queuedOffline;

  /// True when the reading was created but the photo still needs to go up.
  final bool imagePending;

  const SubmitOutcome({
    this.reading,
    this.image,
    this.queuedOffline = false,
    this.imagePending = false,
  });

  bool get isFullySynced =>
      reading != null && image != null && !queuedOffline && !imagePending;

  /// The backend's blur/relevance verdict asked for a retake.
  bool get needsRecapture => image?.needsRecapture ?? false;

  String get headline {
    if (queuedOffline) return 'Saved offline';
    if (imagePending) return 'Reading submitted';
    return 'Reading submitted';
  }

  String get detail {
    if (queuedOffline) {
      return 'No connection. The reading and photo are stored on this device '
          'and will sync automatically.';
    }
    if (imagePending) {
      return 'The reading was accepted. The photo will upload on the next sync.';
    }
    return 'The reading and photo were accepted by the server.';
  }
}

abstract class ReadingRepository {
  Future<SubmitOutcome> submitReading(MeterReadingDraft draft);
}

/// Offline-first submission.
///
/// Every draft is written to the Hive queue *first*, then pushed. If the push
/// fails for connectivity reasons the draft stays queued and [SyncRepository]
/// retries it later - the officer is never blocked and no capture is lost.
/// Auth and validation errors are surfaced immediately, because retrying those
/// would just fail forever.
///
/// Ordering note: the reading row is created before the photo is uploaded, and
/// that is not arbitrary. `meter_images.reading_id` is
/// `NOT NULL REFERENCES meter_readings(id)`, so the photo is structurally
/// unable to exist before the reading does.
///
/// `officer_id` is never sent: the backend reads it from the JWT.
class ApiReadingRepository implements ReadingRepository {
  final ApiClient _client;
  final LocalStore _store;
  final ImageService _imageService;
  final ConnectivityService _connectivity;
  final Uuid _uuid;

  ApiReadingRepository(
    this._client,
    this._store,
    this._imageService,
    this._connectivity, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<SubmitOutcome> submitReading(MeterReadingDraft draft) async {
    final queued =
        draft.localId == null ? draft.copyWith(localId: _uuid.v4()) : draft;

    // 1. Persist locally before anything else touches the network.
    await _store.upsertPendingReading(queued);

    // 2. Pre-flight connectivity check.
    //
    // Without this, submitting with no signal means waiting out the 15s
    // connect timeout before the officer is told the reading was queued -
    // and on the Android emulator it means the reading is NOT queued at all,
    // because `10.0.2.2` is the emulator's virtual router alias for the host
    // loopback and stays reachable in airplane mode. The radio is off, the
    // request still succeeds, and offline behaviour never gets exercised.
    //
    // Asking the platform whether a transport exists is instant and honest.
    // It is only used to short-circuit the definitely-offline case; a captive
    // portal or a connected-but-dead Wi-Fi still falls through to the request
    // and is caught below.
    if (!await _connectivity.isOnline()) {
      await _store.upsertPendingReading(
        queued.copyWith(
          syncStatus: SyncStatus.pending,
          lastError: 'Captured while offline. Waiting for a connection.',
        ),
      );
      return const SubmitOutcome(queuedOffline: true);
    }

    SubmittedReading reading;

    try {
      // 3. Create the reading row.
      reading = await createReading(queued);
    } on ApiException catch (e) {
      if (e.isNetworkFailure) {
        // Stays queued as pending; SyncRepository will replay it.
        await _store.upsertPendingReading(
          queued.copyWith(
            syncStatus: SyncStatus.pending,
            lastError: e.displayMessage,
          ),
        );
        return const SubmitOutcome(queuedOffline: true);
      }

      await _store.upsertPendingReading(
        queued.copyWith(
          syncStatus: SyncStatus.failed,
          retryCount: queued.retryCount + 1,
          lastError: e.displayMessage,
          nextAttemptAt:
              DateTime.now().add(MeterReadingDraft.backoffFor(queued.retryCount)),
        ),
      );
      rethrow;
    }

    // Record the server id immediately. If the process dies right here, the
    // next sync pass resumes at the image step instead of creating a second
    // meter_readings row.
    final withReadingId = queued.copyWith(readingId: reading.id);
    await _store.upsertPendingReading(withReadingId);

    // 4. Attach the photo. A failure here must not lose the reading, so it is
    //    tolerated and retried by the sync pass.
    try {
      final image = await _imageService.uploadImage(
        readingId: reading.id,
        filePath: withReadingId.imagePath,
        latitude: withReadingId.latitude ?? 0.0,
        longitude: withReadingId.longitude ?? 0.0,
      );

      // 5. Fully delivered - drop it from the queue.
      await _store.removePendingReading(withReadingId.localId!);

      return SubmitOutcome(reading: reading, image: image);
    } on ApiException catch (e) {
      await _store.upsertPendingReading(
        withReadingId.copyWith(
          syncStatus: SyncStatus.pending,
          lastError: 'Reading saved. Photo upload pending: ${e.displayMessage}',
        ),
      );

      return SubmitOutcome(reading: reading, imagePending: true);
    }
  }

  /// POST /readings/create -> 201 + bare ReadingResponse
  Future<SubmittedReading> createReading(MeterReadingDraft draft) async {
    final raw = await _client.post(
      ApiConstants.readingsCreate,
      body: draft.toCreateJson(),
    );

    return SubmittedReading.fromJson(ApiClient.asMap(raw));
  }

  /// GET /readings/ - filters map onto ReadingFilter.
  ///
  /// Note: this route has no auth dependency on the backend, and `status` /
  /// `from_date` are declared untyped, so an unexpected value reaches
  /// ReadingFilter and raises an unhandled ValidationError. Only send values
  /// from the enum.
  Future<List<SubmittedReading>> listReadings({
    ReadingStatus? status,
    String? officerId,
    String? subdivision,
  }) async {
    final raw = await _client.get(
      ApiConstants.readingsList,
      query: {
        // `status` keeps the `if` because the value is a computed expression,
        // not the nullable variable itself.
        if (status != null) 'status': status.wireValue,
        'officer_id': ?officerId,
        'subdivision': ?subdivision,
      },
    );

    return ApiClient.asList(raw).map(SubmittedReading.fromJson).toList();
  }
}

/// Retained for widget tests only.
class InMemoryReadingRepository implements ReadingRepository {
  final List<MeterReadingDraft> _pending = [];

  List<MeterReadingDraft> get pending => List.unmodifiable(_pending);

  @override
  Future<SubmitOutcome> submitReading(MeterReadingDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _pending.add(draft);
    return const SubmitOutcome(queuedOffline: true);
  }
}