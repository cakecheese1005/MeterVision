import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/meter_reading_draft.dart';
import '../providers/reading_provider.dart';
import '../widgets/captured_image.dart';

class SubmitReadingScreen extends ConsumerStatefulWidget {
  final String consumerId;
  final String imagePath;
  final String reading;
  final double? ocrConfidence;

  const SubmitReadingScreen({
    super.key,
    required this.consumerId,
    required this.imagePath,
    required this.reading,
    this.ocrConfidence,
  });

  @override
  ConsumerState<SubmitReadingScreen> createState() => _SubmitReadingScreenState();
}

class _SubmitReadingScreenState extends ConsumerState<SubmitReadingScreen> {
  MeterType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitReadingProvider);
    final isSubmitting = submitState.isLoading;

    // React to submit result: success -> confirm + return to Consumer List,
    // error -> surface it so the officer can retry (nothing is lost).
    ref.listen(submitReadingProvider, (previous, next) {
      next.when(
        data: (_) {
          if (previous is AsyncLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reading saved locally — will sync when online.')),
            );
            context.go(AppRoutes.consumerList);
          }
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save reading: $err')),
          );
        },
        loading: () {},
      );
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
                      child: CapturedImage(imagePath: widget.imagePath, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryCard(consumerId: widget.consumerId, reading: widget.reading),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Meter Type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: 'Electro-Mechanical',
                          selected: _selectedType == MeterType.electroMechanical,
                          onTap: () => setState(() => _selectedType = MeterType.electroMechanical),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TypeChip(
                          label: 'Digital',
                          selected: _selectedType == MeterType.digital,
                          onTap: () => setState(() => _selectedType = MeterType.digital),
                        ),
                      ),
                    ],
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
                onPressed: (_selectedType == null || isSubmitting) ? null : _handleSubmit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('SUBMIT READING'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    final draft = MeterReadingDraft(
      consumerId: widget.consumerId,
      imagePath: widget.imagePath,
      meterReading: widget.reading,
      meterType: _selectedType!,
      ocrConfidence: widget.ocrConfidence,
      capturedAt: DateTime.now(),
    );
    ref.read(submitReadingProvider.notifier).submit(draft);
  }
}

class _SummaryCard extends StatelessWidget {
  final String consumerId;
  final String reading;
  const _SummaryCard({required this.consumerId, required this.reading});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(context, 'Consumer ID', consumerId),
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

  Widget _row(BuildContext context, String label, String value, {double? valueSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: valueSize),
        ),
      ],
    );
  }
}

/// Flat toggle chip — no filled Material chips with elevation/shadow,
/// matches the strict utilitarian design system.
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
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