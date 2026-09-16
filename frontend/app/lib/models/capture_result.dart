import '../core/location/location_service.dart';

/// A single meter photo capture, plus whatever GPS fix was available at the
/// moment the shutter fired.
///
/// This is the hand-off object between the camera layer and the reading
/// pipeline - a raw CameraController or XFile never leaks past here.
class CaptureResult {
  final String consumerId;
  final String imagePath;
  final DateTime capturedAt;

  /// GPS at capture time. Null when no fix was available; see
  /// [locationFailure] for why.
  final LocationFix? location;

  /// Populated instead of [location] when the fix could not be taken, so the
  /// UI can tell the officer *why* rather than silently recording 0.0.
  final LocationFailure? locationFailure;

  const CaptureResult({
    required this.consumerId,
    required this.imagePath,
    required this.capturedAt,
    this.location,
    this.locationFailure,
  });

  bool get hasLocation => location != null;

  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;

  CaptureResult copyWith({
    String? consumerId,
    String? imagePath,
    DateTime? capturedAt,
    LocationFix? location,
    LocationFailure? locationFailure,
  }) {
    return CaptureResult(
      consumerId: consumerId ?? this.consumerId,
      imagePath: imagePath ?? this.imagePath,
      capturedAt: capturedAt ?? this.capturedAt,
      location: location ?? this.location,
      locationFailure: locationFailure ?? this.locationFailure,
    );
  }
}
