import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/device/device_identity.dart';
import '../core/local_store.dart';
import '../core/location/location_service.dart';
import '../core/network/connectivity_service.dart';
import '../core/secure_storage.dart';
import '../core/location/geolocator_location_service.dart';

/// Infrastructure singletons.
///
/// Keeping these in one file avoids import cycles: every feature provider
/// depends on these, and these depend on nothing but `core/`.

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// One Dio instance for the whole app, so the auth interceptor and the
/// token-refresh lock are shared across every repository.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(secureStorageProvider));
  ref.onDispose(() => client.raw.close(force: true));
  return client;
});

/// Hive-backed offline store (pending reading queue + consumer cache).
final localStoreProvider = Provider<LocalStore>((ref) {
  return LocalStore();
});

/// Stable per-install id, sent as `device_id` on the /sync/* routes.
final deviceIdentityProvider = Provider<DeviceIdentity>((ref) {
  return DeviceIdentity(ref.watch(secureStorageProvider));
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return PlatformConnectivityService();
});

/// GPS at capture time.
///
/// Currently a no-op: capturing a real fix needs the `geolocator` plugin,
/// which is a new dependency this project has not resolved yet. Everything
/// downstream of this provider is already wired, so enabling GPS is a
/// `flutter pub add geolocator` plus changing the line below to
/// `GeolocatorLocationService()`.
///
/// Full instructions are in the doc comment on [NullLocationService].
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});
