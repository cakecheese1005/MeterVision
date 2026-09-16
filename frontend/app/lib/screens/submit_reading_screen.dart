import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/capture_result.dart';
import '../models/meter_reading_draft.dart';
import '../providers/consumer_provider.dart';
import '../providers/ocr_provider.dart';
import '../providers/reading_provider.dart';
import '../services/reading_repository.dart';
import '../widgets/captured_image.dart';

class SubmitReadingScreen extends ConsumerStatefulWidget {
  final CaptureResult capture;
  final String reading;
  final double? ocrConfidence;

  const SubmitReadingScreen({
    super.key,
    required this.capture,
    required this.reading,
    this.ocrConfidence,
  });

  @override
  ConsumerState<SubmitReadingScreen> createState() =>
      _SubmitReadingScreenState();
}

class _SubmitReadingScreenState extends ConsumerState<SubmitReadingScreen> {
  MeterType? _selectedType;
  bool _typeInitialised = false;

  @override
  Widget build(BuildContext context) {
    final consumer = ref.watch(consumerByIdProvider(widget.capture.consumerId));
    final submitState = ref.watch(submitReadingProvider);
    final isSubmitting = submitState.isLoading;

    // Prefill the meter type from the consumer record — the consumers table
    // already stores meter_type, so making the officer re-enter it is asking
    // for a contradiction rather than information.
    if (!_typeInitialised && consumer?.meterType != null) {
      _selectedType = consumer!.meterType;
      _typeInitialised = true;
    }

    ref.listen<AsyncValue<SubmitOutcome?>>(submitReadingProvider,
        (previous, next) {
      // Only react to the transition out of a submit we started.
      if (previous is! AsyncLoading) return;

      if (next.hasError) {
        final err = next.error;
        final message = err is ApiException
            ? err.displayMessage
            : 'Could not submit the reading.';

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
            ),
          );
        return;
      }

      final outcome = next.value;
      if (outcome != null) _showOutcome(outcome);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Reading')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: CapturedImage(
                        imagePath: widget.capture.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryCard(
                    consumerName: consumer?.consumerName,
                    consumerReference:
                        consumer?.displayReference ?? widget.capture.consumerId,
                    meterNumber: consumer?.meterNumber,
                    reading: widget.reading,
                  ),
                  if (!widget.capture.hasLocation) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _WarningBanner(
                      icon: Icons.location_off_outlined,
                      message: 'No GPS fix was recorded for this capture. '
                          'The reading will be submitted without coordinates.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Meter Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // Being straight about this rather than implying the
                    // selection travels with the reading.
                    'Recorded on this device only — the reading API does not '
                    'accept a meter type.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: MeterType.electroMechanical.label,
                          selected:
                              _selectedType == MeterType.electroMechanical,
                          onTap: () => setState(
                            () => _selectedType = MeterType.electroMechanical,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TypeChip(
                          label: MeterType.digital.label,
                          selected: _selectedType == MeterType.digital,
                          onTap: () =>
                              setState(() => _selectedType = MeterType.digital),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedType == null || isSubmitting)
                      ? null
                      : _handleSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SUBMIT READING'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    final draft = MeterReadingDraft(
      consumerId: widget.capture.consumerId,
      imagePath: widget.capture.imagePath,
      meterReading: widget.reading,
      meterType: _selectedType!,
      ocrConfidence: widget.ocrConfidence,
      capturedAt: widget.capture.capturedAt,
      latitude: widget.capture.latitude,
      longitude: widget.capture.longitude,
      locationAvailable: widget.capture.hasLocation,
    );

    ref.read(submitReadingProvider.notifier).submit(draft);
  }

  /// Shows what the server actually recorded.
  ///
  /// `POST /readings/create` returns `previous_reading` and `units_consumed`,
  /// and until now both were parsed and thrown away — the officer got a
  /// snackbar and no confirmation of what was stored.
  Future<void> _showOutcome(SubmitOutcome outcome) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OutcomeDialog(
        outcome: outcome,
        officerReading: widget.reading,
      ),
    );

    if (!mounted) return;

    // Back to the round, ready for the next consumer.
    context.go(AppRoutes.consumerList);
  }
}

class _OutcomeDialog extends StatelessWidget {
  final SubmitOutcome outcome;

  /// What the officer typed - handed to the AI review so it can tell agreement
  /// from disagreement, and restore the original if an auto-apply is undone.
  final String officerReading;

  const _OutcomeDialog({
    required this.outcome,
    required this.officerReading,
  });

  @override
  Widget build(BuildContext context) {
    final reading = outcome.reading;
    final imageId = outcome.image?.imageId;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            outcome.queuedOffline
                ? Icons.cloud_off_outlined
                : Icons.check_circle_outline,
            color:
                outcome.queuedOffline ? AppColors.pending : AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(outcome.headline)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outcome.detail,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            if (reading != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              _row(context, 'Current reading',
                  reading.readingValue.toStringAsFixed(2)),
              if (reading.previousReading != null)
                _row(context, 'Previous reading',
                    reading.previousReading!.toStringAsFixed(2)),
              if (reading.unitsConsumed != null)
                _row(
                  context,
                  'Units consumed',
                  '${reading.unitsConsumed!.toStringAsFixed(2)} kWh',
                  emphasise: true,
                ),
              _row(context, 'Status', reading.status.label),

              // No tariff table or billing endpoint exists on the backend, so
              // units consumed is as far as this can go today.
              if (reading.unitsConsumed != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Provisional billing is calculated by the back office.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],

            // AI verification runs only once the photo is actually on the
            // server - the pipeline is keyed on image_id. Offline submissions
            // and pending uploads simply skip it.
            if (imageId != null && imageId.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              _AiVerificationSection(
                imageId: imageId,
                officerReading: officerReading,
                previousReading: reading?.previousReading,
              ),
            ],

            if (outcome.needsRecapture) ...[
              const SizedBox(height: AppSpacing.md),
              _WarningBanner(
                icon: Icons.image_not_supported_outlined,
                message: outcome.image?.quality?.label ??
                    'The photo may need to be retaken.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('DONE'),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasise = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: emphasise
                  ? Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.primary)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of `POST /ocr/process/{image_id}`, shown after submission.
///
/// This runs here rather than before submit because the OCR pipeline is keyed
/// on an uploaded image, which is keyed on an existing reading - the schema
/// makes pre-submit server OCR impossible.
class _AiVerificationSection extends ConsumerWidget {
  final String imageId;
  final String officerReading;
  final double? previousReading;

  const _AiVerificationSection({
    required this.imageId,
    required this.officerReading,
    this.previousReading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = OcrReviewArgs(
      imageId: imageId,
      officerReading: officerReading,
    );

    final review = ref.watch(ocrReviewProvider(args));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'AI verification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _body(context, ref, review),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, OcrReviewState review) {
    if (review.isProcessing) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Reading the meter photo...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    final result = review.result;
    final confidence = result == null
        ? ''
        : '${(result.confidenceScore * 100).toStringAsFixed(0)}%';

    switch (review.stage) {
      case OcrReviewStage.agreed:
        return _note(
          context,
          icon: Icons.verified_outlined,
          color: AppColors.success,
          text: 'The model read the same value you entered '
              '($confidence confidence).',
        );

      case OcrReviewStage.autoApplied:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              context,
              icon: Icons.published_with_changes,
              color: AppColors.pending,
              text: 'The model read ${result?.extractedReading} at '
                  '$confidence confidence and this reading was updated. '
                  'You entered $officerReading.',
            ),
            if (previousReading != null && result != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Units recalculated: '
                '${_units(result.extractedReading).toStringAsFixed(2)} kWh',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // Auto-apply is always one tap from being undone. The officer is
            // the one who physically saw the meter.
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: review.canUndo
                    ? () => ref
                        .read(ocrReviewProvider(OcrReviewArgs(
                          imageId: imageId,
                          officerReading: officerReading,
                        )).notifier)
                        .undo()
                    : null,
                icon: review.isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo, size: 16),
                label: Text('KEEP MY READING ($officerReading)'),
              ),
            ),
            if (review.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                review.errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        );

      case OcrReviewStage.reverted:
        return _note(
          context,
          icon: Icons.undo,
          color: AppColors.success,
          text: 'Your reading of $officerReading has been restored.',
        );

      case OcrReviewStage.disagreedLowConfidence:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              context,
              icon: Icons.info_outline,
              color: AppColors.textSecondary,
              text: 'The model read ${result?.extractedReading} at '
                  '$confidence confidence. That is below the threshold for '
                  'changing a reading, so yours stands.',
            ),
            if (review.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                review.errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        );

      case OcrReviewStage.noReading:
        return _note(
          context,
          icon: Icons.visibility_off_outlined,
          color: AppColors.textSecondary,
          text: 'The model could not read the meter from this photo. '
              'Your reading stands.',
        );

      case OcrReviewStage.failed:
        return _note(
          context,
          icon: Icons.cloud_off_outlined,
          color: AppColors.textSecondary,
          text: review.errorMessage ??
              'AI verification is unavailable. Your reading stands.',
        );

      case OcrReviewStage.processing:
        return const SizedBox.shrink();
    }
  }

  double _units(String reading) {
    final value = double.tryParse(reading.trim()) ?? 0;
    final previous = previousReading ?? 0;
    final units = value - previous;
    return units < 0 ? 0 : units;
  }

  Widget _note(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String? consumerName;
  final String consumerReference;
  final String? meterNumber;
  final String reading;

  const _SummaryCard({
    required this.consumerReference,
    required this.reading,
    this.consumerName,
    this.meterNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (consumerName != null)
              _row(context, 'Consumer', consumerName!),
            _row(context, 'Reference', consumerReference),
            if (meterNumber != null && meterNumber!.isNotEmpty)
              _row(context, 'Meter no.', meterNumber!),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            _row(context, 'Meter Reading', reading, valueSize: 20),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    double? valueSize,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: valueSize),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _WarningBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.pending),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.pending),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat toggle chip — no filled Material chips with elevation/shadow,
/// matches the utilitarian design system.
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}