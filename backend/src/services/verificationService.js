'use strict';

const env = require('../config/env');
const ApiError = require('../utils/ApiError');
const EmailVerification = require('../models/EmailVerification');
const { generateOtp, sendVerificationEmail } = require('./emailService');

/**
 * Issues a fresh code, superseding any outstanding one for this user. Honours a
 * resend cooldown so the screen's countdown is enforced server-side too.
 */
async function issueVerificationCode(user, { name } = {}) {
  const existing = await EmailVerification.findOne({
    userId: user._id,
    consumedAt: null,
  }).sort({ createdAt: -1 });

  if (existing) {
    const elapsedSeconds = (Date.now() - new Date(existing.lastSentAt).getTime()) / 1000;
    if (elapsedSeconds < env.otpResendSeconds) {
      throw ApiError.tooMany(
        `Please wait ${Math.ceil(env.otpResendSeconds - elapsedSeconds)}s before requesting another code.`
      );
    }
    existing.consumedAt = new Date();
    await existing.save();
  }

  const code = generateOtp();
  const record = new EmailVerification({
    userId: user._id,
    email: user.email,
    expiresAt: new Date(Date.now() + env.otpTtlMinutes * 60 * 1000),
    lastSentAt: new Date(),
  });
  await record.setCode(code);
  await record.save();

  await sendVerificationEmail({ email: user.email, code, name });

  return {
    expiresAt: record.expiresAt,
    resendAfterSeconds: env.otpResendSeconds,
    // Development affordance only; controlled by EXPOSE_OTP.
    ...(env.exposeOtp ? { devCode: code } : {}),
  };
}

/** Consumes a code. Wrong codes burn an attempt; five wrong codes kill it. */
async function verifyCode(user, code) {
  const record = await EmailVerification.findOne({
    userId: user._id,
    consumedAt: null,
  }).sort({ createdAt: -1 });

  if (!record) {
    throw ApiError.badRequest('That code is no longer valid. Please request a new one.');
  }
  if (record.expiresAt.getTime() < Date.now()) {
    throw ApiError.badRequest('This code has expired. Please request a new one.');
  }
  if (record.attempts >= record.maxAttempts) {
    throw ApiError.tooMany('Too many incorrect attempts. Please request a new code.');
  }

  const matches = await record.matches(code);
  if (!matches) {
    record.attempts += 1;
    await record.save();
    const remaining = record.maxAttempts - record.attempts;
    throw ApiError.badRequest(
      remaining > 0
        ? `That code is not correct. ${remaining} attempt${remaining === 1 ? '' : 's'} left.`
        : 'That code is not correct. Please request a new one.'
    );
  }

  record.consumedAt = new Date();
  await record.save();

  user.isEmailVerified = true;
  user.emailVerifiedAt = new Date();
  if (user.onboardingStage === 'registered') user.onboardingStage = 'email_verified';
  await user.save();

  return user;
}

module.exports = { issueVerificationCode, verifyCode };
