import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/location/location_service.dart';
import '../models/capture_result.dart';
import 'core_providers.dart';

enum CameraStatus { initializing, ready, error, captured }

/// Immutable state the UI reacts to.
///
/// The UI never touches CameraController methods directly except
/// `CameraPreview(controller)`, which just renders frames - all lifecycle and
/// capture logic stays in the notifier below.
class CameraCaptureState {
  final CameraStatus status;
  final CameraController? controller;
  final String? errorMessage;
  final CaptureResult? capture;
  final bool isFlashOn;

  /// True while the GPS fix is being taken, just after the shutter fires.
  final bool isLocating;

  const CameraCaptureState({
    this.status = CameraStatus.initializing,
    this.controller,
    this.errorMessage,
    this.capture,
    this.isFlashOn = false,
    this.isLocating = false,
  });

  String? get capturedImagePath => capture?.imagePath;

  /// ---------------------------------------------------------------
  /// Preserving copyWith.
  ///
  /// The previous version passed `errorMessage` and `capturedImagePath`
  /// straight through without `??`, so any call that omitted them silently
  /// reset both to null. `_ReviewView` dereferences the captured path with
  /// `!`, which made every future copyWith a latent null-assertion crash -
  /// `toggleFlash()` only got away with it because it is unreachable from
  /// the review screen.
  ///
  /// Both fields genuinely need clearing (on retake, and when an error is
  /// resolved), so that is expressed explicitly with the two `clear` flags
  /// rather than by accident.
  /// ---------------------------------------------------------------
  CameraCaptureState copyWith({
    CameraStatus? status,
    CameraController? controller,
    String? errorMessage,
    CaptureResult? capture,
    bool? isFlashOn,
    bool? isLocating,
    bool clearError = false,
    bool clearCapture = false,
  }) {
    return CameraCaptureState(
      status: status ?? this.status,
      controller: controller ?? this.controller,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      capture: clearCapture ? null : (capture ?? this.capture),
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isLocating: isLocating ?? this.isLocating,
    );
  }
}

class CameraNotifier extends StateNotifier<CameraCaptureState> {
  final LocationService _locationService;
  final String consumerId;

  CameraNotifier(this._locationService, this.consumerId)
      : super(const CameraCaptureState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        state = state.copyWith(
          status: CameraStatus.error,
          errorMessage: 'No camera found on this device.',
        );
        return;
      }

      // Rear camera for meter photography.
      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rearCamera,
        // Meter digits need to stay legible for OCR. `high` is 1280x720,
        // which encodes to a few hundred KB of JPEG - comfortably inside the
        // backend's 10 MB cap, so no client-side compression step is needed.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      state = state.copyWith(
        status: CameraStatus.ready,
        controller: controller,
        clearError: true,
      );
    } on CameraException catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: _describeCameraError(e),
      );
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: 'The camera could not be started.',
      );
    }
  }

  /// Turns plugin error codes into something a field officer can act on.
  static String _describeCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission was denied. Enable camera access for '
            'MeterVision in system settings, then try again.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      default:
        return e.description ?? 'The camera is unavailable.';
    }
  }

  Future<void> toggleFlash() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final newValue = !state.isFlashOn;

    try {
      await controller.setFlashMode(newValue ? FlashMode.torch : FlashMode.off);
      state = state.copyWith(isFlashOn: newValue);
    } on CameraException {
      // Torch is not available on every device; failing to toggle it is not
      // worth interrupting the capture flow for.
    }
  }

  Future<void> capture() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    try {
      final XFile file = await controller.takePicture();

      if (!mounted) return;

      // Show the review screen immediately; the GPS fix resolves behind it
      // rather than making the officer wait on a satellite lock.
      state = state.copyWith(
        status: CameraStatus.captured,
        capture: CaptureResult(
          consumerId: consumerId,
          imagePath: file.path,
          capturedAt: DateTime.now(),
        ),
        isLocating: true,
        clearError: true,
      );

      final result = await _locationService.currentPosition();

      if (!mounted) return;

      final existing = state.capture;
      if (existing == null) return; // officer already hit retake

      state = state.copyWith(
        capture: existing.copyWith(
          location: result.fix,
          locationFailure: result.failure,
        ),
        isLocating: false,
      );
    } on CameraException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: _describeCameraError(e),
        isLocating: false,
      );
    }
  }

  /// Discards the captured frame and returns to live preview.
  void retake() {
    state = state.copyWith(
      status: CameraStatus.ready,
      isLocating: false,
      clearCapture: true,
      clearError: true,
    );
  }

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

/// autoDispose: the controller is released as soon as the screen is popped,
/// so the camera hardware is not held open in the background.
///
/// Keyed by consumerId so the capture carries the consumer it belongs to
/// without the screen having to thread it through separately.
final cameraControllerProvider = StateNotifierProvider.autoDispose
    .family<CameraNotifier, CameraCaptureState, String>((ref, consumerId) {
  return CameraNotifier(ref.watch(locationServiceProvider), consumerId);
});
