import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../models/capture_result.dart';
import '../providers/camera_provider.dart';
import '../providers/consumer_provider.dart';
import '../widgets/captured_image.dart';

class MeterCaptureScreen extends ConsumerWidget {
  final String consumerId;

  const MeterCaptureScreen({super.key, required this.consumerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider(consumerId));
    final consumer = ref.watch(consumerByIdProvider(consumerId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(consumer?.consumerName ?? 'Capture Meter Reading'),
        // The consumer number matters more than the UUID when an officer is
        // checking they are photographing the right meter.
        bottom: consumer == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${consumer.displayReference}  ·  Meter '
                      '${consumer.meterNumber}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ),
      ),
      body: switch (state.status) {
        CameraStatus.initializing => const _LoadingView(),
        CameraStatus.error =>
          _ErrorView(message: state.errorMessage ?? 'Unknown camera error'),
        CameraStatus.ready => _LivePreview(consumerId: consumerId),
        CameraStatus.captured => state.capture == null
            // Defensive: retake clears the capture, and a frame can render
            // between that and the status flip.
            ? const _LoadingView()
            : _ReviewView(
                consumerId: consumerId,
                capture: state.capture!,
                isLocating: state.isLocating,
              ),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live camera preview with a fixed alignment guide overlay — a functional
/// aid for lining up the meter dial/digits, not a decorative element.
class _LivePreview extends ConsumerWidget {
  final String consumerId;

  const _LivePreview({required this.consumerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider(consumerId));
    final controller = state.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const _LoadingView();
    }

    final notifier = ref.read(cameraControllerProvider(consumerId).notifier);

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),

        // Alignment guide: helps the officer frame the meter face/digits.
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.32,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Align the meter display within the frame',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),

        // Bottom control bar — flat, no colored shadows, standard iconography.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.xl,
            ),
            color: Colors.black54,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: state.isFlashOn ? 'Torch off' : 'Torch on',
                    onPressed: notifier.toggleFlash,
                    icon: Icon(
                      state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                  _ShutterButton(onPressed: notifier.capture),
                  // Balances the row.
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Flat circular shutter — deliberately not a colored/shadowed FAB.
class _ShutterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShutterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border:
              Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
        child: Container(
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

/// Shown after capture: the officer confirms the photo is usable before it
/// goes on to reading entry.
class _ReviewView extends ConsumerWidget {
  final String consumerId;
  final CaptureResult capture;
  final bool isLocating;

  const _ReviewView({
    required this.consumerId,
    required this.capture,
    required this.isLocating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: CapturedImage(
            imagePath: capture.imagePath,
            fit: BoxFit.contain,
          ),
        ),
        _LocationStrip(capture: capture, isLocating: isLocating),
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: ref
                        .read(cameraControllerProvider(consumerId).notifier)
                        .retake,
                    child: const Text('RETAKE'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () => context.push(
                      AppRoutes.ocrVerification,
                      extra: OcrVerificationArgs(capture: capture),
                    ),
                    child: const Text('USE PHOTO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Makes the GPS state visible rather than letting a missing fix silently
/// become 0.0 on the server.
class _LocationStrip extends StatelessWidget {
  final CaptureResult capture;
  final bool isLocating;

  const _LocationStrip({required this.capture, required this.isLocating});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String text;
    late final Color color;

    if (isLocating) {
      icon = Icons.location_searching;
      text = 'Getting GPS fix...';
      color = Colors.white70;
    } else if (capture.hasLocation) {
      icon = Icons.location_on_outlined;
      text = 'GPS ${capture.latitude!.toStringAsFixed(5)}, '
          '${capture.longitude!.toStringAsFixed(5)}';
      color = Colors.white;
    } else {
      icon = Icons.location_off_outlined;
      text = 'No GPS fix — the reading will be saved without coordinates';
      color = AppColors.pending;
    }

    return Container(
      width: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
