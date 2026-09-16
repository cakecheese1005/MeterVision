import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'api_exception.dart';
import 'constants.dart';
import 'secure_storage.dart';

/// The only place in the app that knows Dio exists.
///
/// Screens -> Providers -> Repositories -> ApiClient -> Dio -> FastAPI
///
/// Responsibilities:
///  * base URL + JSON headers
///  * attach `Authorization: Bearer <access_token>` automatically
///  * transparently refresh an expired access token once, then retry
///  * unwrap the backend `APIResponse` envelope
///  * translate `DioException` into a typed [ApiException]
class ApiClient {
  final Dio _dio;

  /// Separate Dio without interceptors — used for the refresh call so a
  /// failing refresh cannot recurse back into the 401 handler.
  final Dio _refreshDio;

  final SecureStorage _storage;

  /// Invoked when the session is unrecoverable (refresh failed / no refresh
  /// token). AuthNotifier hooks into this to drop the user back to login.
  Future<void> Function()? onSessionExpired;

  /// Guards against a stampede: if ten requests 401 at once we only want a
  /// single refresh round-trip, with the rest awaiting its result.
  Future<bool>? _refreshInFlight;

  ApiClient({
    SecureStorage? storage,
    String? baseUrl,
    Dio? dio,
    Dio? refreshDio,
  })  : _storage = storage ?? SecureStorage(),
        _dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    final options = BaseOptions(
      baseUrl: baseUrl ?? ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      // We inspect status codes ourselves so 4xx/5xx reach onError with a body.
      validateStatus: (status) => status != null && status < 400,
    );

    _dio.options = options;
    _refreshDio.options = BaseOptions(
      baseUrl: options.baseUrl,
      connectTimeout: options.connectTimeout,
      receiveTimeout: options.receiveTimeout,
      headers: Map<String, dynamic>.from(options.headers),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );

    // Debug builds only. `logPrint` is routed through `debugPrint` so long
    // bodies are throttled rather than dropped by the platform log buffer.
    //
    // requestBody is deliberately OFF: POST /auth/login carries a plaintext
    // password and it must never reach a log, not even in debug.
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
  }

  Dio get raw => _dio;

  // =================================================================
  // Interceptors
  // =================================================================

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicEndpoint(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;

    final isRetryable = status == 401 &&
        !_isPublicEndpoint(path) &&
        error.requestOptions.extra['__retried__'] != true;

    if (!isRetryable) {
      return handler.next(error);
    }

    final refreshed = await _refreshToken();

    if (!refreshed) {
      await _storage.clear();
      await onSessionExpired?.call();
      return handler.next(error);
    }

    try {
      final token = await _storage.readAccessToken();
      final options = error.requestOptions;

      options.extra['__retried__'] = true;
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';

      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// POST /auth/refresh — single-flight.
  Future<bool> _refreshToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
      );

      final data = unwrap(response.data);

      if (data is! Map) return false;

      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;

      if (access == null || refresh == null) return false;

      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isPublicEndpoint(String path) {
    return path.contains(ApiConstants.login) ||
        path.contains(ApiConstants.authRefresh) ||
        path.contains(ApiConstants.authRegister);
  }

  // =================================================================
  // Envelope handling
  // =================================================================

  /// The backend is *not* uniform:
  ///
  ///  * `/auth/*` returns `{success, message, data, timestamp}`
  ///  * `/readings`, `/consumers`, `/sync`, `/images` return the bare model
  ///
  /// So we unwrap only when the envelope is actually present, and pass
  /// everything else straight through.
  static dynamic unwrap(dynamic body) {
    if (body is Map<String, dynamic> &&
        body.containsKey('success') &&
        body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// Normalises list payloads, tolerating the paginated
  /// `{items: [...], pagination: {...}}` shape from `responses.paginated`.
  static List<Map<String, dynamic>> asList(dynamic payload) {
    final data = unwrap(payload);

    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    }

    return const [];
  }

  static Map<String, dynamic> asMap(dynamic payload) {
    final data = unwrap(payload);
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // =================================================================
  // Verbs
  // =================================================================

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  /// [receiveTimeout] overrides the client default for slow endpoints.
  /// `POST /ocr/process/{image_id}` runs EasyOCR plus a MobileNet digit model
  /// on CPU, which routinely exceeds the 30s default on modest hardware.
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );
      return response.data;
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(path, data: body, cancelToken: cancelToken);
      return response.data;
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<dynamic> delete(String path, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.delete(path, cancelToken: cancelToken);
      return response.data;
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  /// multipart/form-data — used by `POST /images/upload`.
  /// Content-Type is deliberately left to Dio so the boundary is generated.
  ///
  /// Timeouts are overridden here: the default 30s send timeout is fine for a
  /// JSON body but not for a meter photo on a rural 2G/3G link, where an
  /// upload that would have succeeded gets cancelled mid-flight and lands the
  /// draft back in the retry queue for no reason.
  Future<dynamic> postMultipart(
    String path, {
    required FormData formData,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  // =================================================================
  // Error mapping
  // =================================================================

  /// FastAPI raises `HTTPException(detail=ErrorResponse(...))`, so the body is
  ///   `{"detail": {"success": false, "status_code": 404, "message": "..."}}`
  /// while request-validation failures produce
  ///   `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}`
  /// Both are handled here.
  static ApiException mapError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'Request timed out.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          type: ApiErrorType.cancelled,
          message: 'Request cancelled.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Unable to reach the server.',
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const ApiException(
            type: ApiErrorType.network,
            message: 'Unable to reach the server.',
          );
        }
        break;
      default:
        break;
    }

    final status = error.response?.statusCode;
    final parsed = _parseErrorBody(error.response?.data);

    final message = parsed.$1 ?? _defaultMessageFor(status);
    final errors = parsed.$2;

    return ApiException(
      type: _typeFor(status),
      message: message,
      statusCode: status,
      errors: errors,
    );
  }

  static (String?, List<String>?) _parseErrorBody(dynamic body) {
    if (body is! Map) return (null, null);

    final detail = body['detail'];

    // ErrorResponse dict
    if (detail is Map) {
      final msg = detail['message'];
      final errs = detail['errors'];
      return (
        msg is String ? msg : null,
        errs is List ? errs.map((e) => e.toString()).toList() : null,
      );
    }

    // Pydantic validation errors
    if (detail is List) {
      final messages = detail
          .whereType<Map>()
          .map((e) => e['msg']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return (messages.isEmpty ? null : messages.first, messages);
    }

    if (detail is String) return (detail, null);

    if (body['message'] is String) return (body['message'] as String, null);

    return (null, null);
  }

  static ApiErrorType _typeFor(int? status) {
    switch (status) {
      case 400:
        return ApiErrorType.validation;
      case 401:
        return ApiErrorType.unauthorized;
      case 403:
        return ApiErrorType.forbidden;
      case 404:
        return ApiErrorType.notFound;
      case 409:
        return ApiErrorType.conflict;
      case 422:
        return ApiErrorType.validation;
      default:
        if (status != null && status >= 500) return ApiErrorType.server;
        return ApiErrorType.unknown;
    }
  }

  static String _defaultMessageFor(int? status) {
    if (status == null) return 'Something went wrong.';
    if (status >= 500) return 'Server error ($status).';
    return 'Request failed ($status).';
  }
}