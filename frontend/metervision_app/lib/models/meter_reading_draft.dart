import '../core/constants.dart';

/// A confirmed meter reading, ready to be saved locally before sync.
/// Mirrors the 'meter_readings' table shape on the backend, minus fields
/// (id, reader_id, status) that only get set once it's actually synced.
class MeterReadingDraft {
  final String consumerId;
  final String imagePath;
  final String meterReading;
  final MeterType meterType;
  final double? ocrConfidence;
  final DateTime capturedAt;

  const MeterReadingDraft({
    required this.consumerId,
    required this.imagePath,
    required this.meterReading,
    required this.meterType,
    required this.capturedAt,
    this.ocrConfidence,
  });
}