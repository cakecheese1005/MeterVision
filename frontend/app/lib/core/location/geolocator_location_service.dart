import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(
            LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(
            LocationFailure.permissionDeniedForever);
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(
            LocationFailure.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return LocationResult.success(
        LocationFix(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    } catch (_) {
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }
}