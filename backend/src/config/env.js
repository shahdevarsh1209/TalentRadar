'use strict';

require('dotenv').config();

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 4000),
  mongoUri: process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/talentradar',
  jwtSecret: process.env.JWT_SECRET || 'talentradar-dev-secret-change-me',
  jwtExpiry: process.env.JWT_EXPIRY || '30d',
  // While no mail provider is wired up the OTP is returned in the response so
  // the app can be exercised end to end. Never enable this in production.
  exposeOtp: (process.env.EXPOSE_OTP || 'true') === 'true',
  otpTtlMinutes: Number(process.env.OTP_TTL_MINUTES || 10),
  otpResendSeconds: Number(process.env.OTP_RESEND_SECONDS || 45),
};

if (env.nodeEnv === 'production' && env.jwtSecret.includes('change-me')) {
  throw new Error('JWT_SECRET must be set in production');
}

module.exports = env;
