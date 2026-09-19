'use strict';

const User = require('../models/User');
const Company = require('../models/Company');
const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { signToken } = require('../middleware/auth');
const { resolveTitleCodes } = require('../services/jobTitleService');
const { issueVerificationCode, verifyCode } = require('../services/verificationService');
const { normalizeEmail, isOfficialDomain } = require('../services/emailService');

const ROLE_LABEL = { candidate: 'a candidate', recruiter: 'an HR / recruiter' };

/**
 * One duplicate check for both roles. Registering with an address that already
 * exists never silently creates a second profile, and when the existing account
 * is on the other role the client gets enough detail to explain it properly.
 */
async function assertEmailAvailable(email, role) {
  const existing = await User.findOne({ email });
  if (!existing) return;

  if (existing.role === role) {
    throw ApiError.conflict('EMAIL_EXISTS', 'An account already exists with this email.', {
      existingRole: existing.role,
      canLogin: true,
    });
  }

  throw ApiError.conflict(
    'EMAIL_EXISTS_OTHER_ROLE',
    `This email is already registered as ${ROLE_LABEL[existing.role]} account. Log in with it, or use a different email to register as ${ROLE_LABEL[role]}.`,
    { existingRole: existing.role, requestedRole: role, canLogin: true }
  );
}

/** Rough completeness signal for the profile-completion nudge on the radar. */
function candidateCompletion(profile) {
  const checks = [
    Boolean(profile.name),
    Boolean(profile.email),
    profile.jobTitles.length > 0,
    profile.workModes.length > 0,
    Boolean(profile.experienceLevel),
    profile.location?.source && profile.location.source !== 'unset',
    profile.skills.length > 0,
    Boolean(profile.headline),
  ];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
}

function recruiterCompletion(profile, company) {
  const checks = [
    Boolean(profile.companyName),
    Boolean(profile.hrName),
    Boolean(profile.email),
    profile.hiringProfiles.length > 0,
    profile.hiringLocations.length > 0,
    Boolean(company?.industry),
    Boolean(company?.size),
    Boolean(company?.website),
  ];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
}

/** Response shape shared by register, verify, login and location updates. */
async function sessionPayload(user, { includeToken = true } = {}) {
  const profile =
    user.role === 'candidate'
      ? await CandidateProfile.findOne({ userId: user._id })
      : await RecruiterProfile.findOne({ userId: user._id });

  let company = null;
  if (user.role === 'recruiter' && profile) {
    company = await Company.findById(profile.companyId);
  }

  return {
    ...(includeToken ? { token: signToken(user) } : {}),
    user: user.toPublic(),
    profile: profile ? profile.toPublic() : null,
    ...(company ? { company: company.toPublic() } : {}),
  };
}

const registerCandidate = asyncHandler(async (req, res) => {
  const body = req.body;
  const email = normalizeEmail(body.email);

  await assertEmailAvailable(email, 'candidate');

  const jobTitles = await resolveTitleCodes(body.jobTitleCodes, { fieldLabel: 'job title' });

  const user = new User({ email, role: 'candidate' });
  if (body.password) await user.setPassword(body.password);
  else user.authProviders = ['email_otp'];
  await user.save();

  let profile;
  try {
    profile = new CandidateProfile({
      userId: user._id,
      name: body.name,
      email,
      jobTitles,
      headline: jobTitles[0].name,
      experienceLevel: body.experienceLevel,
      workModes: body.workModes,
      openToWork: body.openToWork,
      profileVisibility: body.profileVisibility,
      // "Not looking" must not leave someone exposed as available, so it turns
      // stealth on unless the candidate already asked for it explicitly.
      stealthMode: body.stealthMode || body.openToWork === 'not_looking',
    });
    profile.profileCompletion = candidateCompletion(profile);
    await profile.save();
  } catch (err) {
    // Never strand a credential-only user with no profile.
    await User.deleteOne({ _id: user._id });
    throw err;
  }

  const verification = await issueVerificationCode(user, { name: body.name });
  const payload = await sessionPayload(user);

  res.status(201).json({ success: true, data: { ...payload, verification } });
});

const registerRecruiter = asyncHandler(async (req, res) => {
  const body = req.body;
  const email = normalizeEmail(body.email);

  await assertEmailAvailable(email, 'recruiter');

  const hiringProfiles = await resolveTitleCodes(body.hiringProfileCodes, {
    fieldLabel: 'hiring profile',
  });

  const user = new User({ email, role: 'recruiter' });
  if (body.password) await user.setPassword(body.password);
  else user.authProviders = ['email_otp'];
  await user.save();

  let profile;
  let company;
  try {
    // Second recruiter from the same company joins it rather than duplicating it.
    const slug = Company.toSlug(body.companyName);
    company = await Company.findOne({ slug });
    if (!company) {
      company = await Company.create({
        name: body.companyName,
        slug,
        createdBy: user._id,
      });
    }

    profile = new RecruiterProfile({
      userId: user._id,
      companyId: company._id,
      companyName: company.name,
      hrName: body.hrName,
      email,
      designation: body.designation || '',
      isOfficialEmailDomain: isOfficialDomain(email),
      hiringProfiles,
      hiringWorkModes: body.hiringWorkModes,
      profileVisibility: body.profileVisibility,
    });
    profile.profileCompletion = recruiterCompletion(profile, company);
    await profile.save();
  } catch (err) {
    await User.deleteOne({ _id: user._id });
    throw err;
  }

  const verification = await issueVerificationCode(user, { name: body.hrName });
  const payload = await sessionPayload(user);

  res.status(201).json({ success: true, data: { ...payload, verification } });
});

const checkEmail = asyncHandler(async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const existing = await User.findOne({ email });
  res.json({
    success: true,
    data: {
      email,
      available: !existing,
      existingRole: existing ? existing.role : null,
      isOfficialDomain: isOfficialDomain(email),
    },
  });
});

const verifyEmail = asyncHandler(async (req, res) => {
  const user = await User.findById(req.body.userId).catch(() => null);
  if (!user) throw ApiError.notFound('We could not find that registration. Please sign up again.');

  await verifyCode(user, req.body.code);
  const payload = await sessionPayload(user);

  res.json({ success: true, data: payload });
});

const resendCode = asyncHandler(async (req, res) => {
  const user = await User.findById(req.body.userId).catch(() => null);
  if (!user) throw ApiError.notFound('We could not find that registration. Please sign up again.');
  if (user.isEmailVerified) {
    throw ApiError.badRequest('This email is already verified.');
  }

  const profile =
    user.role === 'candidate'
      ? await CandidateProfile.findOne({ userId: user._id })
      : await RecruiterProfile.findOne({ userId: user._id });

  const verification = await issueVerificationCode(user, {
    name: profile?.name || profile?.hrName,
  });

  res.json({ success: true, data: { verification } });
});

const login = asyncHandler(async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const user = await User.findOne({ email });

  // Same message either way — an attacker learns nothing about which emails exist.
  const invalid = ApiError.unauthorized('That email or password is not correct.');
  if (!user || !user.isActive) throw invalid;

  const ok = await user.verifyPassword(req.body.password);
  if (!ok) throw invalid;

  if (req.body.role && req.body.role !== user.role) {
    throw ApiError.conflict(
      'ROLE_MISMATCH',
      `This account is registered as ${ROLE_LABEL[user.role]} account.`,
      { existingRole: user.role }
    );
  }

  user.lastLoginAt = new Date();
  await user.save();

  const payload = await sessionPayload(user);
  res.json({ success: true, data: payload });
});

const me = asyncHandler(async (req, res) => {
  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

module.exports = {
  registerCandidate,
  registerRecruiter,
  checkEmail,
  verifyEmail,
  resendCode,
  login,
  me,
  sessionPayload,
  candidateCompletion,
  recruiterCompletion,
};
