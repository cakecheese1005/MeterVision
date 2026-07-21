class ApiConstants {
  // TODO: point to your real FastAPI backend once it's deployed/running locally
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator -> localhost
  // static const String baseUrl = 'https://your-backend.example.com';

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String consumers = '/consumers';
  static const String readingsCreate = '/readings/create';
  static const String readingsList = '/readings/';
  static const String imagesUpload = '/images/upload';
  static const String syncPending = '/sync/pending';
  static const String syncMarkSynced = '/sync/mark-synced';
  static const String lcrCases = '/lcr/all';
}

enum MeterType { electroMechanical, digital }

enum ReadingStatus { pending, verified, flagged, rejected, assignedLcr }

enum SyncStatus { pending, synced, failed }

class HiveBoxes {
  static const String pendingReadings = 'pending_readings';
  static const String consumersCache = 'consumers_cache';
  static const String authBox = 'auth_box';
}
