'use strict';

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

/** Short-lived OTP record. The code itself is hashed, never stored in clear. */
const emailVerificationSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    email: { type: String, required: true, lowercase: true, trim: true },
    codeHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    attempts: { type: Number, default: 0 },
    maxAttempts: { type: Number, default: 5 },
    consumedAt: { type: Date, default: null },
    lastSentAt: { type: Date, default: Date.now },
  },
  { timestamps: true, collection: 'email_verifications' }
);

// Mongo reaps consumed/expired documents an hour after they stop being useful.
emailVerificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 3600 });

emailVerificationSchema.methods.setCode = async function setCode(code) {
  this.codeHash = await bcrypt.hash(code, 10);
};

emailVerificationSchema.methods.matches = function matches(code) {
  return bcrypt.compare(String(code), this.codeHash);
};

module.exports = mongoose.model('EmailVerification', emailVerificationSchema);
