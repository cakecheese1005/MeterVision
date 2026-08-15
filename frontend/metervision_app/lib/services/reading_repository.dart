import '../models/meter_reading_draft.dart';

abstract class ReadingRepository {
  Future<void> submitReading(MeterReadingDraft draft);
}

/// TEMPORARY in-memory stub — replace with Hive-backed pending_readings box.
class InMemoryReadingRepository implements ReadingRepository {
  final List<MeterReadingDraft> _pending = [];

  @override
  Future<void> submitReading(MeterReadingDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _pending.add(draft);
  }
}