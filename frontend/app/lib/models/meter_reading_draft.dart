import '../core/constants.dart';

/// A reading captured in the field, before (or while) it reaches the backend.
///
/// This is the unit of work for the offline queue: it is what gets written to
/// the Hive `pending_readings` box and later replayed against
/// `POST /readings/create` followed by `POST /images/upload`.
///
/// ---------------------------------------------------------------------
/// FIELDS THE BACKEND DOES NOT ACCEPT (kept local, deliberately)
/// ---------------------------------------------------------------------
///
/// `app.models.reading.ReadingCreate` is exactly:
///
///     consumer_id, reading_value, latitude, longitude, captured_at
///
/// So the following are stored on the device and NEVER sent:
///
///   * [meterType]      - no column on `meter_readings`. The `consumers` table
///                        already carries meter_type, so the server can derive
///                        it. Retained locally for the officer's own record and
///                        so it is ready the day ReadingCreate gains the field.
///   * [ocrConfidence]  - belongs in the `ocr_results` table, which is reached
///                        through `/ocr/*`. That router is not mounted, so
///                        there is nowhere to put it yet.
///
/// `officer_id` is likewise absent: the backend derives it from the JWT
/// (`current_user["sub"]`), so the client must never send it.
class MeterReadingDraft {
  /// Client-side id used to de-duplicate the offline queue.
  ///
  /// NOT an idempotency key as far as the server is concerned: `sync_queue`
  /// has no `local_id` column and `SyncService.sync_reading` ignores the one
  /// on `OfflineReading`. Until that changes, duplicate protection is
  /// best-effort and lives entirely in [readingId] resume logic below.
  final String? localId;

  final String consumerId;
  final String imagePath;
  final String meterReading;

  /// Local only - see the class doc.
  final MeterType meterType;

  /// Local only - see the class doc.
  final double? ocrConfidence;

  final DateTime capturedAt;

  /// GPS at capture time.
  ///
  /// `ReadingCreate.latitude/longitude` are non-optional floats on the
  /// backend, so a missing fix has to be serialised as 0.0. [locationAvailable]
  /// records whether that 0.0 is a real coordinate or a placeholder, so the UI
  /// can warn and so nobody later mistakes a null island reading for a real
  /// one off the coast of Africa.
  final double? latitude;
  final double? longitude;
  final bool locationAvailable;

  /// Set once `POST /readings/create` has accepted the reading.
  ///
  /// Its presence is what makes a retry resume at the image-upload step
  /// instead of inserting a second `meter_readings` row.
  final String? readingId;

  /// Set once `POST /images/upload` has returned a real `image_id`.
  final String? imageId;

  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;

  /// Earliest time the sync pass may try this draft again (exponential
  /// backoff). Null means "eligible now".
  final DateTime? nextAttemptAt;

  const MeterReadingDraft({
    required this.consumerId,
    required this.imagePath,
    required this.meterReading,
    required this.meterType,
    required this.capturedAt,
    this.localId,
    this.ocrConfidence,
    this.latitude,
    this.longitude,
    this.locationAvailable = false,
    this.readingId,
    this.imageId,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    this.nextAttemptAt,
  });

  /// Numeric value the backend expects for `reading_value` (a float).
  double get readingValue =>
      double.tryParse(meterReading.trim().replaceAll(',', '')) ?? 0.0;

  /// True once the reading row exists server-side, so only the photo is left.
  bool get awaitingImageOnly =>
      readingId != null && readingId!.isNotEmpty && imageId == null;

  /// Fully delivered - both the reading and its photo are on the server.
  bool get isComplete =>
      readingId != null &&
      readingId!.isNotEmpty &&
      imageId != null &&
      imageId!.isNotEmpty;

  /// Exhausted its retry budget. Stays in the queue for manual intervention
  /// rather than being retried forever or silently dropped.
  bool get isDeadLettered =>
      syncStatus == SyncStatus.failed &&
      retryCount >= ApiConstants.maxSyncRetries;

  /// Whether the sync pass is allowed to attempt this draft right now.
  bool isEligible(DateTime now) {
    if (isDeadLettered) return false;
    final next = nextAttemptAt;
    return next == null || !now.isBefore(next);
  }

  /// Exponential backoff: 1, 2, 4, 8, 16 minutes, capped at 30.
  static Duration backoffFor(int retryCount) {
    final minutes = 1 << retryCount.clamp(0, 5);
    return Duration(minutes: minutes > 30 ? 30 : minutes);
  }

  // -----------------------------------------------------------------
  // Wire format - POST /readings/create  (app.models.reading.ReadingCreate)
  // -----------------------------------------------------------------

  Map<String, dynamic> toCreateJson() {
    return {
      'consumer_id': consumerId,
      'reading_value': readingValue,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }

  /// Wire format for `POST /sync/` and `/sync/bulk`
  /// (app.models.sync.OfflineReading).
  ///
  /// NOTE: the server reads `image_path` into a local variable and never
  /// writes it, so the binary still has to go through `POST /images/upload`
  /// separately. The app's primary path uses `/readings/create` instead;
  /// this exists for completeness and for bulk catch-up.
  Map<String, dynamic> toOfflineReadingJson() {
    return {
      'local_id': localId ?? '',
      'consumer_id': consumerId,
      'reading_value': readingValue,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'image_path': imagePath,
    };
  }

  // -----------------------------------------------------------------
  // Local persistence (Hive) - every field, including client-only ones
  // -----------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'consumer_id': consumerId,
      'image_path': imagePath,
      'meter_reading': meterReading,
      'meter_type': meterType.wireValue,
      'ocr_confidence': ocrConfidence,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_available': locationAvailable,
      'reading_id': readingId,
      'image_id': imageId,
      'sync_status': syncStatus.wireValue,
      'retry_count': retryCount,
      'last_error': lastError,
      'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
    };
  }

  factory MeterReadingDraft.fromJson(Map<String, dynamic> json) {
    return MeterReadingDraft(
      localId: json['local_id']?.toString(),
      consumerId: json['consumer_id']?.toString() ?? '',
      imagePath: json['image_path']?.toString() ?? '',
      meterReading: json['meter_reading']?.toString() ?? '',
      meterType: MeterTypeX.fromWire(json['meter_type']?.toString()) ??
          MeterType.digital,
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      capturedAt:
          DateTime.tryParse(json['captured_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAvailable: json['location_available'] == true,
      readingId: json['reading_id']?.toString(),
      imageId: json['image_id']?.toString(),
      syncStatus: SyncStatusX.fromWire(json['sync_status']?.toString()),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
      nextAttemptAt:
          DateTime.tryParse(json['next_attempt_at']?.toString() ?? '')
              ?.toLocal(),
    );
  }

  /// Note the sentinel booleans: `copyWith` cannot otherwise distinguish
  /// "leave this alone" from "set this back to null", and both
  /// [nextAttemptAt] and [lastError] genuinely need clearing on success.
  MeterReadingDraft copyWith({
    String? localId,
    String? consumerId,
    String? imagePath,
    String? meterReading,
    MeterType? meterType,
    double? ocrConfidence,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    bool? locationAvailable,
    String? readingId,
    String? imageId,
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    DateTime? nextAttemptAt,
    bool clearLastError = false,
    bool clearNextAttempt = false,
  }) {
    return MeterReadingDraft(
      localId: localId ?? this.localId,
      consumerId: consumerId ?? this.consumerId,
      imagePath: imagePath ?? this.imagePath,
      meterReading: meterReading ?? this.meterReading,
      meterType: meterType ?? this.meterType,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      capturedAt: capturedAt ?? this.capturedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAvailable: locationAvailable ?? this.locationAvailable,
      readingId: readingId ?? this.readingId,
      imageId: imageId ?? this.imageId,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextAttemptAt:
          clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
    );
  }
}
