/// Represents a single meter photo capture before it's persisted locally.
/// This is what gets handed to the (future) local storage / OCR pipeline —
/// never a raw CameraController or XFile leaking into other layers.
class CaptureResult {
  final String consumerId;
  final String imagePath;
  final DateTime capturedAt;

  const CaptureResult({
    required this.consumerId,
    required this.imagePath,
    required this.capturedAt,
  });
}
