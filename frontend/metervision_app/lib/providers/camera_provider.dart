import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CameraStatus { initializing, ready, error, captured }

/// Immutable state the UI reacts to. The UI never touches CameraController
/// methods directly except CameraPreview(controller), which just renders
/// frames — all lifecycle/capture logic stays in the notifier below.
class CameraCaptureState {
  final CameraStatus status;
  final CameraController? controller;
  final String? errorMessage;
  final String? capturedImagePath;
  final bool isFlashOn;

  const CameraCaptureState({
    this.status = CameraStatus.initializing,
    this.controller,
    this.errorMessage,
    this.capturedImagePath,
    this.isFlashOn = false,
  });

  CameraCaptureState copyWith({
    CameraStatus? status,
    CameraController? controller,
    String? errorMessage,
    String? capturedImagePath,
    bool? isFlashOn,
  }) {
    return CameraCaptureState(
      status: status ?? this.status,
      controller: controller ?? this.controller,
      errorMessage: errorMessage,
      capturedImagePath: capturedImagePath,
      isFlashOn: isFlashOn ?? this.isFlashOn,
    );
  }
}

class CameraNotifier extends StateNotifier<CameraCaptureState> {
  CameraNotifier() : super(const CameraCaptureState()) {
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
        ResolutionPreset.high, // meter digits need to stay legible for OCR
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      state = state.copyWith(status: CameraStatus.ready, controller: controller);
    } on CameraException catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: e.description ?? 'Camera permission denied or unavailable.',
      );
    } catch (e) {
      state = state.copyWith(status: CameraStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> toggleFlash() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final newValue = !state.isFlashOn;
    await controller.setFlashMode(newValue ? FlashMode.torch : FlashMode.off);
    state = state.copyWith(isFlashOn: newValue);
  }

  Future<void> capture() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    try {
      final XFile file = await controller.takePicture();
      state = state.copyWith(status: CameraStatus.captured, capturedImagePath: file.path);
    } on CameraException catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: e.description ?? 'Failed to capture image.',
      );
    }
  }

  /// Discards the captured frame and returns to live preview.
  void retake() {
    state = state.copyWith(status: CameraStatus.ready, capturedImagePath: null);
  }

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

/// autoDispose: controller is released as soon as the screen is popped,
/// so we're not holding the camera hardware open in the background.
final cameraControllerProvider =
    StateNotifierProvider.autoDispose<CameraNotifier, CameraCaptureState>((ref) {
  return CameraNotifier();
});
