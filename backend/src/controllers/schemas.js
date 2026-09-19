'use strict';

const { z } = require('zod');
const {
  ROLES,
  EXPERIENCE_VALUES,
  WORK_MODES,
  OPEN_TO_WORK,
  PROFILE_VISIBILITY,
  MAX_JOB_TITLES,
  MAX_HIRING_PROFILES,
} = require('../utils/constants');

/**
 * Messages here are shown verbatim in the app, so they are written as product
 * copy rather than developer copy.
 */

// Rejects "aaaa", "....", "123" — a name needs letters and some structure.
const humanName = z
  .string({ required_error: 'Please enter your name.' })
  .trim()
  .min(2, 'Please enter your full name.')
  .max(80, 'That name is too long.')
  .refine((value) => /[A-Za-zऀ-ॿ]/.test(value), 'Please enter a valid name.')
  .refine(
    (value) => !/^(.)\1+$/.test(value.replace(/\s/g, '')),
    'Please enter a valid name.'
  )
  .transform((value) => value.replace(/\s+/g, ' '));

const email = z
  .string({ required_error: 'Please enter your email address.' })
  .trim()
  .min(5, 'Please enter a valid email address.')
  .max(160, 'That email address is too long.')
  .email('Please enter a valid email address.')
  .transform((value) => value.toLowerCase());

const password = z
  .string()
  .min(8, 'Use at least 8 characters.')
  .max(128, 'That password is too long.')
  .optional();

const titleCodes = (max, label) =>
  z
    .array(z.string().trim().min(1))
    .min(1, `Please select at least one ${label}.`)
    .max(max, `You can select up to ${max} ${label}s.`);

const locationInput = z.object({
  source: z.enum(['device', 'manual']),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  area: z.string().trim().max(120).optional(),
  city: z.string().trim().max(120).optional(),
  state: z.string().trim().max(120).optional(),
  country: z.string().trim().max(120).optional(),
  pincode: z
    .string()
    .trim()
    .regex(/^[0-9]{4,10}$/, 'Please enter a valid PIN code.')
    .optional()
    .or(z.literal('')),
  label: z.string().trim().max(160).optional(),
  privacyRadiusKm: z.number().min(0.5).max(25).optional(),
});

/** A manual location must at least name a city; a device fix needs coordinates. */
const locationRefined = locationInput.superRefine((value, ctx) => {
  if (value.source === 'device') {
    if (typeof value.latitude !== 'number' || typeof value.longitude !== 'number') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['latitude'],
        message: 'We could not read your location. Please choose it manually.',
      });
    }
  } else if (!value.city && !value.area && !value.pincode) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['city'],
      message: 'Please choose a city or area.',
    });
  }
});

const candidateRegistrationSchema = z.object({
  name: humanName,
  email,
  password,
  jobTitleCodes: titleCodes(MAX_JOB_TITLES, 'job title'),
  experienceLevel: z.enum(EXPERIENCE_VALUES).optional().default('fresher'),
  workModes: z
    .array(z.enum(WORK_MODES))
    .min(1, 'Please choose at least one work mode.')
    .max(3),
  openToWork: z.enum(OPEN_TO_WORK).optional().default('open_to_opportunities'),
  profileVisibility: z.enum(PROFILE_VISIBILITY).optional().default('recruiters_only'),
  stealthMode: z.boolean().optional().default(false),
});

const recruiterRegistrationSchema = z.object({
  companyName: z
    .string({ required_error: 'Please enter your company name.' })
    .trim()
    .min(2, 'Please enter your company name.')
    .max(120, 'That company name is too long.')
    .transform((value) => value.replace(/\s+/g, ' ')),
  hrName: humanName,
  email,
  password,
  designation: z.string().trim().max(80).optional(),
  hiringProfileCodes: titleCodes(MAX_HIRING_PROFILES, 'hiring profile'),
  hiringWorkModes: z.array(z.enum(WORK_MODES)).max(3).optional().default([]),
  profileVisibility: z.enum(PROFILE_VISIBILITY).optional().default('everyone'),
});

const loginSchema = z.object({
  email,
  password: z.string().min(1, 'Please enter your password.'),
  role: z.enum(ROLES).optional(),
});

const checkEmailSchema = z.object({ email });

const verifyEmailSchema = z.object({
  userId: z.string().trim().min(1),
  code: z
    .string()
    .trim()
    .regex(/^[0-9]{6}$/, 'Please enter the 6-digit code.'),
});

const resendCodeSchema = z.object({ userId: z.string().trim().min(1) });

const candidateLocationSchema = locationRefined;

const recruiterLocationSchema = z
  .object({
    hiringRadiusKm: z.number().min(1).max(100).optional(),
  })
  .and(locationRefined);

const jobTitleSearchSchema = z.object({
  q: z.string().trim().max(80).optional().default(''),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
  category: z.string().trim().max(60).optional(),
});

module.exports = {
  candidateRegistrationSchema,
  recruiterRegistrationSchema,
  loginSchema,
  checkEmailSchema,
  verifyEmailSchema,
  resendCodeSchema,
  candidateLocationSchema,
  recruiterLocationSchema,
  jobTitleSearchSchema,
};
