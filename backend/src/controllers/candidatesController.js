'use strict';

const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const Company = require('../models/Company');
const { SavedItem, Connection, ProfileView, pairKeyOf } = require('../models/social');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { distanceKm, displayDistance } = require('../utils/geo');
const { resolveTitleCodes } = require('../services/jobTitleService');
const { initialsOf, canViewCandidate } = require('../services/peopleService');
const { sessionPayload, candidateCompletion, recruiterCompletion } = require('./authController');
const { viewerContext } = require('./jobsController');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function endOfToday() {
  const end = new Date();
  end.setHours(23, 59, 59, 999);
  return end;
}

/** The card a recruiter sees in "Talent near you" — area words and a rounded distance only. */
function candidateCard(profile, { point, hiringCodes, savedIds }) {
  const km = point ? distanceKm(point, profile.location?.approximate) : null;
  return {
    userId: String(profile.userId),
    name: profile.name,
    initials: initialsOf(profile.name),
    headline: profile.jobTitles[0]?.name || profile.headline || '',
    jobTitles: profile.jobTitles.map((title) => ({ code: title.code, name: title.name })),
    experienceLevel: profile.experienceLevel,
    workModes: profile.workModes,
    openToWork: profile.openToWork,
    availableToday: profile.isAvailableToday(),
    area: [profile.location?.area, profile.location?.city].filter(Boolean).join(', '),
    distanceKm: km === null ? null : displayDistance(km),
    matchesHiring: profile.jobTitles.some((title) => hiringCodes.has(title.code)),
    saved: savedIds.has(String(profile.userId)),
  };
}

/** Recruiter radar: discoverable candidates around the company hiring location. */
const nearbyCandidates = asyncHandler(async (req, res) => {
  const { q, experience, workMode, availableToday, matchOnly, limit } = req.query;
  const context = await viewerContext(req.user);
  const radiusKm = req.query.radiusKm || context.radiusKm;

  // The discoverability rule, expressed as a query: see CandidateProfile.isDiscoverable.
  const filter = {
    stealthMode: false,
    openToWork: { $ne: 'not_looking' },
    profileVisibility: { $in: ['everyone', 'recruiters_only'] },
  };
  if (experience) filter.experienceLevel = experience;
  if (workMode) filter.workModes = workMode;
  if (availableToday) filter.availableUntil = { $gt: new Date() };
  if (matchOnly && context.titleCodes.size) {
    filter['jobTitles.code'] = { $in: [...context.titleCodes] };
  }
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    filter.$or = [{ 'jobTitles.name': pattern }, { headline: pattern }, { skills: pattern }];
  }

  let profiles;
  if (context.point) {
    profiles = await CandidateProfile.find({
      ...filter,
      'location.approximate': {
        $nearSphere: { $geometry: context.point, $maxDistance: radiusKm * 1000 },
      },
    }).limit(limit);
  } else {
    profiles = await CandidateProfile.find(filter).sort({ updatedAt: -1 }).limit(limit);
  }

  const saved = await SavedItem.find({
    userId: req.user._id,
    kind: 'person',
    refId: { $in: profiles.map((profile) => profile.userId) },
  }).select('refId');
  const savedIds = new Set(saved.map((item) => String(item.refId)));

  const cards = profiles.map((profile) =>
    candidateCard(profile, { point: context.point, hiringCodes: context.titleCodes, savedIds })
  );

  res.json({
    success: true,
    data: {
      candidates: cards,
      meta: {
        total: cards.length,
        availableToday: cards.filter((card) => card.availableToday).length,
        radiusKm,
        hasLocation: Boolean(context.point),
        areaLabel: context.areaLabel,
      },
    },
  });
});

/** The quick-profile sheet. Records a profile view when a recruiter opens it. */
const candidateProfile = asyncHandler(async (req, res) => {
  const profile = await CandidateProfile.findOne({ userId: req.params.userId }).catch(() => null);
  if (!profile || !(await canViewCandidate(req.user, profile))) {
    throw ApiError.notFound('This profile is private or no longer available.');
  }

  const isSelf = String(profile.userId) === String(req.user._id);
  if (req.user.role === 'recruiter' && !isSelf) {
    await ProfileView.updateOne(
      {
        viewerUserId: req.user._id,
        candidateUserId: profile.userId,
        viewedOn: new Date().toISOString().slice(0, 10),
      },
      { $setOnInsert: { viewerUserId: req.user._id } },
      { upsert: true }
    );
  }

  const context = await viewerContext(req.user);
  const [saved, connection] = await Promise.all([
    SavedItem.exists({ userId: req.user._id, kind: 'person', refId: profile.userId }),
    Connection.findOne({ pairKey: pairKeyOf(req.user._id, profile.userId) }),
  ]);

  let connectionStatus = 'none';
  if (connection?.status === 'accepted') connectionStatus = 'connected';
  else if (connection?.status === 'pending') {
    connectionStatus =
      String(connection.requesterId) === String(req.user._id) ? 'pending_sent' : 'pending_received';
  }

  const card = candidateCard(profile, {
    point: context.point,
    hiringCodes: context.titleCodes,
    savedIds: new Set(saved ? [String(profile.userId)] : []),
  });

  res.json({
    success: true,
    data: {
      candidate: {
        ...card,
        skills: profile.skills,
        experienceYears: profile.experienceYears,
        openToConnect: profile.openToConnect,
        connectionStatus,
        connectionId: connection?._id?.toString() || null,
        canMessage:
          connectionStatus === 'connected' ||
          (req.user.role === 'recruiter' && profile.openToConnect),
      },
    },
  });
});

/** The centre "go live" button: available today, until midnight. */
const setAvailability = asyncHandler(async (req, res) => {
  const profile = await CandidateProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your candidate profile.');

  profile.availableUntil = req.body.available ? endOfToday() : null;
  await profile.save();

  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

/** Privacy & stealth mode screen. */
const updatePrivacy = asyncHandler(async (req, res) => {
  const profile = await CandidateProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your candidate profile.');

  const fields = ['stealthMode', 'profileVisibility', 'openToWork', 'openToConnect', 'walkInAlerts'];
  fields.forEach((field) => {
    if (req.body[field] !== undefined) profile[field] = req.body[field];
  });

  // Choosing "not looking" never leaves someone shown as available.
  if (req.body.openToWork === 'not_looking') profile.stealthMode = true;
  if (profile.stealthMode) profile.availableUntil = null;

  await profile.save();
  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

const updateCandidateProfile = asyncHandler(async (req, res) => {
  const profile = await CandidateProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your candidate profile.');

  const body = req.body;
  if (body.name !== undefined) profile.name = body.name;
  if (body.headline !== undefined) profile.headline = body.headline;
  if (body.skills !== undefined) profile.skills = body.skills;
  if (body.experienceLevel !== undefined) profile.experienceLevel = body.experienceLevel;
  if (body.workModes !== undefined) profile.workModes = body.workModes;
  if (body.jobTitleCodes !== undefined) {
    profile.jobTitles = await resolveTitleCodes(body.jobTitleCodes, { fieldLabel: 'job title' });
  }

  profile.profileCompletion = candidateCompletion(profile);
  await profile.save();
  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

/** "7 recruiters viewed you · In the last 3 days" on the candidate radar. */
const candidateInsights = asyncHandler(async (req, res) => {
  const since = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const viewers = await ProfileView.distinct('viewerUserId', {
    candidateUserId: req.user._id,
    viewedOn: { $gte: since },
  });
  res.json({ success: true, data: { recruitersViewedLast3Days: viewers.length } });
});

const updateRecruiterProfile = asyncHandler(async (req, res) => {
  const profile = await RecruiterProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your hiring profile.');

  const body = req.body;
  if (body.hrName !== undefined) profile.hrName = body.hrName;
  if (body.designation !== undefined) profile.designation = body.designation;
  if (body.hiringWorkModes !== undefined) profile.hiringWorkModes = body.hiringWorkModes;
  if (body.hiringRadiusKm !== undefined) profile.hiringRadiusKm = body.hiringRadiusKm;
  if (body.hiringProfileCodes !== undefined) {
    profile.hiringProfiles = await resolveTitleCodes(body.hiringProfileCodes, {
      fieldLabel: 'hiring profile',
    });
  }

  const company = await Company.findById(profile.companyId);
  profile.profileCompletion = recruiterCompletion(profile, company);
  await profile.save();
  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

/** Company profile completion: the fields deliberately left out of registration. */
const updateCompany = asyncHandler(async (req, res) => {
  const profile = await RecruiterProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your hiring profile.');
  const company = await Company.findById(profile.companyId);
  if (!company) throw ApiError.notFound('We could not find your company.');

  ['description', 'industry', 'size', 'website', 'linkedinUrl'].forEach((field) => {
    if (req.body[field] !== undefined) company[field] = req.body[field];
  });
  await company.save();

  profile.profileCompletion = recruiterCompletion(profile, company);
  await profile.save();
  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: { ...payload, companyDetails: companyDetails(company) } });
});

function companyDetails(company) {
  return {
    ...company.toPublic(),
    description: company.description,
    linkedinUrl: company.linkedinUrl,
  };
}

const myCompany = asyncHandler(async (req, res) => {
  const profile = await RecruiterProfile.findOne({ userId: req.user._id });
  const company = profile ? await Company.findById(profile.companyId) : null;
  if (!company) throw ApiError.notFound('We could not find your company.');
  res.json({ success: true, data: { company: companyDetails(company) } });
});

module.exports = {
  nearbyCandidates,
  candidateProfile,
  setAvailability,
  updatePrivacy,
  updateCandidateProfile,
  candidateInsights,
  updateRecruiterProfile,
  updateCompany,
  myCompany,
};
