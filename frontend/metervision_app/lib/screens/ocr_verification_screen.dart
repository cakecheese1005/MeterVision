import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/theme.dart';
import '../models/ocr_result.dart';
import '../providers/ocr_provider.dart';

class OcrVerificationScreen extends ConsumerStatefulWidget {
  final String consumerId;
  final String imagePath;
  const OcrVerificationScreen({super.key, required this.consumerId, required this.imagePath});

  @override
  ConsumerState<OcrVerificationScreen> createState() => _OcrVerificationScreenState();
}

class _OcrVerificationScreenState extends ConsumerState<OcrVerificationScreen> {
  final _readingController = TextEditingController();
  bool _prefilled = false; // only auto-fill the field once, on first OCR result

  @override
  void dispose() {
    _readingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrAsync = ref.watch(ocrResultProvider(widget.imagePath));

    // Pre-fill the editable field with the OCR reading the first time it
    // arrives, without ever overwriting what the officer has since typed.
    ref.listen(ocrResultProvider(widget.imagePath), (previous, next) {
      next.whenData((result) {
        if (!_prefilled) {
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
            child: kIsWeb
                ? Image.network(widget.imagePath, fit: BoxFit.cover)
                : Image.file(File(widget.imagePath), fit: BoxFit.cover),
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
                    error: (err, _) => _OcrErrorCard(message: err.toString()),
                    data: (result) => _OcrResultCard(result: result),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Meter Reading', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _readingController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _readingController.text.trim().isEmpty
                    ? null
                    : () {
                        // TODO: hand off (consumerId, imagePath, manual reading,
                        // ocr result) to local storage (pending_readings box),
                        // then navigate to Submit Reading screen.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reading confirmed — Submit screen pending.')),
                        );
                      },
                child: const Text('CONFIRM & CONTINUE'),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Running OCR on captured image...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _OcrErrorCard extends StatelessWidget {
  final String message;
  const _OcrErrorCard({required this.message});

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
                'OCR failed: $message\nEnter the reading manually below.',
                style: const TextStyle(color: AppColors.error),
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
    if (result.confidenceScore >= 0.80) return AppColors.pending;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Detected Reading', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    result.extractedReading,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                border: Border.all(color: _statusColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(result.confidenceScore * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}