import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ocr_result.dart';
import '../services/ocr_service.dart';

/// Swap this one line for the real implementation once the OCR
/// model/endpoint is ready — screens never change.
final ocrServiceProvider = Provider<OcrService>((ref) => StubOcrService());

/// Keyed by imagePath so re-running OCR on a different capture
/// doesn't return a stale cached result.
final ocrResultProvider = FutureProvider.family<OcrResult, String>((ref, imagePath) async {
  final service = ref.watch(ocrServiceProvider);
  return service.extractReading(imagePath);
});