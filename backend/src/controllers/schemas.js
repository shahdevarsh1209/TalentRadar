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

// ── Jobs ─────────────────────────────────────────────────────────────────────

const objectId = z.string().trim().regex(/^[a-f0-9]{24}$/i, 'That reference is not valid.');
const timeOfDay = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use a time like 10:00.');

const createJobSchema = z
  .object({
    titleCode: z.string().trim().min(1, 'Please choose the role you are hiring for.'),
    description: z.string().trim().max(2000, 'Keep the description under 2000 characters.').optional(),
    experienceLevel: z.enum(EXPERIENCE_VALUES).optional().default('fresher'),
    workMode: z.enum(WORK_MODES, { required_error: 'Please choose a work mode.' }),
    openings: z.coerce.number().int().min(1, 'At least one opening.').max(500).optional().default(1),
    salaryMin: z.coerce.number().int().min(0).max(10000000).optional().nullable(),
    salaryMax: z.coerce.number().int().min(0).max(10000000).optional().nullable(),
    isWalkIn: z.boolean().optional().default(false),
    walkIn: z
      .object({
        date: z.string().refine((value) => !Number.isNaN(Date.parse(value)), 'Please pick a date.'),
        startTime: timeOfDay,
        endTime: timeOfDay,
        address: z.string().trim().max(200).optional(),
        instructions: z.string().trim().max(300).optional(),
      })
      .optional(),
  })
  .superRefine((value, ctx) => {
    if (!value.isWalkIn) return;
    if (!value.walkIn) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['walkIn'], message: 'Add the walk-in date and time.' });
      return;
    }
    const day = new Date(value.walkIn.date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (day < today) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['walkIn', 'date'], message: 'The walk-in date has passed.' });
    }
    if (value.walkIn.startTime >= value.walkIn.endTime) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['walkIn', 'endTime'], message: 'End time must be after the start.' });
    }
  });

const jobListSchema = z.object({
  filter: z.enum(['all', 'walkins', 'remote']).optional().default('all'),
  q: z.string().trim().max(80).optional().default(''),
  sort: z.enum(['nearest', 'newest']).optional().default('nearest'),
  radiusKm: z.coerce.number().min(1).max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

const jobStatusSchema = z.object({ status: z.enum(['open', 'closed']) });

// ── Candidates & recruiters ──────────────────────────────────────────────────

const candidateSearchSchema = z.object({
  q: z.string().trim().max(80).optional().default(''),
  experience: z.enum(EXPERIENCE_VALUES).optional(),
  workMode: z.enum(WORK_MODES).optional(),
  availableToday: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
  matchOnly: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
  radiusKm: z.coerce.number().min(1).max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

const availabilitySchema = z.object({ available: z.boolean() });

const privacySchema = z
  .object({
    stealthMode: z.boolean().optional(),
    profileVisibility: z.enum(PROFILE_VISIBILITY).optional(),
    openToWork: z.enum(OPEN_TO_WORK).optional(),
    openToConnect: z.boolean().optional(),
    walkInAlerts: z.boolean().optional(),
  })
  .refine((value) => Object.keys(value).length > 0, 'Nothing to update.');

const candidateProfileUpdateSchema = z.object({
  name: humanName.optional(),
  headline: z.string().trim().max(120, 'Keep your headline under 120 characters.').optional(),
  skills: z
    .array(z.string().trim().min(1).max(40))
    .max(20, 'You can add up to 20 skills.')
    .optional()
    .transform((value) => (value ? [...new Set(value)] : value)),
  jobTitleCodes: titleCodes(MAX_JOB_TITLES, 'job title').optional(),
  experienceLevel: z.enum(EXPERIENCE_VALUES).optional(),
  workModes: z.array(z.enum(WORK_MODES)).min(1, 'Please choose at least one work mode.').max(3).optional(),
});

const recruiterProfileUpdateSchema = z.object({
  hrName: humanName.optional(),
  designation: z.string().trim().max(80).optional(),
  hiringProfileCodes: titleCodes(MAX_HIRING_PROFILES, 'hiring profile').optional(),
  hiringWorkModes: z.array(z.enum(WORK_MODES)).max(3).optional(),
  hiringRadiusKm: z.number().min(1).max(100).optional(),
});

const companyUpdateSchema = z.object({
  description: z.string().trim().max(1000).optional(),
  industry: z.string().trim().max(80).optional(),
  size: z.enum(['1-10', '11-50', '51-200', '201-500', '501-1000', '1000+', '']).optional(),
  website: z
    .string()
    .trim()
    .max(200)
    .refine((value) => value === '' || /^https?:\/\/\S+\.\S+/.test(value), 'Please enter a full web address, like https://abc.com.')
    .optional(),
  linkedinUrl: z
    .string()
    .trim()
    .max(200)
    .refine((value) => value === '' || /^https?:\/\/\S+\.\S+/.test(value), 'Please enter a full web address.')
    .optional(),
});

// ── Saved, connections, chat ─────────────────────────────────────────────────

const saveItemSchema = z.object({ kind: z.enum(['job', 'person']), refId: objectId });

const connectionRequestSchema = z.object({
  recipientId: objectId,
  message: z.string().trim().max(300, 'Keep your note under 300 characters.').optional(),
});

const connectionResponseSchema = z.object({ action: z.enum(['accept', 'ignore']) });

const startConversationSchema = z.object({ participantId: objectId, jobId: objectId.optional() });

const sendMessageSchema = z.object({
  text: z.string().trim().min(1, 'Write a message first.').max(2000, 'That message is too long.'),
});

const inviteSchema = z.object({
  title: z.string().trim().min(2, 'Add the role for this interview.').max(120),
  round: z.string().trim().max(60).optional().default('Round 1'),
  scheduledAt: z
    .string()
    .refine((value) => !Number.isNaN(Date.parse(value)), 'Please pick a date and time.')
    .refine((value) => Date.parse(value) > Date.now() - 60 * 1000, 'Pick a time in the future.'),
  mode: z.enum(['in_person', 'video', 'phone']).optional().default('in_person'),
  location: z.string().trim().max(200).optional().default(''),
});

const inviteResponseSchema = z.object({ action: z.enum(['accept', 'reschedule', 'decline']) });

// ── Unified search ───────────────────────────────────────────────────────────

/** Query strings carry booleans as text; absent stays absent rather than false. */
const flag = z
  .enum(['true', 'false'])
  .optional()
  .transform((value) => value === 'true');

const searchSchema = z.object({
  q: z.string().trim().max(80).optional().default(''),
  // Validated against the role's own list in the controller, so a recruiter
  // asking for "companies" simply gets the types they are allowed.
  type: z.enum(['all', 'jobs', 'companies', 'recruiters', 'candidates']).optional().default('all'),
  titleCode: z.string().trim().max(20).optional(),
  companyId: objectId.optional(),
  recruiterId: objectId.optional(),
  experience: z.enum(EXPERIENCE_VALUES).optional(),
  workMode: z.enum(WORK_MODES).optional(),
  openToWork: z.enum(OPEN_TO_WORK).optional(),
  skill: z.string().trim().max(40).optional(),
  maxDistanceKm: z.coerce.number().min(1).max(100).optional(),
  minOpenings: z.coerce.number().int().min(1).max(500).optional(),
  postedWithinDays: z.coerce.number().int().min(1).max(90).optional(),
  activeWithinDays: z.coerce.number().int().min(1).max(90).optional(),
  hiringNow: flag,
  walkIn: flag,
  remote: flag,
  availableToday: flag,
  openToFreshers: flag,
  sort: z.enum(['nearest', 'newest']).optional().default('nearest'),
  limit: z.coerce.number().int().min(1).max(50).optional().default(25),
});

// ── Blocks & reports ─────────────────────────────────────────────────────────

const blockSchema = z.object({ userId: objectId, blocked: z.boolean() });

const reportSchema = z.object({
  subjectKind: z.enum(['person', 'job', 'company']),
  subjectId: objectId,
  reason: z.enum(['spam', 'fake_profile', 'misleading_job', 'harassment', 'other']),
  details: z.string().trim().max(1000).optional().default(''),
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
  createJobSchema,
  jobListSchema,
  jobStatusSchema,
  candidateSearchSchema,
  availabilitySchema,
  privacySchema,
  candidateProfileUpdateSchema,
  recruiterProfileUpdateSchema,
  companyUpdateSchema,
  saveItemSchema,
  connectionRequestSchema,
  connectionResponseSchema,
  startConversationSchema,
  sendMessageSchema,
  inviteSchema,
  inviteResponseSchema,
  searchSchema,
  blockSchema,
  reportSchema,
};
