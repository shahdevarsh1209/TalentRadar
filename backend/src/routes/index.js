'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');

const validate = require('../middleware/validate');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth, requireRole } = require('../middleware/auth');
const authController = require('../controllers/authController');
const locationController = require('../controllers/locationController');
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

const router = express.Router();

// Registration and OTP endpoints are the abuse-prone ones; search is not.
const registrationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
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

module.exports = router;
