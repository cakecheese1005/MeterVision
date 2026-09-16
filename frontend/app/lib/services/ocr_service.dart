import 'dart:math';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/ocr_result.dart';

/// Server-side OCR, live as of this backend revision.
///
/// `app/routers/ocr.py` is now registered in `app/main.py` and migration 006
/// has the columns the service writes, so these endpoints work.
///
/// ---------------------------------------------------------------------
/// ORDERING CONSTRAINT - why this is not the pre-submit OCR
/// ---------------------------------------------------------------------
///
/// Every endpoint is keyed on `image_id`, `ocr_id` or `reading_id`:
///
///   ocr_results.reading_id  NOT NULL UNIQUE -> meter_readings(id)
///   meter_images.reading_id NOT NULL        -> meter_readings(id)
///
/// So an image cannot exist before its reading does, and an OCR result cannot
/// exist before its image does. Server OCR is therefore structurally unable to
/// run before the officer submits.
///
/// That is why the capture flow still uses [StubOcrService] for the reading
/// the officer reviews, and this class runs afterwards as verification.
abstract class OcrService {
  /// Runs the AI pipeline over an already-uploaded image.
  Future<OcrResult> processImage(String imageId);

  /// Fetches the stored result for a reading, if one exists.
  Future<OcrResult> resultForReading(String readingId);

  /// Records a corrected reading.
  Future<OcrResult> verifyResult({
    required String ocrId,
    required String correctedReading,
    String? remarks,
  });
}

class ApiOcrService implements OcrService {
  final ApiClient _client;

  ApiOcrService(this._client);

  /// POST /ocr/process/{image_id}
  ///
  /// Upserts on `reading_id`, so calling it twice for the same reading updates
  /// the existing row rather than colliding with the UNIQUE constraint. Safe
  /// to retry.
  @override
  Future<OcrResult> processImage(String imageId) async {
    final raw = await _client.post(
      '${ApiConstants.ocrProcess}/$imageId',
      // EasyOCR plus a MobileNet digit pass, on CPU, over a downloaded image.
      // The 30s client default is not enough on modest hardware.
      receiveTimeout: const Duration(minutes: 2),
    );

    return OcrResult.fromJson(ApiClient.asMap(raw));
  }

  /// GET /ocr/{reading_id} - 404s when the pipeline has not run yet.
  @override
  Future<OcrResult> resultForReading(String readingId) async {
    final raw = await _client.get('${ApiConstants.ocrRoot}/$readingId');
    return OcrResult.fromJson(ApiClient.asMap(raw));
  }

  /// PUT /ocr/{ocr_id}/verify
  ///
  /// Sets status to `verified`, stores [remarks] in
  /// `ocr_results.verification_remarks`, and - importantly - also rewrites
  /// `meter_readings.reading_value` and recomputes `units_consumed`. It is the
  /// only endpoint that accepts a corrected reading, since `ReadingCreate`
  /// still has no field for one.
  ///
  /// Backend constraints: corrected_reading is 1..30 chars, remarks <= 500.
  @override
  Future<OcrResult> verifyResult({
    required String ocrId,
    required String correctedReading,
    String? remarks,
  }) async {
    final trimmed = correctedReading.trim();

    final raw = await _client.put(
      '${ApiConstants.ocrRoot}/$ocrId/verify',
      body: {
        'corrected_reading':
            trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed,
        if (remarks != null && remarks.isNotEmpty)
          'remarks': remarks.length > 500 ? remarks.substring(0, 500) : remarks,
      },
    );

    return OcrResult.fromJson(ApiClient.asMap(raw));
  }
}

/// Placeholder used ONLY by the pre-submit verification screen, which runs
/// before any reading or image exists server-side (see the ordering note on
/// [OcrService]).
///
/// It produces a plausible reading and a confidence between 0.70 and 1.00 so
/// the review UI - badge colours, the low-confidence banner, the editable
/// field - can be exercised. The screen labels it as a placeholder so nobody
/// mistakes it for a model prediction.
///
/// Delete this once there is a way to OCR an image before submission.
class StubOcrService {
  final Random _random;

  StubOcrService([Random? random]) : _random = random ?? Random();

  Future<OcrResult> extractForReading(String imagePath) async {
    // Simulates inference latency.
    await Future.delayed(const Duration(milliseconds: 900));

    final fakeReading = (1000 + _random.nextInt(8999)).toString();
    final fakeConfidence = 0.7 + _random.nextDouble() * 0.3;

    return OcrResult(
      extractedReading: fakeReading,
      confidenceScore: double.parse(fakeConfidence.toStringAsFixed(2)),
      processingTimeMs: 900,
      isStub: true,
    );
  }
}