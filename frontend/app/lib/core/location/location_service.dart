/// A GPS fix taken at capture time.
class LocationFix {
  final double latitude;
  final double longitude;

  /// Horizontal accuracy in metres, when the platform reports one.
  final double? accuracy;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}

/// Why a fix could not be obtained. Surfaced to the officer so a missing
/// coordinate is a visible condition rather than a silent 0.0.
enum LocationFailure {
  /// The user denied the runtime permission.
  permissionDenied,

  /// Denied permanently - only recoverable from system settings.
  permissionDeniedForever,

  /// Location services are switched off device-wide.
  serviceDisabled,

  /// Timed out or the platform returned nothing.
  unavailable,

  /// No implementation is wired in (see [NullLocationService]).
  notConfigured,
}

class LocationResult {
  final LocationFix? fix;
  final LocationFailure? failure;

  const LocationResult.success(LocationFix this.fix) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : fix = null;

  bool get hasFix => fix != null;

  String get message {
    final reason = failure;
    if (reason == null) return '';

    switch (reason) {
      case LocationFailure.permissionDenied:
        return 'Location permission was denied. The reading will be saved '
            'without GPS coordinates.';
      case LocationFailure.permissionDeniedForever:
        return 'Location permission is blocked. Enable it in system settings '
            'to record GPS with readings.';
      case LocationFailure.serviceDisabled:
        return 'Location services are turned off. Turn them on to record GPS '
            'with readings.';
      case LocationFailure.unavailable:
        return 'Could not get a GPS fix. The reading will be saved without '
            'coordinates.';
      case LocationFailure.notConfigured:
        return 'GPS capture is not enabled in this build.';
    }
  }
}

abstract class LocationService {
  /// Requests permission if needed and returns the current position.
  /// Never throws - failures come back as a [LocationResult.failed].
  Future<LocationResult> currentPosition();
}

/// Default implementation: always reports "not configured".
///
/// ---------------------------------------------------------------------
/// WHY THIS IS THE DEFAULT
/// ---------------------------------------------------------------------
///
/// Capturing GPS needs a plugin (`geolocator`), which is a new dependency.
/// Adding one that has not been resolved against this project's Flutter
/// version would risk breaking the build for everyone, so the plumbing is
/// wired end-to-end and the platform call is left switched off.
///
/// Everything downstream already works: [LocationResult] flows through
/// `CaptureResult` -> `MeterReadingDraft` -> `ReadingCreate`, the submit
/// screen shows a warning banner when there is no fix, and the draft records
/// `locationAvailable: false` so a 0.0 coordinate is never mistaken for a
/// real one.
///
/// ---------------------------------------------------------------------
/// TO ENABLE (about five minutes)
/// ---------------------------------------------------------------------
///
/// 1. `flutter pub add geolocator`
///
/// 2. Create `lib/core/location/geolocator_location_service.dart`:
///
/// ```dart
/// import 'package:geolocator/geolocator.dart';
/// import 'location_service.dart';
///
/// class GeolocatorLocationService implements LocationService {
///   @override
///   Future<LocationResult> currentPosition() async {
///     try {
///       if (!await Geolocator.isLocationServiceEnabled()) {
///         return const LocationResult.failed(
///             LocationFailure.serviceDisabled);
///       }
///
///       var permission = await Geolocator.checkPermission();
///
///       if (permission == LocationPermission.denied) {
///         permission = await Geolocator.requestPermission();
///       }
///
///       if (permission == LocationPermission.deniedForever) {
///         return const LocationResult.failed(
///             LocationFailure.permissionDeniedForever);
///       }
///
///       if (permission == LocationPermission.denied) {
///         return const LocationResult.failed(
///             LocationFailure.permissionDenied);
///       }
///
///       final position = await Geolocator.getCurrentPosition(
///         locationSettings: const LocationSettings(
///           accuracy: LocationAccuracy.high,
///           timeLimit: Duration(seconds: 12),
///         ),
///       );
///
///       return LocationResult.success(
///         LocationFix(
///           latitude: position.latitude,
///           longitude: position.longitude,
///           accuracy: position.accuracy,
///         ),
///       );
///     } catch (_) {
///       return const LocationResult.failed(LocationFailure.unavailable);
///     }
///   }
/// }
/// ```
///
/// 3. In `lib/providers/core_providers.dart`, change one line:
///
/// ```dart
/// final locationServiceProvider = Provider<LocationService>((ref) {
///   return GeolocatorLocationService();   // was NullLocationService()
/// });
/// ```
///
/// The Android manifest already declares ACCESS_FINE_LOCATION and
/// ACCESS_COARSE_LOCATION, so no manifest change is needed.
class NullLocationService implements LocationService {
  const NullLocationService();

  @override
  Future<LocationResult> currentPosition() async {
    return const LocationResult.failed(LocationFailure.notConfigured);
  }
}
