import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/constants.dart';
import '../models/ocr_result.dart';
import '../services/ocr_service.dart';
import 'core_providers.dart';

// =====================================================================
// PRE-SUBMIT (stub)
//
// Runs on the local image path, before any reading or image exists on the
// server. Cannot be the real service - see the ordering note in
// ocr_service.dart.
// =====================================================================

final stubOcrServiceProvider = Provider<StubOcrService>((ref) {
  return StubOcrService();
});

/// Keyed by imagePath so re-running OCR on a different capture does not
/// return a stale cached result.
final ocrResultProvider =
    FutureProvider.autoDispose.family<OcrResult, String>((ref, imagePath) async {
  return ref.watch(stubOcrServiceProvider).extractForReading(imagePath);
});

// =====================================================================
// POST-SUBMIT (real)
// =====================================================================

final ocrServiceProvider = Provider<OcrService>((ref) {
  return ApiOcrService(ref.watch(apiClientProvider));
});

/// Identifies one AI review. Needs value equality because Riverpod families
/// key their providers on it.
class OcrReviewArgs {
  final String imageId;
  final String officerReading;

  const OcrReviewArgs({
    required this.imageId,
    required this.officerReading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrReviewArgs &&
          other.imageId == imageId &&
          other.officerReading == officerReading);

  @override
  int get hashCode => Object.hash(imageId, officerReading);
}

enum OcrReviewStage {
  processing,

  /// The model read the same value the officer typed.
  agreed,

  /// The model disagreed but was not confident enough to override.
  /// The officer's reading stands.
  disagreedLowConfidence,

  /// The model disagreed with high confidence and its reading was applied.
  autoApplied,

  /// An auto-apply was rolled back to the officer's original reading.
  reverted,

  /// The pipeline could not produce a reading at all.
  noReading,

  failed,
}

class OcrReviewState {
  final OcrReviewStage stage;
  final OcrResult? result;

  /// What the officer originally typed - kept so [OcrReviewNotifier.undo]
  /// can restore it.
  final String officerReading;

  /// The reading currently stored server-side for this meter.
  final String effectiveReading;

  final bool isBusy;
  final String? errorMessage;

  const OcrReviewState({
    required this.stage,
    required this.officerReading,
    required this.effectiveReading,
    this.result,
    this.isBusy = false,
    this.errorMessage,
  });

  bool get isProcessing => stage == OcrReviewStage.processing;
  bool get wasAutoApplied => stage == OcrReviewStage.autoApplied;
  bool get canUndo => wasAutoApplied && !isBusy;

  OcrReviewState copyWith({
    OcrReviewStage? stage,
    OcrResult? result,
    String? effectiveReading,
    bool? isBusy,
    String? errorMessage,
  }) {
    return OcrReviewState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      officerReading: officerReading,
      effectiveReading: effectiveReading ?? this.effectiveReading,
      isBusy: isBusy ?? this.isBusy,
      // Deliberately not `??` - passing null clears the error.
      errorMessage: errorMessage,
    );
  }
}

/// Runs the AI pipeline over the uploaded photo once the reading exists, and
/// applies the model's value when - and only when - it is confident enough.
///
/// ---------------------------------------------------------------------
/// ON AUTO-APPLY
/// ---------------------------------------------------------------------
///
/// Overwriting a number a human read off a physical meter, for billing, is
/// not a decision to take lightly. Three constraints keep it defensible:
///
///  1. The bar is [ApiConstants.ocrAutoApplyConfidence] (0.95), not the
///     server's `success` threshold of 0.70. Passing 0.70 only means the
///     result is worth showing.
///  2. It is always visible - the dialog states plainly that the reading was
///     replaced, and by what.
///  3. It is always reversible via [undo], in one tap.
///
/// Both the apply and the undo write an audit trail into
/// `ocr_results.verification_remarks`, and because `PUT /ocr/{id}/verify` also
/// rewrites `meter_readings.reading_value` and `units_consumed`, the stored
/// reading and the OCR record never drift apart.
class OcrReviewNotifier extends StateNotifier<OcrReviewState> {
  final OcrService _service;
  final OcrReviewArgs _args;

  OcrReviewNotifier(this._service, this._args)
      : super(
          OcrReviewState(
            stage: OcrReviewStage.processing,
            officerReading: _args.officerReading,
            effectiveReading: _args.officerReading,
          ),
        ) {
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await _service.processImage(_args.imageId);

      if (!mounted) return;

      if (!result.hasReading) {
        state = state.copyWith(
          stage: OcrReviewStage.noReading,
          result: result,
        );
        return;
      }

      if (result.matches(_args.officerReading)) {
        state = state.copyWith(
          stage: OcrReviewStage.agreed,
          result: result,
        );
        return;
      }

      // Disagreement. Only override when well past the auto-apply bar, and
      // only when there is an ocr_id to correct through.
      if (result.isAutoApplyConfident && result.id != null) {
        await _apply(result);
        return;
      }

      state = state.copyWith(
        stage: OcrReviewStage.disagreedLowConfidence,
        result: result,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        stage: OcrReviewStage.failed,
        errorMessage: e.displayMessage,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        stage: OcrReviewStage.failed,
        errorMessage: 'AI verification could not be completed.',
      );
    }
  }

  Future<void> _apply(OcrResult result) async {
    state = state.copyWith(isBusy: true, errorMessage: null);

    try {
      final verified = await _service.verifyResult(
        ocrId: result.id!,
        correctedReading: result.extractedReading,
        remarks: 'Auto-applied by MeterVision: model read '
            '${result.extractedReading} at '
            '${(result.confidenceScore * 100).toStringAsFixed(1)}% confidence; '
            'officer entered ${_args.officerReading}.',
      );

      if (!mounted) return;

      state = state.copyWith(
        stage: OcrReviewStage.autoApplied,
        result: verified,
        effectiveReading: result.extractedReading,
        isBusy: false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // The correction failed, so the officer's reading is still what is
      // stored. Say so rather than claiming an override that did not happen.
      state = state.copyWith(
        stage: OcrReviewStage.disagreedLowConfidence,
        result: result,
        isBusy: false,
        errorMessage: 'Could not apply the AI reading: ${e.displayMessage}',
      );
    }
  }

  /// Restores the officer's original reading.
  Future<void> undo() async {
    final result = state.result;
    if (result?.id == null || state.isBusy) return;

    state = state.copyWith(isBusy: true, errorMessage: null);

    try {
      final reverted = await _service.verifyResult(
        ocrId: result!.id!,
        correctedReading: _args.officerReading,
        remarks: 'Officer reverted the auto-applied AI reading and confirmed '
            '${_args.officerReading} from the physical meter.',
      );

      if (!mounted) return;

      state = state.copyWith(
        stage: OcrReviewStage.reverted,
        result: reverted,
        effectiveReading: _args.officerReading,
        isBusy: false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Could not restore your reading: ${e.displayMessage}',
      );
    }
  }
}

/// autoDispose so the pipeline is not re-run when the officer reopens a
/// dialog, and so nothing lingers after the confirmation is dismissed.
final ocrReviewProvider = StateNotifierProvider.autoDispose
    .family<OcrReviewNotifier, OcrReviewState, OcrReviewArgs>((ref, args) {
  return OcrReviewNotifier(ref.watch(ocrServiceProvider), args);
});