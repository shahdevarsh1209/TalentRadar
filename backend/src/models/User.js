'use strict';

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { ROLES } = require('../utils/constants');

/**
 * Authentication identity. Deliberately thin: it owns credentials and role, and
 * nothing profile-shaped, so new auth providers (Google, phone OTP) can be added
 * by appending to `authProviders` without touching profile data.
 */
const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    role: { type: String, required: true, enum: ROLES, index: true },
    passwordHash: { type: String, default: null },
    authProviders: {
      type: [String],
      default: ['password'],
      enum: ['password', 'email_otp', 'google', 'apple', 'phone'],
    },
    isEmailVerified: { type: Boolean, default: false },
    emailVerifiedAt: { type: Date, default: null },
    // Registration is multi-step; this lets the client resume where it stopped.
    onboardingStage: {
      type: String,
      enum: ['registered', 'email_verified', 'location_set', 'complete'],
      default: 'registered',
    },
    lastLoginAt: { type: Date, default: null },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

userSchema.methods.setPassword = async function setPassword(plain) {
  this.passwordHash = await bcrypt.hash(plain, 12);
  if (!this.authProviders.includes('password')) this.authProviders.push('password');
};

userSchema.methods.verifyPassword = function verifyPassword(plain) {
  if (!this.passwordHash) return Promise.resolve(false);
  return bcrypt.compare(plain, this.passwordHash);
};

userSchema.methods.toPublic = function toPublic() {
  return {
    userId: this._id.toString(),
    email: this.email,
    role: this.role,
    isEmailVerified: this.isEmailVerified,
    onboardingStage: this.onboardingStage,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
