import '../models/meter_reading_draft.dart';

/// Contract the UI/providers depend on. Real implementation should write to
/// the Hive box 'HiveBoxes.pendingReadings' (see core/constants.dart) as a
/// 'pending_readings' entry, which the (future) SyncService then uploads to
/// POST /readings/create + POST /images/upload once connectivity is back.
abstract class ReadingRepository {
  Future<void> submitReading(MeterReadingDraft draft);
}

/// TEMPORARY in-memory stub so this screen is fully testable before the
/// Hive-backed offline storage layer exists. Nothing survives an app
/// restart with this implementation — that's expected and fine for now.
/// DELETE once the real Hive-backed repository is wired in.
class InMemoryReadingRepository implements ReadingRepository {
  final List<MeterReadingDraft> _pending = [];

  @override
  Future<void> submitReading(MeterReadingDraft draft) async {
    // Simulates local DB write latency.
    await Future.delayed(const Duration(milliseconds: 400));
    _pending.add(draft);
  }
}