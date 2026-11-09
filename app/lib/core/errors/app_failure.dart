/// User-facing failure taxonomy (plan §12.5). Maps backend error codes to
/// copy that never blames the user and never over-promises safety.
enum FailureKind {
  network,
  rateLimited,
  outOfArea,
  routingUnavailable,
  unauthorized,
  validation,
  externalData,
  server,
  unknown,
}

class AppFailure implements Exception {
  AppFailure(this.kind, this.message, {this.reference});

  final FailureKind kind;
  final String message;
  final String? reference;

  factory AppFailure.fromStatus(int? status, String? code, String? message) {
    switch (code) {
      case 'RATE_LIMITED':
        return AppFailure(
          FailureKind.rateLimited,
          'Too many route checks from this device — try again shortly.',
        );
      case 'OUT_OF_SERVICE_AREA':
        return AppFailure(
          FailureKind.outOfArea,
          'NightWise is currently Bengaluru-only — you\'re outside our mapped area.',
        );
      case 'ROUTING_UNAVAILABLE':
        return AppFailure(
          FailureKind.routingUnavailable,
          'The routing engine is temporarily unavailable. Your last routes are still shown.',
        );
      case 'UNAUTHENTICATED':
      case 'AUTH_FAILED':
        return AppFailure(FailureKind.unauthorized, message ?? 'Sign in required.');
      case 'INVALID_BODY':
      case 'VALIDATION_ERROR':
        return AppFailure(FailureKind.validation, message ?? 'Please check the highlighted fields.');
      case 'EXTERNAL_DATA_ERROR':
        return AppFailure(
          FailureKind.externalData,
          'A data provider is not responding. Scores may be based on fewer signals right now.',
        );
      case 'GEOCODER_UNCONFIGURED':
        return AppFailure(
          FailureKind.externalData,
          'Place search is not configured on this server. You can still pick a destination on the map.',
        );
    }
    if (status == 401) return AppFailure(FailureKind.unauthorized, 'Sign in required.');
    if (status == 429) {
      return AppFailure(FailureKind.rateLimited, 'Too many requests — try again shortly.');
    }
    if (status != null && status >= 500) {
      return AppFailure(
        FailureKind.server,
        'The server hit a problem. Please try again.',
        reference: message,
      );
    }
    return AppFailure(FailureKind.unknown, message ?? 'Something went wrong.');
  }

  @override
  String toString() => message;
}
