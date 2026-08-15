import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/router.dart';
import '../core/theme.dart';
import '../providers/camera_provider.dart';

class MeterCaptureScreen extends ConsumerWidget {
  final String consumerId;
  const MeterCaptureScreen({super.key, required this.consumerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(cameraControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Capture Meter Reading'),
      ),
      body: switch (captureState.status) {
        CameraStatus.initializing => const _LoadingView(),
        CameraStatus.error => _ErrorView(message: captureState.errorMessage ?? 'Unknown camera error'),
        CameraStatus.ready => _LivePreview(consumerId: consumerId, controller: captureState.controller!),
        CameraStatus.captured => _ReviewView(
            consumerId: consumerId,
            imagePath: captureState.capturedImagePath!,
          ),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
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
            const Icon(Icons.videocam_off_outlined, color: AppColors.error, size: 40),
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
  final CameraController controller;
  const _LivePreview({required this.consumerId, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);

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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Align the meter display within the frame',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ),

        // Bottom control bar — flat, no colored shadows, standard iconography.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.xl),
            color: Colors.black.withOpacity(0.55),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => ref.read(cameraControllerProvider.notifier).toggleFlash(),
                  icon: Icon(
                    state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                ),
                _ShutterButton(
                  onPressed: () => ref.read(cameraControllerProvider.notifier).capture(),
                ),
                // Placeholder to balance the row (e.g. future gallery-pick icon)
                const SizedBox(width: 48),
              ],
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
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

/// Shown after capture: officer confirms the photo is usable before it's
/// handed off (later) to local storage + the OCR pipeline someone else owns.
class _ReviewView extends ConsumerWidget {
  final String consumerId;
  final String imagePath;
  const _ReviewView({required this.consumerId, required this.imagePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: kIsWeb
            ? Image.network(imagePath, fit: BoxFit.contain, width: double.infinity)
            : Image.file(File(imagePath), fit: BoxFit.contain, width: double.infinity),
        ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => ref.read(cameraControllerProvider.notifier).retake(),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {
                      // TODO: also persist CaptureResult(consumerId, imagePath, DateTime.now())
                      // to local storage (pending_readings box) here once that layer exists.
                      context.push(
                        AppRoutes.ocrVerification,
                        extra: OcrVerificationArgs(consumerId: consumerId, imagePath: imagePath),
                      );
                    },
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