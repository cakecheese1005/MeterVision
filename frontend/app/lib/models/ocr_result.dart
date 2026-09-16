import '../core/constants.dart';

/// Mirrors `app.models.ocr.OCRResultResponse`.
///
/// Field notes against this backend revision:
///
///  * the timestamp is `processed_at`, NOT `created_at` (it was renamed, and
///    `created_at` never existed as a column on `ocr_results`)
///  * `model_version` and `classification` are both Optional now
///  * `verification_remarks` is new, and carries the audit trail written when
///    a reading is corrected through `PUT /ocr/{ocr_id}/verify`
///  * `predicted_reading` is a STRING on purpose - meter readings are digit
///    sequences and the backend explicitly refuses to store them as floats
///  * `confidence` is `DECIMAL(5,4)`, so it round-trips to 4 decimal places
class OcrResult {
  /// `ocr_results.id` - required by `PUT /ocr/{ocr_id}/verify`.
  final String? id;

  final String? readingId;

  /// `predicted_reading`. Empty when the model could not read the meter.
  final String extractedReading;

  /// 0.0 - 1.0. Null when there was nothing to score.
  final double confidenceScore;

  /// `app.models.enums.OCRStatus`: success | failed | low_confidence | verified
  final String? status;

  final String? modelVersion;

  /// `app.models.enums.AIClassification`, e.g. "Image OK — Digital Meter".
  ///
  /// Held as a raw string and only ever displayed. The exact label text
  /// changed in this backend revision (it now uses an em dash), which cost
  /// nothing here precisely because nothing branches on the value.
  final String? classification;

  final int? processingTimeMs;

  final DateTime? processedAt;

  /// Audit trail from the last correction, if any.
  final String? verificationRemarks;

  /// True when this came from [StubOcrService] rather than the server, so the
  /// UI can be honest that the number is not a real prediction.
  final bool isStub;

  const OcrResult({
    required this.extractedReading,
    required this.confidenceScore,
    this.id,
    this.readingId,
    this.status,
    this.modelVersion,
    this.classification,
    this.processingTimeMs,
    this.processedAt,
    this.verificationRemarks,
    this.isStub = false,
  });

  /// Matches OCR_LOW_CONFIDENCE_THRESHOLD in app/services/ocr_service.py.
  static const double lowConfidenceThreshold = ApiConstants.ocrLowConfidence;

  bool get requiresManualReview => confidenceScore < lowConfidenceThreshold;

  bool get hasReading => extractedReading.trim().isNotEmpty;

  /// The server labelled this `success` (confidence >= 0.70).
  bool get isSuccess => status == 'success';

  /// A human has already corrected this result.
  bool get isVerified => status == 'verified';

  bool get isLowConfidence => status == 'low_confidence';

  /// Confident enough to replace an officer's typed reading unprompted.
  /// See the note on [ApiConstants.ocrAutoApplyConfidence] - this is a much
  /// higher bar than the server's `success` threshold.
  bool get isAutoApplyConfident =>
      hasReading && confidenceScore >= ApiConstants.ocrAutoApplyConfidence;

  /// Numeric comparison where possible, so "012345" and "12345" are the same
  /// reading and a stray space does not read as a disagreement.
  bool matches(String officerReading) {
    final a = extractedReading.trim().replaceAll(',', '');
    final b = officerReading.trim().replaceAll(',', '');

    if (a.isEmpty || b.isEmpty) return false;

    final na = double.tryParse(a);
    final nb = double.tryParse(b);

    if (na != null && nb != null) return na == nb;

    return a == b;
  }

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final raw = json['predicted_reading'] ?? json['extracted_reading'];
    final confidence = json['confidence'] ?? json['confidence_score'];

    return OcrResult(
      id: json['id']?.toString(),
      readingId: json['reading_id']?.toString(),
      extractedReading: raw?.toString() ?? '',
      confidenceScore: (confidence as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString(),
      modelVersion: json['model_version']?.toString(),
      classification: json['classification']?.toString(),
      processingTimeMs: (json['processing_time_ms'] as num?)?.toInt(),
      // `created_at` is accepted as a fallback only so an older deployment
      // does not produce a null timestamp.
      processedAt: DateTime.tryParse(
        (json['processed_at'] ?? json['created_at'])?.toString() ?? '',
      )?.toLocal(),
      verificationRemarks: json['verification_remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reading_id': readingId,
      'predicted_reading': extractedReading,
      'confidence': confidenceScore,
      'status': status,
      'model_version': modelVersion,
      'classification': classification,
      'processing_time_ms': processingTimeMs,
      'processed_at': processedAt?.toUtc().toIso8601String(),
      'verification_remarks': verificationRemarks,
    };
  }
}