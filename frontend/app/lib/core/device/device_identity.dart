import 'package:uuid/uuid.dart';

import '../secure_storage.dart';

/// Stable per-install identifier, sent as the `device_id` query parameter on
/// `POST /sync/` and `POST /sync/bulk`.
///
/// The backend column is `sync_queue.device_id VARCHAR(100)` (migration 010).
/// Until this was wired up the router never forwarded a value, so every row
/// was written with a null device_id and there was no way to tell which
/// handset a queued reading came from.
///
/// Generated once on first use and persisted in secure storage. It is
/// deliberately NOT a hardware identifier (IMEI, Android ID, advertising ID):
/// those are privacy-sensitive, require extra permissions on modern Android,
/// and are not needed here. All the backend needs is a value that is stable
/// for one install and distinct between handsets.
///
/// Consequence: reinstalling the app produces a new device id. That is the
/// correct trade-off - the local Hive queue is wiped on reinstall too, so
/// there is nothing left to correlate.
class DeviceIdentity {
  final SecureStorage _storage;
  final Uuid _uuid;

  String? _cached;

  DeviceIdentity(this._storage, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String> deviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    final existing = await _storage.readDeviceId();

    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final generated = _uuid.v4();
    await _storage.saveDeviceId(generated);
    _cached = generated;
    return generated;
  }
}
