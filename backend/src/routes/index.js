'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');

const validate = require('../middleware/validate');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth, requireRole } = require('../middleware/auth');
const authController = require('../controllers/authController');
const locationController = require('../controllers/locationController');
const jobsController = require('../controllers/jobsController');
const candidatesController = require('../controllers/candidatesController');
const socialController = require('../controllers/socialController');
const profilesController = require('../controllers/profilesController');
const searchController = require('../controllers/searchController');
const jobTitleService = require('../services/jobTitleService');
const {
  EXPERIENCE_LEVELS,
  WORK_MODES,
  OPEN_TO_WORK,
  PROFILE_VISIBILITY,
  MAX_JOB_TITLES,
  MAX_HIRING_PROFILES,
} = require('../utils/constants');
const schemas = require('../controllers/schemas');
const env = require('../config/env');

const router = express.Router();

// Registration and OTP endpoints are the abuse-prone ones; search is not.
const registrationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: env.authRateLimit,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMITED', message: 'Too many attempts. Please try again in a few minutes.' },
  },
});

const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMITED', message: 'Too many attempts. Please try again shortly.' },
  },
});

router.get('/health', (req, res) => {
  const states = ['disconnected', 'connected', 'connecting', 'disconnecting'];
  res.json({
    success: true,
    data: {
      status: 'ok',
      database: states[mongoose.connection.readyState] || 'unknown',
      time: new Date().toISOString(),
    },
  });
});

/**
 * Vocabulary the client renders its selectors from. Serving it means a new
 * experience band or work mode ships without an app release.
 */
router.get('/meta/registration-options', (req, res) => {
  res.json({
    success: true,
    data: {
      experienceLevels: EXPERIENCE_LEVELS,
      workModes: WORK_MODES,
      openToWork: OPEN_TO_WORK,
      profileVisibility: PROFILE_VISIBILITY,
      limits: { maxJobTitles: MAX_JOB_TITLES, maxHiringProfiles: MAX_HIRING_PROFILES },
    },
  });
});

// ── Job-title master ────────────────────────────────────────────────────────
router.get(
  '/job-titles',
  validate(schemas.jobTitleSearchSchema, 'query'),
  asyncHandler(async (req, res) => {
    const results = await jobTitleService.searchJobTitles({
      query: req.query.q,
      limit: req.query.limit,
      category: req.query.category,
    });
    res.json({ success: true, data: { results, query: req.query.q || '' } });
  })
);

router.get(
  '/job-titles/categories',
  asyncHandler(async (req, res) => {
    const categories = await jobTitleService.listCategories();
    res.json({ success: true, data: { categories } });
  })
);

// ── Registration & auth ─────────────────────────────────────────────────────
router.post(
  '/auth/register/candidate',
  registrationLimiter,
  validate(schemas.candidateRegistrationSchema),
  authController.registerCandidate
);

router.post(
  '/auth/register/recruiter',
  registrationLimiter,
  validate(schemas.recruiterRegistrationSchema),
  authController.registerRecruiter
);

router.post('/auth/check-email', validate(schemas.checkEmailSchema), authController.checkEmail);

router.post(
  '/auth/verify-email',
  otpLimiter,
  validate(schemas.verifyEmailSchema),
  authController.verifyEmail
);

router.post(
  '/auth/resend-code',
  otpLimiter,
  validate(schemas.resendCodeSchema),
  authController.resendCode
);

router.post('/auth/login', registrationLimiter, validate(schemas.loginSchema), authController.login);

router.get('/auth/me', requireAuth, authController.me);

// ── Location ────────────────────────────────────────────────────────────────
router.get('/locations/search', locationController.searchLocations);

router.put(
  '/candidates/me/location',
  requireAuth,
  requireRole('candidate'),
  validate(schemas.candidateLocationSchema),
  locationController.setCandidateLocation
);

router.put(
  '/recruiters/me/hiring-location',
  requireAuth,
  requireRole('recruiter'),
  validate(schemas.recruiterLocationSchema),
  locationController.setHiringLocation
);

// ── Jobs ────────────────────────────────────────────────────────────────────
const candidateOnly = [requireAuth, requireRole('candidate')];
const recruiterOnly = [requireAuth, requireRole('recruiter')];

router.get('/jobs', requireAuth, validate(schemas.jobListSchema, 'query'), jobsController.listJobs);
router.post('/jobs', ...recruiterOnly, validate(schemas.createJobSchema), jobsController.createJob);
router.get('/jobs/:jobId', requireAuth, jobsController.getJob);
router.patch(
  '/jobs/:jobId/status',
  ...recruiterOnly,
  validate(schemas.jobStatusSchema),
  jobsController.setJobStatus
);
router.post('/jobs/:jobId/interest', ...candidateOnly, jobsController.expressInterest);
router.get('/jobs/:jobId/interests', ...recruiterOnly, jobsController.jobInterests);
router.get('/recruiters/me/jobs', ...recruiterOnly, jobsController.myJobs);

// ── Candidates & recruiters ─────────────────────────────────────────────────
router.get(
  '/candidates/nearby',
  ...recruiterOnly,
  validate(schemas.candidateSearchSchema, 'query'),
  candidatesController.nearbyCandidates
);
router.get('/candidates/me/insights', ...candidateOnly, candidatesController.candidateInsights);
router.put(
  '/candidates/me/availability',
  ...candidateOnly,
  validate(schemas.availabilitySchema),
  candidatesController.setAvailability
);
router.put(
  '/candidates/me/privacy',
  ...candidateOnly,
  validate(schemas.privacySchema),
  candidatesController.updatePrivacy
);
router.put(
  '/candidates/me/profile',
  ...candidateOnly,
  validate(schemas.candidateProfileUpdateSchema),
  candidatesController.updateCandidateProfile
);
router.get('/candidates/:userId', requireAuth, candidatesController.candidateProfile);
router.put(
  '/recruiters/me/profile',
  ...recruiterOnly,
  validate(schemas.recruiterProfileUpdateSchema),
  candidatesController.updateRecruiterProfile
);
router.get('/companies/mine', ...recruiterOnly, candidatesController.myCompany);
router.put(
  '/companies/mine',
  ...recruiterOnly,
  validate(schemas.companyUpdateSchema),
  candidatesController.updateCompany
);

// Registered after every literal /recruiters/... and /companies/... path above,
// so "me" and "mine" are never mistaken for an id.
router.get('/recruiters/:userId', requireAuth, profilesController.recruiterProfile);
router.get('/companies/:companyId', requireAuth, profilesController.companyProfile);

// ── Search ──────────────────────────────────────────────────────────────────
router.get('/search', requireAuth, validate(schemas.searchSchema, 'query'), searchController.search);

// ── Safety ──────────────────────────────────────────────────────────────────
router.get('/blocks', requireAuth, profilesController.listBlocks);
router.put('/blocks', requireAuth, validate(schemas.blockSchema), profilesController.setBlock);
router.post('/reports', requireAuth, validate(schemas.reportSchema), profilesController.createReport);

// ── Saved, connections, chat ────────────────────────────────────────────────
router.get('/saved', requireAuth, socialController.listSaved);
router.put('/saved', requireAuth, validate(schemas.saveItemSchema), socialController.saveItem);
router.delete('/saved/:kind/:refId', requireAuth, socialController.unsaveItem);

router.get('/connections', requireAuth, socialController.listConnections);
router.post(
  '/connections',
  requireAuth,
  validate(schemas.connectionRequestSchema),
  socialController.requestConnection
);
router.post(
  '/connections/:connectionId/respond',
  requireAuth,
  validate(schemas.connectionResponseSchema),
  socialController.respondToConnection
);

router.get('/conversations', requireAuth, socialController.listConversations);
router.post(
  '/conversations',
  requireAuth,
  validate(schemas.startConversationSchema),
  socialController.startConversation
);
router.get('/conversations/:conversationId/messages', requireAuth, socialController.listMessages);
router.post(
  '/conversations/:conversationId/messages',
  requireAuth,
  validate(schemas.sendMessageSchema),
  socialController.sendMessage
);
router.post(
  '/conversations/:conversationId/invites',
  ...recruiterOnly,
  validate(schemas.inviteSchema),
  socialController.sendInvite
);
router.post(
  '/messages/:messageId/invite-response',
  requireAuth,
  validate(schemas.inviteResponseSchema),
  socialController.respondToInvite
);
router.get('/me/badges', requireAuth, socialController.badges);

module.exports = router;
