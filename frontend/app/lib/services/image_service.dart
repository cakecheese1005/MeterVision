import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/constants.dart';

/// Result of `POST /images/upload` (`app.models.image.ImageUploadResponse`).
///
/// Backend declares every field as required:
///   image_id, image_url, blur_score, quality, classification
class UploadedImage {
  final String imageId;
  final String imageUrl;
  final double? blurScore;
  final ImageQuality? quality;

  /// `app.models.enums.AIClassification` - a long human-readable string such
  /// as "Image Okay Digital Meter". Kept as a raw string because the client
  /// only displays it; it never branches on the value.
  final String? classification;

  const UploadedImage({
    required this.imageId,
    required this.imageUrl,
    this.blurScore,
    this.quality,
    this.classification,
  });

  /// The backend's blur/relevance check rejected the photo - the officer
  /// should be asked to retake it.
  ///
  /// Currently always false: `ImageService.upload_image` hardcodes
  /// `image_quality = "ok"` because the blur/YOLO pipeline is not wired up.
  /// The handling path is here so it works the day it is.
  bool get needsRecapture => quality?.needsRecapture ?? false;

  factory UploadedImage.fromJson(Map<String, dynamic> json) {
    return UploadedImage(
      imageId: (json['image_id'] ?? json['id'])?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      blurScore: (json['blur_score'] as num?)?.toDouble(),
      quality: ImageQualityX.fromWire(json['quality']?.toString()),
      classification: json['classification']?.toString(),
    );
  }
}

abstract class ImageService {
  Future<UploadedImage> uploadImage({
    required String readingId,
    required String filePath,
    required double latitude,
    required double longitude,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}

/// multipart/form-data upload.
///
/// The router signature is:
///   reading_id: str        = Form(...)
///   latitude:   float      = Form(...)
///   longitude:  float      = Form(...)
///   file:       UploadFile = File(...)
///
/// All four are required - sending JSON, or omitting latitude/longitude,
/// returns 422.
class ApiImageService implements ImageService {
  final ApiClient _client;

  ApiImageService(this._client);

  @override
  Future<UploadedImage> uploadImage({
    required String readingId,
    required String filePath,
    required double latitude,
    required double longitude,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Captured image is missing at $filePath',
      );
    }

    // Fail fast rather than spending three minutes of a field officer's
    // mobile data uploading something the server will reject outright.
    final sizeBytes = await file.length();
    final maxBytes = ApiConstants.maxImageSizeMb * 1024 * 1024;

    if (sizeBytes > maxBytes) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Image is ${(sizeBytes / 1048576).toStringAsFixed(1)} MB. '
            'The server accepts up to ${ApiConstants.maxImageSizeMb} MB.',
      );
    }

    final formData = FormData.fromMap({
      'reading_id': readingId,
      'latitude': latitude,
      'longitude': longitude,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[/\\]')).last,
        contentType: MediaType('image', 'jpeg'),
      ),
    });

    final raw = await _client.postMultipart(
      ApiConstants.imagesUpload,
      formData: formData,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );

    final uploaded = UploadedImage.fromJson(ApiClient.asMap(raw));

    // ---------------------------------------------------------------
    // Do not trust a 200 alone.
    //
    // An earlier revision of the backend had `upload_image` as an unimplemented
    // stub returning None, which FastAPI serialised as `null` with HTTP 200.
    // That flowed through asMap -> {} -> imageId: '' with no exception, the
    // caller read it as success, and the draft was dropped from the offline
    // queue - destroying the meter photo silently.
    //
    // The service is implemented now and the route declares
    // response_model=ImageUploadResponse, so this should not recur. The guard
    // stays because the cost of being wrong here is a lost photo with no trace,
    // and one comparison is cheap insurance against any future regression.
    // ---------------------------------------------------------------
    if (uploaded.imageId.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'The server accepted the upload but returned no image id. '
            'The photo has been kept and will be retried.',
      );
    }

    return uploaded;
  }
}
