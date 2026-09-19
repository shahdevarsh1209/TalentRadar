'use strict';

/**
 * Every failure the client is allowed to see. `code` is a stable machine string
 * the Flutter app switches on; `message` is already user-presentable, so the app
 * never has to invent copy and raw driver errors never reach a screen.
 */
class ApiError extends Error {
  constructor(status, code, message, details = undefined) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
    this.isApiError = true;
  }

  static badRequest(message, details) {
    return new ApiError(400, 'BAD_REQUEST', message, details);
  }

  static validation(message, details) {
    return new ApiError(422, 'VALIDATION_ERROR', message, details);
  }

  static unauthorized(message = 'Your session has expired. Please log in again.') {
    return new ApiError(401, 'UNAUTHORIZED', message);
  }

  static forbidden(message = 'You do not have access to this resource.') {
    return new ApiError(403, 'FORBIDDEN', message);
  }

  static notFound(message = 'We could not find what you were looking for.') {
    return new ApiError(404, 'NOT_FOUND', message);
  }

  static conflict(code, message, details) {
    return new ApiError(409, code, message, details);
  }

  static tooMany(message = 'Too many attempts. Please try again in a little while.') {
    return new ApiError(429, 'RATE_LIMITED', message);
  }

  static internal(message = 'Something went wrong on our side. Please try again.') {
    return new ApiError(500, 'SERVER_ERROR', message);
  }
}

module.exports = ApiError;
