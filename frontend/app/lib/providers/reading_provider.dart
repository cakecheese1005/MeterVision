import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/meter_reading_draft.dart';
import '../services/image_service.dart';
import '../services/reading_repository.dart';
import 'core_providers.dart';

final imageServiceProvider = Provider<ImageService>((ref) {
  return ApiImageService(ref.watch(apiClientProvider));
});

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  return ApiReadingRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
    ref.watch(imageServiceProvider),
    ref.watch(connectivityServiceProvider),
  );
});

/// Tracks the submit action so the Submit screen can show a spinner, disable
/// the button mid-submit, and then report what actually happened.
///
/// The value type is [SubmitOutcome] rather than `void`: the backend returns
/// `previous_reading` and `units_consumed` on `POST /readings/create`, and
/// discarding those meant the officer got no confirmation of what was recorded.
class SubmitReadingNotifier extends StateNotifier<AsyncValue<SubmitOutcome?>> {
  final ReadingRepository _repository;

  SubmitReadingNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> submit(MeterReadingDraft draft) async {
    state = const AsyncValue.loading();

    try {
      final outcome = await _repository.submitReading(draft);
      if (!mounted) return;
      state = AsyncValue.data(outcome);
    } on ApiException catch (e, st) {
      if (!mounted) return;

      // A network failure is not an error here: the repository has queued the
      // draft locally, so the officer gets the normal success path and the
      // reading syncs later.
      if (e.isNetworkFailure) {
        state = const AsyncValue.data(SubmitOutcome(queuedOffline: true));
      } else {
        state = AsyncValue.error(e, st);
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final submitReadingProvider = StateNotifierProvider.autoDispose<
    SubmitReadingNotifier, AsyncValue<SubmitOutcome?>>((ref) {
  return SubmitReadingNotifier(ref.read(readingRepositoryProvider));
});