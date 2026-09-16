/// Endpoint paths, verified against `app/main.py` and the routers it mounts.
///
/// Anything listed under "NOT AVAILABLE" is deliberately absent: the route
/// either is not registered in `main.py` or would fail to import. Do not add
/// constants for those until the backend actually exposes them.
class ApiConstants {
  /// Android emulator loopback to the host machine's FastAPI process.
  /// iOS simulator / desktop: use http://127.0.0.1:8000
  /// Physical device: use your machine's LAN IP, e.g. http://192.168.1.20:8000
  ///
  /// Override at build time without touching source:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
  ///
  /// NOTE: plain HTTP is only permitted for the hosts whitelisted in
  /// android/app/src/main/res/xml/network_security_config.xml
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  // ---------------------------------------------------------------
  // Auth  (app/routers/auth.py - mounted)
  // ---------------------------------------------------------------

  /// Wrapped in APIResponse -> unwrap to LoginData.
  static const String login = '/auth/login';

  /// Wrapped in APIResponse -> unwrap to UserProfile.
  static const String me = '/auth/me';

  /// Wrapped in APIResponse -> unwrap to RefreshSessionData.
  /// Rotates BOTH tokens, so both must be written back.
  static const String authRefresh = '/auth/refresh';

  /// Server-side no-op (JWTs are stateless and there is no blacklist table).
  /// Clearing local storage is what actually ends the session.
  static const String authLogout = '/auth/logout';

  static const String authRegister = '/auth/register';

  // ---------------------------------------------------------------
  // Consumers  (app/routers/consumer.py - mounted)
  //
  // Returns a BARE list[ConsumerResponse], not the APIResponse envelope.
  // ---------------------------------------------------------------

  static const String consumers = '/consumers/';
  static const String consumersSearch = '/consumers/search';

  // ---------------------------------------------------------------
  // Readings  (app/routers/readings.py - mounted)
  //
  // Bare ReadingResponse / list[ReadingResponse].
  // ---------------------------------------------------------------

  /// 201 + bare ReadingResponse. officer_id is taken from the JWT.
  static const String readingsCreate = '/readings/create';
  static const String readingsList = '/readings/';

  // ---------------------------------------------------------------
  // Images  (app/routers/images.py - mounted)
  //
  // multipart/form-data. All four fields are Form(...)-required:
  //   reading_id, latitude, longitude, file
  // Declares response_model=ImageUploadResponse.
  // ---------------------------------------------------------------

  static const String imagesUpload = '/images/upload';

  // ---------------------------------------------------------------
  // Sync  (app/routers/sync.py - mounted)
  //
  // `device_id` is a QUERY parameter on POST / and POST /bulk.
  // ---------------------------------------------------------------

  static const String syncRoot = '/sync/';
  static const String syncBulk = '/sync/bulk';
  static const String syncPending = '/sync/pending';
  static const String syncRetryFailed = '/sync/retry-failed';
  static const String syncMarkSynced = '/sync/mark-synced';
  static const String syncMarkFailed = '/sync/mark-failed';

  // ---------------------------------------------------------------
  // OCR  (app/routers/ocr.py - MOUNTED as of this backend revision)
  //
  // All four require a JWT. Keyed on image_id / ocr_id / reading_id, so
  // server OCR can only run AFTER the reading and its image exist.
  // ---------------------------------------------------------------

  /// POST /ocr/process/{image_id} -> OCRResultResponse
  /// Upserts on reading_id, so it is safe to call more than once.
  static const String ocrProcess = '/ocr/process';

  /// PUT /ocr/{ocr_id}/verify -> OCRResultResponse
  /// Body: {corrected_reading (1..30 chars), remarks (<=500 chars)}
  /// Also rewrites meter_readings.reading_value and units_consumed.
  static const String ocrRoot = '/ocr';

  static const String health = '/health';

  // ---------------------------------------------------------------
  // NOT AVAILABLE - do not call
  // ---------------------------------------------------------------
  //
  //  /consumers/officer/{officer_id}
  //                REMOVED from consumer.py in this backend revision, along
  //                with ConsumerService.get_officer_consumers. There is
  //                currently NO endpoint that returns an officer's assigned
  //                round, so the app falls back to the paginated full list.
  //                The officer_assignments table still exists (migration 003).
  //
  //  bills / tariffs
  //                No table, no model, no route anywhere in the backend.
  //                Provisional bill calculation cannot be implemented yet.

  /// Client-side ceiling on sync attempts.
  /// Mirrors `settings.MAX_SYNC_RETRIES` in app/core/config.py.
  static const int maxSyncRetries = 5;

  /// Backend rejects anything larger (`settings.MAX_IMAGE_SIZE_MB`).
  static const int maxImageSizeMb = 10;

  /// Server-side cutoff between OCRStatus.success and low_confidence.
  /// Mirrors OCR_LOW_CONFIDENCE_THRESHOLD in app/services/ocr_service.py.
  static const double ocrLowConfidence = 0.70;

  /// Confidence required before the app will REPLACE an officer's typed
  /// reading with the model's, without asking.
  ///
  /// Deliberately far above [ocrLowConfidence]. 0.70 only means the server
  /// labels the result `success`; it is nowhere near enough certainty to
  /// overwrite a number a human read off a physical meter for billing.
  /// Anything below this is shown side by side and the officer's value stands.
  ///
  /// Every auto-apply is reversible from the confirmation dialog and leaves an
  /// audit trail in ocr_results.verification_remarks.
  static const double ocrAutoApplyConfidence = 0.95;
}

// =====================================================================
// Enums
//
// Dart names stay camelCase for the UI; `wireValue` is the exact string
// the FastAPI/Supabase layer expects. Never send `.name` over the wire.
//
// All verified against app/models/enums.py.
// =====================================================================

/// `app.models.enums.MeterType`
enum MeterType { electroMechanical, digital }

extension MeterTypeX on MeterType {
  String get wireValue {
    switch (this) {
      case MeterType.digital:
        return 'digital';
      case MeterType.electroMechanical:
        return 'electromechanical';
    }
  }

  String get label {
    switch (this) {
      case MeterType.digital:
        return 'Digital';
      case MeterType.electroMechanical:
        return 'Electro-Mechanical';
    }
  }

  static MeterType? fromWire(String? value) {
    switch (value) {
      case 'digital':
        return MeterType.digital;
      case 'electromechanical':
        return MeterType.electroMechanical;
      default:
        return null;
    }
  }
}

/// `app.models.enums.ReadingStatus`
enum ReadingStatus { pending, completed, review, rejected }

extension ReadingStatusX on ReadingStatus {
  String get wireValue => name;

  String get label {
    switch (this) {
      case ReadingStatus.pending:
        return 'Pending';
      case ReadingStatus.completed:
        return 'Completed';
      case ReadingStatus.review:
        return 'Needs Review';
      case ReadingStatus.rejected:
        return 'Rejected';
    }
  }

  static ReadingStatus fromWire(String? value) {
    switch (value) {
      case 'completed':
        return ReadingStatus.completed;
      case 'review':
        return ReadingStatus.review;
      case 'rejected':
        return ReadingStatus.rejected;
      case 'pending':
      default:
        return ReadingStatus.pending;
    }
  }
}

/// `app.models.enums.SyncStatus` - note `success`, not `synced`.
enum SyncStatus { pending, success, failed }

extension SyncStatusX on SyncStatus {
  String get wireValue => name;

  String get label {
    switch (this) {
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.failed:
        return 'Failed';
    }
  }

  static SyncStatus fromWire(String? value) {
    switch (value) {
      case 'success':
        return SyncStatus.success;
      case 'failed':
        return SyncStatus.failed;
      case 'pending':
      default:
        return SyncStatus.pending;
    }
  }
}

/// `app.models.enums.UserRole`
enum UserRole { admin, officer, lcr }

extension UserRoleX on UserRole {
  String get wireValue => name;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin Officer';
      case UserRole.lcr:
        return 'LCR Verification';
      case UserRole.officer:
        return 'Field Officer';
    }
  }

  static UserRole fromWire(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'lcr':
        return UserRole.lcr;
      case 'officer':
      default:
        return UserRole.officer;
    }
  }
}

/// `app.models.enums.ImageQuality` - the verdict returned by the backend's
/// blur/relevance check on `POST /images/upload`.
///
/// The backend currently hardcodes `ok` (the blur/YOLO pipeline is not wired
/// up yet), so [ImageQualityX.needsRecapture] will not fire in practice until
/// it is. The handling path exists so that it works the day it does.
enum ImageQuality { ok, blur, reflection, irrelevant }

extension ImageQualityX on ImageQuality {
  String get wireValue => name;

  bool get needsRecapture => this != ImageQuality.ok;

  String get label {
    switch (this) {
      case ImageQuality.ok:
        return 'Image looks good';
      case ImageQuality.blur:
        return 'Image is blurred';
      case ImageQuality.reflection:
        return 'Glare or reflection on the meter';
      case ImageQuality.irrelevant:
        return 'This does not look like a meter';
    }
  }

  static ImageQuality? fromWire(String? value) {
    switch (value) {
      case 'ok':
        return ImageQuality.ok;
      case 'blur':
        return ImageQuality.blur;
      case 'reflection':
        return ImageQuality.reflection;
      case 'irrelevant':
        return ImageQuality.irrelevant;
      default:
        return null;
    }
  }
}

class HiveBoxes {
  static const String pendingReadings = 'pending_readings';
  static const String consumersCache = 'consumers_cache';
  static const String authBox = 'auth_box';
}