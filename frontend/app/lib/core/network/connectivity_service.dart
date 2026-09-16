import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus.
///
/// Exists for two reasons:
///
///  1. `onConnectivityChanged` only fires on *transitions*. Watching it alone
///     means the app does not know whether it is online until something
///     changes - which, on a device that launches already-online and stays
///     that way, is never. [stream] therefore seeds the current state first.
///
///  2. It keeps `Connectivity()` out of the providers so the whole sync
///     subsystem can be tested with a fake.
///
/// "Online" here means *a transport is active*, not *the server is reachable*.
/// The real reachability check is the sync request itself failing with
/// [ApiErrorType.network].
abstract class ConnectivityService {
  /// Emits the current state immediately, then every subsequent change.
  Stream<bool> get stream;

  /// One-shot check, for callers that just need to know right now.
  Future<bool> isOnline();
}

class PlatformConnectivityService implements ConnectivityService {
  final Connectivity _connectivity;

  PlatformConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  /// connectivity_plus 6.x reports a *list* of active transports.
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Stream<bool> get stream async* {
    // Seed with the current state so subscribers are not left in the dark
    // until the first transition.
    try {
      yield _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      // Platform channel unavailable (e.g. in tests) - assume online and let
      // the request itself decide.
      yield true;
    }

    yield* _connectivity.onConnectivityChanged.map(_isOnline);
  }

  @override
  Future<bool> isOnline() async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      return true;
    }
  }
}
