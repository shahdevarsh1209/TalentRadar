'use strict';

const ApiError = require('../utils/ApiError');

/** Replaces req.body with the parsed, coerced value so controllers trust input. */
module.exports = function validate(schema, source = 'body') {
  return function validator(req, res, next) {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        field: issue.path.join('.') || source,
        message: issue.message,
      }));
      return next(ApiError.validation('Please check the highlighted fields.', details));
    }
    req[source] = result.data;
    return next();
  };
};
