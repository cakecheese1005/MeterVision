import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../models/capture_result.dart';
import '../models/ocr_result.dart';
import '../providers/ocr_provider.dart';
import '../widgets/captured_image.dart';

class OcrVerificationScreen extends ConsumerStatefulWidget {
  final CaptureResult capture;

  const OcrVerificationScreen({super.key, required this.capture});

  @override
  ConsumerState<OcrVerificationScreen> createState() =>
      _OcrVerificationScreenState();
}

class _OcrVerificationScreenState extends ConsumerState<OcrVerificationScreen> {
  final _readingController = TextEditingController();

  /// Only auto-fill the field once, on the first OCR result — otherwise a
  /// rebuild would overwrite whatever the officer has typed.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();

    // ---------------------------------------------------------------
    // Rebuild on every keystroke.
    //
    // The CONFIRM button is gated on the field being non-empty, and that
    // condition is evaluated during build. Without this listener nothing
    // triggers a rebuild when the officer types, so if OCR failed or returned
    // an empty string the button stayed disabled forever and the reading could
    // not be entered manually at all.
    // ---------------------------------------------------------------
    _readingController.addListener(_onReadingChanged);
  }

  void _onReadingChanged() => setState(() {});

  @override
  void dispose() {
    _readingController.removeListener(_onReadingChanged);
    _readingController.dispose();
    super.dispose();
  }

  bool get _canContinue => _readingController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ocrAsync = ref.watch(ocrResultProvider(widget.capture.imagePath));

    ref.listen(ocrResultProvider(widget.capture.imagePath), (previous, next) {
      next.whenData((result) {
        if (!_prefilled && result.extractedReading.isNotEmpty) {
          _readingController.text = result.extractedReading;
          _prefilled = true;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Reading')),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CapturedImage(
              imagePath: widget.capture.imagePath,
              fit: BoxFit.cover,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ocrAsync.when(
                    loading: () => const _OcrLoadingCard(),
                    error: (err, _) => const _OcrErrorCard(),
                    data: (result) => _OcrResultCard(result: result),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Meter Reading',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _readingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      // meter_readings.reading_value is NUMERIC(10,2).
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,8}\.?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter or correct the reading',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Confirm this matches the physical meter before proceeding.',
                    style: Theme.of(context).textTheme.bodySmall,
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
                  onPressed: _canContinue
                      ? () => context.push(
                            AppRoutes.submitReading,
                            extra: SubmitReadingArgs(
                              capture: widget.capture,
                              reading: _readingController.text.trim(),
                              ocrConfidence:
                                  ocrAsync.valueOrNull?.confidenceScore,
                            ),
                          )
                      : null,
                  child: const Text('CONFIRM & CONTINUE'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrLoadingCard extends StatelessWidget {
  const _OcrLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Reading the meter image...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrErrorCard extends StatelessWidget {
  const _OcrErrorCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Automatic reading failed. Enter the reading manually below.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrResultCard extends StatelessWidget {
  final OcrResult result;

  const _OcrResultCard({required this.result});

  Color get _statusColor {
    if (result.confidenceScore >= 0.90) return AppColors.success;
    if (result.confidenceScore >= OcrResult.lowConfidenceThreshold) {
      return AppColors.pending;
    }
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Reading',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.extractedReading.isEmpty
                            ? '—'
                            : result.extractedReading,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _statusColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(result.confidenceScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            if (result.requiresManualReview) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Low confidence. Check the reading against the meter carefully.',
                style: TextStyle(color: _statusColor, fontSize: 12),
              ),
            ],

            // ---------------------------------------------------------
            // Honesty about the placeholder.
            //
            // Server OCR is keyed on an uploaded image, which is keyed on an
            // existing reading - so it structurally cannot run at this point
            // in the flow. This number comes from StubOcrService and is
            // labelled as such; the real model runs after submission and its
            // result appears in the confirmation dialog.
            // ---------------------------------------------------------
            if (result.isStub) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.pending),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined,
                        size: 16, color: AppColors.pending),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Placeholder value — enter the reading from the meter '
                        'yourself. The AI check runs after you submit.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}