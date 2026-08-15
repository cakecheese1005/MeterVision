import '../core/constants.dart';

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