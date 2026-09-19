'use strict';

const crypto = require('crypto');
const env = require('../config/env');

/** Free mail providers. Used only to flag, never to block, a recruiter. */
const FREE_EMAIL_DOMAINS = new Set([
  'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.in', 'yahoo.co.in',
  'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'icloud.com',
  'rediffmail.com', 'protonmail.com', 'proton.me', 'zoho.com', 'aol.com',
  'mail.com', 'yandex.com', 'gmx.com',
]);

/**
 * Gmail treats dots and +tags as noise, so two spellings of one inbox would
 * otherwise register twice. Everything else is only lowercased and trimmed.
 */
function normalizeEmail(raw) {
  const email = String(raw || '').trim().toLowerCase();
  const atIndex = email.lastIndexOf('@');
  if (atIndex < 1) return email;

  const local = email.slice(0, atIndex);
  const domain = email.slice(atIndex + 1);

  if (domain === 'gmail.com' || domain === 'googlemail.com') {
    const cleaned = local.split('+')[0].replace(/\./g, '');
    return `${cleaned}@gmail.com`;
  }
  return `${local.split('+')[0]}@${domain}`;
}

function emailDomain(email) {
  const parts = String(email || '').split('@');
  return parts.length === 2 ? parts[1].toLowerCase() : '';
}

function isOfficialDomain(email) {
  const domain = emailDomain(email);
  return Boolean(domain) && !FREE_EMAIL_DOMAINS.has(domain);
}

/** Cryptographically random 6-digit code — never Math.random for credentials. */
function generateOtp() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

/**
 * Delivery seam. Swapping in SES/SendGrid/Resend means implementing this one
 * function; nothing upstream knows how mail is actually sent.
 */
async function sendVerificationEmail({ email, code, name }) {
  if (env.nodeEnv !== 'production') {
    console.log(`[mail] verification code for ${email} (${name || 'user'}): ${code}`);
  }
  return { delivered: true, provider: 'console' };
}

module.exports = {
  normalizeEmail,
  emailDomain,
  isOfficialDomain,
  generateOtp,
  sendVerificationEmail,
  FREE_EMAIL_DOMAINS,
};
