import 'dart:math';
import '../models/ocr_result.dart';

/// Contract the UI depends on. A teammate is building the actual OCR model
/// separately (per project handover) — when it's ready, it'll likely be
/// exposed via the backend's 'POST /ocr/process' endpoint. At that point,
/// swap 'StubOcrService' for a real implementation that calls that endpoint
/// with the image; nothing in the UI/provider layer needs to change.
abstract class OcrService {
  Future<OcrResult> extractReading(String imagePath);
}

/// TEMPORARY placeholder so the OCR Verification screen is fully buildable
/// and testable before the real model/endpoint exists.
/// DELETE once the real OcrService implementation is wired in.
class StubOcrService implements OcrService {
  @override
  Future<OcrResult> extractReading(String imagePath) async {
    // Simulates network/inference latency.
    await Future.delayed(const Duration(milliseconds: 900));

    // Fake but plausible reading + confidence so the review UI
    // (badge colors, manual-review banner, editable field) can be tested.
    final fakeReading = (1000 + Random().nextInt(8999)).toString();
    final fakeConfidence = 0.7 + Random().nextDouble() * 0.3;

    return OcrResult(
      extractedReading: fakeReading,
      confidenceScore: double.parse(fakeConfidence.toStringAsFixed(2)),
      processingTimeMs: 900,
    );
  }
}