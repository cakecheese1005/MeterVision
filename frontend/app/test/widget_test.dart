// Contract and logic tests for the frontend <-> FastAPI mapping layer.
//
// These run without a backend and without a device:
//   flutter test
//
// They exist because the JSON contract is the part most likely to drift when
// the backend changes, and because the sync retry rules are the part most
// likely to lose a field officer's work if they regress.

import 'package:flutter_test/flutter_test.dart';

import 'package:metervision_app/core/api_client.dart';
import 'package:metervision_app/core/constants.dart';
import 'package:metervision_app/core/location/location_service.dart';
import 'package:metervision_app/models/auth_user.dart';
import 'package:metervision_app/models/consumer.dart';
import 'package:metervision_app/models/meter_reading_draft.dart';
import 'package:metervision_app/models/ocr_result.dart';
import 'package:metervision_app/services/image_service.dart';
import 'package:metervision_app/services/reading_repository.dart';

void main() {
  group('APIResponse envelope', () {
    // /auth/* wraps in APIResponse; /consumers, /readings, /images and /sync
    // return the bare model. ApiClient.unwrap has to cope with both.
    test('unwraps the /auth/* envelope', () {
      final body = {
        'success': true,
        'message': 'Login successful.',
        'data': {'access_token': 'abc'},
        'timestamp': '2026-01-01T00:00:00Z',
      };

      expect(ApiClient.asMap(body)['access_token'], 'abc');
    });

    test('passes through bare models from /readings and /consumers', () {
      final body = {'id': 'r1', 'reading_value': 42.0};
      expect(ApiClient.asMap(body)['id'], 'r1');
    });

    test('does not unwrap a model that merely has a `data` field', () {
      // Guards against over-eager unwrapping: the envelope needs BOTH keys.
      final body = {'id': 'r1', 'data': 'something'};
      expect(ApiClient.asMap(body)['id'], 'r1');
    });

    test('handles both bare lists and paginated {items: []}', () {
      expect(
        ApiClient.asList([
          {'id': 'c1'}
        ]).length,
        1,
      );

      expect(
        ApiClient.asList({
          'items': [
            {'id': 'c1'},
            {'id': 'c2'}
          ],
          'pagination': {'page': 1},
        }).length,
        2,
      );
    });

    test('a null body yields empty collections rather than throwing', () {
      expect(ApiClient.asMap(null), isEmpty);
      expect(ApiClient.asList(null), isEmpty);
    });
  });

  group('Consumer', () {
    test('maps every ConsumerResponse field', () {
      final consumer = Consumer.fromJson({
        'id': 'c1',
        'consumer_number': 'PSPCL-C-0001',
        'account_number': 'ACC-10001',
        'consumer_name': 'Harpreet Singh',
        'address': 'Model Town, Ludhiana',
        'meter_number': 'MTR-D-0001',
        'meter_type': 'electromechanical',
        'subdivision': 'Ludhiana Central',
      });

      expect(consumer.consumerNumber, 'PSPCL-C-0001');
      expect(consumer.accountNumber, 'ACC-10001');
      expect(consumer.meterType, MeterType.electroMechanical);
      expect(consumer.subdivision, 'Ludhiana Central');

      // Aliases the existing screens rely on.
      expect(consumer.name, 'Harpreet Singh');
      expect(consumer.consumerNo, 'ACC-10001');
      expect(consumer.displayReference, 'PSPCL-C-0001');
    });

    test('falls back to account number when consumer number is absent', () {
      final consumer = Consumer.fromJson({
        'id': 'c1',
        'account_number': 'ACC-10001',
        'consumer_name': 'X',
        'address': 'Y',
      });

      expect(consumer.displayReference, 'ACC-10001');
    });
  });

  group('MeterReadingDraft wire format', () {
    final draft = MeterReadingDraft(
      consumerId: 'c1',
      imagePath: '/tmp/meter.jpg',
      meterReading: '12345',
      meterType: MeterType.digital,
      capturedAt: DateTime.utc(2026, 1, 1, 10, 30),
      latitude: 30.33,
      longitude: 76.38,
      locationAvailable: true,
      ocrConfidence: 0.91,
    );

    test('ReadingCreate carries exactly the five fields the backend accepts',
        () {
      final json = draft.toCreateJson();

      expect(
        json.keys.toSet(),
        {
          'consumer_id',
          'reading_value',
          'latitude',
          'longitude',
          'captured_at',
        },
      );

      // Derived from the JWT server-side - sending it would be ignored at best.
      expect(json.containsKey('officer_id'), isFalse);

      // Not columns on meter_readings; kept local only.
      expect(json.containsKey('meter_type'), isFalse);
      expect(json.containsKey('ocr_confidence'), isFalse);
    });

    test('reading_value is numeric, not a string', () {
      expect(draft.toCreateJson()['reading_value'], isA<double>());
      expect(draft.toCreateJson()['reading_value'], 12345.0);
    });

    test('captured_at is UTC ISO-8601', () {
      expect(draft.toCreateJson()['captured_at'], '2026-01-01T10:30:00.000Z');
    });

    test('thousands separators in a typed reading are tolerated', () {
      final messy = draft.copyWith(meterReading: '12,345');
      expect(messy.readingValue, 12345.0);
    });

    test('a missing GPS fix serialises as 0.0 but is flagged locally', () {
      // ReadingCreate.latitude/longitude are non-optional floats, so 0.0 is
      // the only thing that can be sent. locationAvailable is what stops that
      // being mistaken for a real coordinate off the coast of Africa.
      final noFix = MeterReadingDraft(
        consumerId: 'c1',
        imagePath: '/tmp/a.jpg',
        meterReading: '1',
        meterType: MeterType.digital,
        capturedAt: DateTime.utc(2026, 1, 1),
      );

      expect(noFix.locationAvailable, isFalse);
      expect(noFix.toCreateJson()['latitude'], 0.0);
      expect(noFix.toCreateJson()['longitude'], 0.0);

      // And the flag survives a queue round-trip, so the sync screen can still
      // warn about it days later.
      expect(
        MeterReadingDraft.fromJson(noFix.toJson()).locationAvailable,
        isFalse,
      );
    });

    test('round-trips through the Hive queue format', () {
      final restored = MeterReadingDraft.fromJson(
        draft.copyWith(localId: 'local-1').toJson(),
      );

      expect(restored.localId, 'local-1');
      expect(restored.meterType, MeterType.digital);
      expect(restored.readingValue, 12345.0);
      expect(restored.syncStatus, SyncStatus.pending);
      expect(restored.locationAvailable, isTrue);
      expect(restored.ocrConfidence, 0.91);
    });

    test('copyWith clears lastError and nextAttemptAt only when asked', () {
      final failed = draft.copyWith(
        lastError: 'boom',
        nextAttemptAt: DateTime(2026, 1, 1),
      );

      // An unrelated copyWith must not silently wipe them.
      expect(failed.copyWith(retryCount: 2).lastError, 'boom');
      expect(failed.copyWith(retryCount: 2).nextAttemptAt, isNotNull);

      expect(failed.copyWith(clearLastError: true).lastError, isNull);
      expect(failed.copyWith(clearNextAttempt: true).nextAttemptAt, isNull);
    });
  });

  group('Sync retry policy', () {
    MeterReadingDraft draftWith({
      int retryCount = 0,
      SyncStatus status = SyncStatus.pending,
      DateTime? nextAttemptAt,
    }) {
      return MeterReadingDraft(
        consumerId: 'c1',
        imagePath: '/tmp/a.jpg',
        meterReading: '100',
        meterType: MeterType.digital,
        capturedAt: DateTime.utc(2026, 1, 1),
        localId: 'l1',
        retryCount: retryCount,
        syncStatus: status,
        nextAttemptAt: nextAttemptAt,
      );
    }

    test('backoff grows exponentially and is capped at 30 minutes', () {
      expect(MeterReadingDraft.backoffFor(0), const Duration(minutes: 1));
      expect(MeterReadingDraft.backoffFor(1), const Duration(minutes: 2));
      expect(MeterReadingDraft.backoffFor(2), const Duration(minutes: 4));
      expect(MeterReadingDraft.backoffFor(4), const Duration(minutes: 16));
      expect(MeterReadingDraft.backoffFor(9), const Duration(minutes: 30));
    });

    test('a draft inside its backoff window is not eligible', () {
      final now = DateTime(2026, 1, 1, 12, 0);

      final waiting = draftWith(
        retryCount: 1,
        status: SyncStatus.failed,
        nextAttemptAt: now.add(const Duration(minutes: 5)),
      );

      expect(waiting.isEligible(now), isFalse);
      expect(
        waiting.isEligible(now.add(const Duration(minutes: 6))),
        isTrue,
      );
    });

    test('a draft with no scheduled time is eligible immediately', () {
      expect(draftWith().isEligible(DateTime.now()), isTrue);
    });

    test('dead-lettering matches the backend MAX_SYNC_RETRIES', () {
      expect(ApiConstants.maxSyncRetries, 5);

      final exhausted = draftWith(
        retryCount: ApiConstants.maxSyncRetries,
        status: SyncStatus.failed,
      );

      expect(exhausted.isDeadLettered, isTrue);
      // Dead-lettered drafts stop retrying but are never auto-discarded.
      expect(exhausted.isEligible(DateTime.now()), isFalse);
    });

    test('a pending draft is never dead-lettered, however many retries', () {
      final pending = draftWith(retryCount: 99);
      expect(pending.isDeadLettered, isFalse);
    });

    test('resume state distinguishes reading-created from fully-synced', () {
      final base = draftWith();
      expect(base.awaitingImageOnly, isFalse);
      expect(base.isComplete, isFalse);

      final created = base.copyWith(readingId: 'r1');
      expect(created.awaitingImageOnly, isTrue);
      expect(created.isComplete, isFalse);

      final done = created.copyWith(imageId: 'i1');
      expect(done.awaitingImageOnly, isFalse);
      expect(done.isComplete, isTrue);
    });
  });

  group('Enums match the backend', () {
    test('reading status', () {
      expect(ReadingStatusX.fromWire('completed'), ReadingStatus.completed);
      expect(ReadingStatusX.fromWire('review'), ReadingStatus.review);
      expect(ReadingStatus.completed.wireValue, 'completed');
    });

    test('sync status uses success, not synced', () {
      expect(SyncStatusX.fromWire('success'), SyncStatus.success);
      expect(SyncStatus.success.wireValue, 'success');
    });

    test('meter type uses electromechanical on the wire', () {
      expect(MeterType.electroMechanical.wireValue, 'electromechanical');
      expect(MeterType.digital.wireValue, 'digital');
    });

    test('image quality maps and flags recapture', () {
      expect(ImageQualityX.fromWire('ok'), ImageQuality.ok);
      expect(ImageQualityX.fromWire('blur'), ImageQuality.blur);
      expect(ImageQualityX.fromWire('nonsense'), isNull);

      expect(ImageQuality.ok.needsRecapture, isFalse);
      expect(ImageQuality.blur.needsRecapture, isTrue);
      expect(ImageQuality.irrelevant.needsRecapture, isTrue);
    });

    test('user roles', () {
      expect(UserRoleX.fromWire('admin'), UserRole.admin);
      expect(UserRoleX.fromWire('lcr'), UserRole.lcr);
      expect(UserRoleX.fromWire('officer'), UserRole.officer);
    });
  });

  group('AuthUser', () {
    test('accepts user_id from login and id from /auth/me', () {
      expect(AuthUser.fromJson({'user_id': 'u1', 'role': 'officer'}).id, 'u1');
      expect(AuthUser.fromJson({'id': 'u1', 'role': 'admin'}).role,
          UserRole.admin);
    });

    test('only officers are field-app users', () {
      expect(AuthUser.fromJson({'id': 'u', 'role': 'officer'}).isOfficer,
          isTrue);
      expect(
          AuthUser.fromJson({'id': 'u', 'role': 'admin'}).isOfficer, isFalse);
      expect(AuthUser.fromJson({'id': 'u', 'role': 'lcr'}).isOfficer, isFalse);
    });
  });

  group('UploadedImage', () {
    test('maps ImageUploadResponse', () {
      final image = UploadedImage.fromJson({
        'image_id': 'i1',
        'image_url': 'https://example.test/a.jpg',
        'blur_score': 100.0,
        'quality': 'ok',
        'classification': 'Image Okay Digital Meter',
      });

      expect(image.imageId, 'i1');
      expect(image.quality, ImageQuality.ok);
      expect(image.needsRecapture, isFalse);
      expect(image.blurScore, 100.0);
    });

    test('a null upload response yields an empty image id', () {
      // The guard in ApiImageService turns exactly this into an exception, so
      // that a stubbed or failing endpoint can never be read as success and
      // cause the queued photo to be deleted.
      final image = UploadedImage.fromJson(ApiClient.asMap(null));
      expect(image.imageId, isEmpty);
    });

    test('a blurred verdict asks for a retake', () {
      final image = UploadedImage.fromJson({
        'image_id': 'i1',
        'image_url': 'u',
        'quality': 'blur',
      });

      expect(image.needsRecapture, isTrue);
    });
  });

  group('SubmittedReading', () {
    test('maps ReadingResponse including the server-computed units', () {
      final reading = SubmittedReading.fromJson({
        'id': 'r1',
        'consumer_id': 'c1',
        'officer_id': 'o1',
        'reading_value': 12500.0,
        'previous_reading': 12450.0,
        'units_consumed': 50.0,
        'status': 'pending',
        'created_at': '2026-01-01T10:30:00Z',
      });

      expect(reading.id, 'r1');
      expect(reading.previousReading, 12450.0);
      expect(reading.unitsConsumed, 50.0);
      expect(reading.hasUnits, isTrue);
      expect(reading.status, ReadingStatus.pending);
    });

    test('a first-ever reading has no previous value', () {
      final reading = SubmittedReading.fromJson({
        'id': 'r1',
        'reading_value': 100.0,
        'status': 'pending',
      });

      expect(reading.previousReading, isNull);
      expect(reading.hasUnits, isFalse);
    });
  });

  group('SubmitOutcome', () {
    test('offline queueing is reported as such, not as an error', () {
      const outcome = SubmitOutcome(queuedOffline: true);
      expect(outcome.isFullySynced, isFalse);
      expect(outcome.headline, 'Saved offline');
    });

    test('reading accepted but photo pending is distinguishable', () {
      const outcome = SubmitOutcome(imagePending: true);
      expect(outcome.isFullySynced, isFalse);
      expect(outcome.detail, contains('photo will upload'));
    });
  });

  group('OcrResult', () {
    test('low-confidence threshold matches settings.OCR_LOW_CONFIDENCE', () {
      expect(OcrResult.lowConfidenceThreshold, 0.70);

      const low = OcrResult(extractedReading: '1', confidenceScore: 0.69);
      const ok = OcrResult(extractedReading: '1', confidenceScore: 0.71);

      expect(low.requiresManualReview, isTrue);
      expect(ok.requiresManualReview, isFalse);
    });

    test('accepts the backend predicted_reading/confidence field names', () {
      final result = OcrResult.fromJson({
        'id': 'o1',
        'reading_id': 'r1',
        'predicted_reading': '12345',
        'confidence': 0.93,
        'status': 'success',
        'model_version': 'digit-reader-v1',
        'classification': 'Image OK — Digital Meter',
        'processing_time_ms': 4200,
        'processed_at': '2026-01-01T10:30:00Z',
      });

      expect(result.id, 'o1');
      expect(result.extractedReading, '12345');
      expect(result.confidenceScore, 0.93);
      expect(result.isSuccess, isTrue);
      expect(result.processedAt, isNotNull);
      expect(result.isStub, isFalse);
    });

    test('reads processed_at, the renamed timestamp column', () {
      // OCRResultResponse used to expose `created_at`; the column is and
      // always was `processed_at`. Both are accepted, processed_at wins.
      final result = OcrResult.fromJson({
        'predicted_reading': '1',
        'confidence': 0.9,
        'processed_at': '2026-02-02T08:00:00Z',
      });

      expect(result.processedAt!.toUtc().month, 2);
    });

    test('verified status is recognised', () {
      final result = OcrResult.fromJson({
        'predicted_reading': '999',
        'confidence': 0.5,
        'status': 'verified',
        'verification_remarks': 'Officer confirmed from the meter.',
      });

      expect(result.isVerified, isTrue);
      expect(result.verificationRemarks, isNotNull);
    });

    test('reading comparison ignores padding and separators', () {
      const result = OcrResult(extractedReading: '012345', confidenceScore: 1);

      expect(result.matches('12345'), isTrue);
      expect(result.matches('12,345'), isTrue);
      expect(result.matches(' 12345 '), isTrue);
      expect(result.matches('12346'), isFalse);
      expect(result.matches(''), isFalse);
    });

    test('auto-apply needs far more confidence than success does', () {
      // 0.70 only means the server labels it `success`. Overwriting a human
      // meter reading for billing needs 0.95.
      const success = OcrResult(extractedReading: '1', confidenceScore: 0.80);
      const confident = OcrResult(extractedReading: '1', confidenceScore: 0.96);
      const empty = OcrResult(extractedReading: '', confidenceScore: 0.99);

      expect(success.requiresManualReview, isFalse);
      expect(success.isAutoApplyConfident, isFalse);
      expect(confident.isAutoApplyConfident, isTrue);
      expect(empty.isAutoApplyConfident, isFalse);
    });
  });

  group('LocationResult', () {
    test('a fix is reported with coordinates', () {
      const result = LocationResult.success(
        LocationFix(latitude: 30.9, longitude: 75.85),
      );

      expect(result.hasFix, isTrue);
      expect(result.fix!.latitude, 30.9);
      expect(result.message, isEmpty);
    });

    test('each failure explains itself to the officer', () {
      for (final failure in LocationFailure.values) {
        final result = LocationResult.failed(failure);
        expect(result.hasFix, isFalse);
        expect(result.message, isNotEmpty);
      }
    });

    test('the default service reports that GPS is not configured', () async {
      final result = await const NullLocationService().currentPosition();
      expect(result.hasFix, isFalse);
      expect(result.failure, LocationFailure.notConfigured);
    });
  });
}