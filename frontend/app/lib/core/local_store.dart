import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/consumer.dart';
import '../models/meter_reading_draft.dart';
import 'constants.dart';

/// Offline-first storage on top of Hive.
///
/// Values are stored as JSON strings rather than TypeAdapters so the schema can
/// evolve with the backend without regenerating adapters (no build_runner step
/// required for these boxes).
///
/// Call [init] once from `main()` before `runApp`.
class LocalStore {
  static Future<void> init() async {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox<String>(HiveBoxes.pendingReadings),
      Hive.openBox<String>(HiveBoxes.consumersCache),
      Hive.openBox<String>(HiveBoxes.authBox),
    ]);
  }

  Box<String> get _pending => Hive.box<String>(HiveBoxes.pendingReadings);
  Box<String> get _consumers => Hive.box<String>(HiveBoxes.consumersCache);

  // =================================================================
  // Pending readings queue
  // =================================================================

  /// Inserts or replaces a draft, keyed by its localId.
  Future<void> upsertPendingReading(MeterReadingDraft draft) async {
    final key = draft.localId;
    if (key == null || key.isEmpty) return;
    await _pending.put(key, jsonEncode(draft.toJson()));
  }

  List<MeterReadingDraft> getPendingReadings() {
    final drafts = <MeterReadingDraft>[];

    for (final key in _pending.keys) {
      final raw = _pending.get(key);
      if (raw == null) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          drafts.add(MeterReadingDraft.fromJson(decoded));
        }
      } catch (_) {
        // Corrupt entry - drop it rather than blocking the whole queue.
        _pending.delete(key);
      }
    }

    drafts.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return drafts;
  }

  /// A single draft by its client-side id, or null if it is gone.
  MeterReadingDraft? getPendingReading(String localId) {
    final raw = _pending.get(localId);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MeterReadingDraft.fromJson(decoded);
      }
    } catch (_) {
      _pending.delete(localId);
    }

    return null;
  }

  /// Only the items still awaiting upload.
  List<MeterReadingDraft> getUnsyncedReadings() {
    return getPendingReadings()
        .where((d) => d.syncStatus != SyncStatus.success)
        .toList();
  }

  /// Everything still queued, including drafts that have exhausted their
  /// retries — those still need the officer's attention, so they belong in
  /// the badge count.
  int get pendingCount => getUnsyncedReadings().length;

  /// Drafts that will not be retried automatically any more.
  int get deadLetterCount =>
      getUnsyncedReadings().where((d) => d.isDeadLettered).length;

  Future<void> removePendingReading(String localId) async {
    await _pending.delete(localId);
  }

  Future<void> clearPendingReadings() async => _pending.clear();

  /// Reactive stream for the sync screen / badge counts.
  Stream<BoxEvent> watchPendingReadings() => _pending.watch();

  // =================================================================
  // Consumer cache (read-through, so the list still renders offline)
  // =================================================================

  Future<void> cacheConsumers(List<Consumer> consumers) async {
    await _consumers.clear();

    await _consumers.putAll({
      for (final c in consumers) c.id: jsonEncode(c.toJson()),
    });
  }

  List<Consumer> getCachedConsumers() {
    final result = <Consumer>[];

    for (final key in _consumers.keys) {
      final raw = _consumers.get(key);
      if (raw == null) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          result.add(Consumer.fromJson(decoded));
        }
      } catch (_) {
        _consumers.delete(key);
      }
    }

    return result;
  }

  bool get hasCachedConsumers => _consumers.isNotEmpty;

  Future<void> clearAll() async {
    await Future.wait([
      _pending.clear(),
      _consumers.clear(),
    ]);
  }
}
