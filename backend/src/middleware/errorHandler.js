'use strict';

const env = require('../config/env');
const ApiError = require('../utils/ApiError');

function notFoundHandler(req, res, next) {
  next(ApiError.notFound(`No route matches ${req.method} ${req.originalUrl}`));
}

/**
 * Translates anything thrown anywhere into the single response envelope. Driver
 * and validation internals are mapped to friendly copy — never forwarded.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let error = err;

  if (!error.isApiError) {
    if (error.name === 'ValidationError' && error.errors) {
      const details = Object.entries(error.errors).map(([field, detail]) => ({
        field,
        message: detail.message,
      }));
      error = ApiError.validation('Please check the highlighted fields.', details);
    } else if (error.code === 11000) {
      error = ApiError.conflict(
        'EMAIL_EXISTS',
        'An account already exists with this email.'
      );
    } else if (error.name === 'CastError') {
      error = ApiError.badRequest('That request referenced something we could not read.');
    } else if (error.name === 'MongooseServerSelectionError' || error.name === 'MongoNetworkError') {
      error = new ApiError(503, 'SERVICE_UNAVAILABLE', 'We could not reach our servers. Please try again.');
    } else {
      error = ApiError.internal();
    }
  }

  if (error.status >= 500) {
    console.error('[error]', err);
  }

  res.status(error.status).json({
    success: false,
    error: {
      code: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
      ...(env.nodeEnv === 'development' && error.status >= 500 ? { debug: err.message } : {}),
    },
  });
}

module.exports = { errorHandler, notFoundHandler };
