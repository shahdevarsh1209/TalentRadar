/// Everything the UI needs to explain a failure, with no raw backend text.
///
/// [code] is the stable machine string the API returns (or one this client
/// invents for transport problems) and [message] is already presentable copy.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.status,
    this.fieldErrors = const {},
    this.details,
  });

  final String code;
  final String message;
  final int? status;

  /// Field name to message, so a form can highlight the offending inputs.
  final Map<String, String> fieldErrors;
  final Map<String, dynamic>? details;

  bool get isNetwork => code == 'NETWORK_UNAVAILABLE';
  bool get isTimeout => code == 'TIMEOUT';
  bool get isEmailTaken => code == 'EMAIL_EXISTS' || code == 'EMAIL_EXISTS_OTHER_ROLE';
  bool get isRoleConflict => code == 'EMAIL_EXISTS_OTHER_ROLE' || code == 'ROLE_MISMATCH';
  bool get isSessionExpired => code == 'UNAUTHORIZED';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isServiceDown => code == 'SERVICE_UNAVAILABLE' || code == 'SERVER_ERROR';

  /// Role the conflicting account already uses, when the API reported one.
  String? get existingRole => details?['existingRole'] as String?;

  factory ApiException.network() => ApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'You appear to be offline. Check your connection and try again.',
      );

  factory ApiException.timeout() => ApiException(
        code: 'TIMEOUT',
        message: 'That took longer than expected. Please try again.',
      );

  factory ApiException.unexpected() => ApiException(
        code: 'SERVER_ERROR',
        message: 'Something went wrong on our side. Please try again.',
      );

  @override
  String toString() => 'ApiException($code): $message';
}
