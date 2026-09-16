/// Transport-agnostic error type.
///
/// Repositories throw [ApiException]; providers map it to UI state.
/// Nothing above this layer should ever need to import Dio.
enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  server,
  cancelled,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final List<String>? errors;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.errors,
  });

  /// True when the failure is connectivity-related, i.e. the caller should
  /// fall back to the local Hive cache / offline queue rather than surface
  /// a hard error to the officer in the field.
  bool get isNetworkFailure =>
      type == ApiErrorType.network || type == ApiErrorType.timeout;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  /// Message safe to render directly in a SnackBar or error card.
  String get displayMessage {
    switch (type) {
      case ApiErrorType.network:
        return 'No internet connection. Working offline.';
      case ApiErrorType.timeout:
        return 'The server took too long to respond. Please retry.';
      case ApiErrorType.unauthorized:
        return 'Your session has expired. Please log in again.';
      case ApiErrorType.forbidden:
        return 'You do not have permission to perform this action.';
      case ApiErrorType.server:
        return 'Server error. Please try again shortly.';
      default:
        return message;
    }
  }

  @override
  String toString() => displayMessage;
}
