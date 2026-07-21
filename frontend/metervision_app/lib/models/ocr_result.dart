/// Result of running OCR on a captured meter image.
/// Mirrors the shape of the backend's 'ocr_results' table
/// (minus 'id'/'meter_reading_id', which only exist after the reading
/// is actually submitted to the backend).
class OcrResult {
  final String extractedReading;
  final double confidenceScore; // 0.0 - 1.0
  final int? processingTimeMs;

  const OcrResult({
    required this.extractedReading,
    required this.confidenceScore,
    this.processingTimeMs,
  });

  /// Threshold matches the backend rule: confidence < 0.80 -> flag for review.
  bool get requiresManualReview => confidenceScore < 0.80;
}