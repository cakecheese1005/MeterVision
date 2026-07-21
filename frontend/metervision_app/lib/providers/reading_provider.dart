import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meter_reading_draft.dart';
import '../services/reading_repository.dart';

/// Swap this one line for the Hive-backed implementation later —
/// screens never change.
final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  return InMemoryReadingRepository();
});

/// Tracks the submit action itself (idle/loading/success/error) so the
/// Submit screen can show a spinner and disable the button mid-submit.
class SubmitReadingNotifier extends StateNotifier<AsyncValue<void>> {
  final ReadingRepository _repository;
  SubmitReadingNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> submit(MeterReadingDraft draft) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitReading(draft);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final submitReadingProvider =
    StateNotifierProvider.autoDispose<SubmitReadingNotifier, AsyncValue<void>>((ref) {
  return SubmitReadingNotifier(ref.read(readingRepositoryProvider));
});