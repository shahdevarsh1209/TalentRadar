'use strict';

/**
 * One search endpoint for both roles. A candidate is asking "who is hiring for
 * this, and where?", a recruiter is asking "who near me can do this?" — the
 * same query text, different result types, so the client asks for the types it
 * wants and gets counts for the rest to label its tabs.
 *
 * Every result carries the ids needed to open the thing it describes; nothing
 * here is a dead end. Distances are rounded by utils/geo exactly as everywhere
 * else, and a candidate's coordinates never appear in a response.
 */

const Job = require('../models/Job');
const Company = require('../models/Company');
const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const { SavedItem, JobInterest, Connection, pairKeyOf } = require('../models/social');
const asyncHandler = require('../middleware/asyncHandler');
const { distanceKm, displayDistance } = require('../utils/geo');
const { initialsOf, blockedUserIds } = require('../services/peopleService');
const { hiringStatusByRecruiter, hiringStatusByCompany } = require('../services/hiringService');
const { viewerContext } = require('./jobsController');

const DAY_MS = 24 * 60 * 60 * 1000;

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Types each role may ask for, in the order their tabs appear. */
const TYPES_FOR_ROLE = {
  candidate: ['jobs', 'companies', 'recruiters'],
  recruiter: ['candidates', 'jobs'],
};

// ── Jobs ─────────────────────────────────────────────────────────────────────

async function searchJobs(req, context, filters, blocked) {
  const { q } = filters;
  const base = { status: 'open' };

  // Asking for one recruiter's jobs must not step around a block.
  if (filters.recruiterId) {
    if (blocked.includes(String(filters.recruiterId))) return [];
    base.recruiterUserId = filters.recruiterId;
  } else if (blocked.length) {
    base.recruiterUserId = { $nin: blocked };
  }
  if (filters.titleCode) base['title.code'] = filters.titleCode;
  if (filters.workMode) base.workMode = filters.workMode;
  if (filters.walkIn) base.isWalkIn = true;
  if (filters.remote) base.workMode = 'remote';
  if (filters.companyId) base.companyId = filters.companyId;
  if (filters.minOpenings) base.openings = { $gte: filters.minOpenings };
  // "Open to freshers" is the fresher and under-a-year bands, not a flag, and
  // it is the more specific of the two so it wins over a plain experience pick.
  if (filters.openToFreshers) {
    base.experienceLevel = { $in: ['fresher', 'lt_1'] };
  } else if (filters.experience) {
    base.experienceLevel = filters.experience;
  }
  if (filters.postedWithinDays) {
    base.createdAt = { $gte: new Date(Date.now() - filters.postedWithinDays * DAY_MS) };
  }
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    base.$or = [
      { 'title.name': pattern },
      { companyName: pattern },
      { 'title.category': pattern },
      { postedByName: pattern },
      { description: pattern },
    ];
  }

  const radiusKm = filters.maxDistanceKm || context.radiusKm;
  let jobs;
  if (context.point && !filters.remote && filters.sort !== 'newest') {
    jobs = await Job.find({
      ...base,
      'location.approximate': {
        $nearSphere: { $geometry: context.point, $maxDistance: radiusKm * 1000 },
      },
    }).limit(filters.limit);
    // Remote roles have no "near", so they are appended rather than excluded.
    if (!filters.walkIn && jobs.length < filters.limit) {
      const remote = await Job.find({
        ...base,
        workMode: 'remote',
        _id: { $nin: jobs.map((job) => job._id) },
      })
        .sort({ createdAt: -1 })
        .limit(filters.limit - jobs.length);
      jobs = [...jobs, ...remote];
    }
  } else {
    jobs = await Job.find(base).sort({ createdAt: -1 }).limit(filters.limit);
  }

  const ids = jobs.map((job) => job._id);
  const [saved, interests] = await Promise.all([
    SavedItem.find({ userId: req.user._id, kind: 'job', refId: { $in: ids } }).select('refId'),
    req.user.role === 'candidate'
      ? JobInterest.find({ candidateUserId: req.user._id, jobId: { $in: ids } }).select('jobId')
      : [],
  ]);
  const savedIds = new Set(saved.map((item) => String(item.refId)));
  const interestedIds = new Set(interests.map((item) => String(item.jobId)));

  return jobs.map((job) => {
    const km = context.point ? distanceKm(context.point, job.location?.approximate) : null;
    return {
      ...job.toPublic({
        distanceKm: km === null ? null : displayDistance(km, { precise: true }),
        saved: savedIds.has(String(job._id)),
        interested: interestedIds.has(String(job._id)),
      }),
      matchesProfile: context.titleCodes.has(job.title.code),
    };
  });
}

// ── Recruiters ───────────────────────────────────────────────────────────────

async function searchRecruiters(req, context, filters, blocked) {
  const { q } = filters;
  const base = {};
  if (blocked.length) base.userId = { $nin: blocked };
  if (filters.titleCode) base['hiringProfiles.code'] = filters.titleCode;
  if (filters.workMode) base.hiringWorkModes = filters.workMode;
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    base.$or = [
      { hrName: pattern },
      { companyName: pattern },
      { designation: pattern },
      { 'hiringProfiles.name': pattern },
    ];
  }

  const radiusKm = filters.maxDistanceKm || context.radiusKm;
  let profiles;
  if (context.point) {
    profiles = await RecruiterProfile.find({
      ...base,
      'hiringLocations.approximate': {
        $nearSphere: { $geometry: context.point, $maxDistance: radiusKm * 1000 },
      },
    }).limit(filters.limit);
  } else {
    profiles = await RecruiterProfile.find(base).sort({ updatedAt: -1 }).limit(filters.limit);
  }

  const [status, saved, connections] = await Promise.all([
    hiringStatusByRecruiter(profiles.map((profile) => profile.userId)),
    SavedItem.find({
      userId: req.user._id,
      kind: 'person',
      refId: { $in: profiles.map((profile) => profile.userId) },
    }).select('refId'),
    Connection.find({
      pairKey: { $in: profiles.map((profile) => pairKeyOf(req.user._id, profile.userId)) },
    }),
  ]);
  const savedIds = new Set(saved.map((item) => String(item.refId)));
  const connectionByPair = new Map(connections.map((item) => [item.pairKey, item]));

  const cards = profiles.map((profile) => {
    const hiring = status.get(String(profile.userId));
    const location = profile.hiringLocations?.[0];
    const km = context.point ? distanceKm(context.point, location?.approximate) : null;
    const connection = connectionByPair.get(pairKeyOf(req.user._id, profile.userId));

    return {
      userId: String(profile.userId),
      role: 'recruiter',
      name: profile.hrName,
      initials: initialsOf(profile.hrName),
      designation: profile.designation || 'Recruiter',
      companyId: String(profile.companyId),
      companyName: profile.companyName,
      subtitle: [profile.designation || 'Hiring', profile.companyName].filter(Boolean).join(' · '),
      area: location?.label || '',
      distanceKm: km === null ? null : displayDistance(km, { precise: true }),
      hiringNow: hiring.hiringNow,
      totalOpenings: hiring.totalOpenings,
      // The live roles only — what "currently hiring for" means on a card.
      openRoles: hiring.openRoles.slice(0, 4).map((role) => ({
        code: role.code,
        name: role.name,
        openings: role.openings,
        jobId: role.jobId,
      })),
      saved: savedIds.has(String(profile.userId)),
      connectionStatus: !connection
        ? 'none'
        : connection.status === 'accepted'
          ? 'connected'
          : connection.status === 'pending'
            ? String(connection.requesterId) === String(req.user._id)
              ? 'pending_sent'
              : 'pending_received'
            : 'none',
    };
  });

  // Actively hiring recruiters are the useful answer, so they come first.
  if (filters.hiringNow) return cards.filter((card) => card.hiringNow);
  return cards.sort((a, b) => Number(b.hiringNow) - Number(a.hiringNow));
}

// ── Companies ────────────────────────────────────────────────────────────────

async function searchCompanies(req, context, filters) {
  const { q } = filters;
  const base = {};
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    base.$or = [{ name: pattern }, { industry: pattern }];
  }

  // A company is a hit on its own details, or on a role it currently has open —
  // searching "Flutter Developer" should surface the companies hiring for it.
  const narrowed = Boolean(q || filters.titleCode);
  const clauses = [...(base.$or || [])];
  if (narrowed) {
    const jobFilter = { status: 'open' };
    if (filters.titleCode) jobFilter['title.code'] = filters.titleCode;
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      jobFilter.$or = [{ 'title.name': pattern }, { companyName: pattern }];
    }
    const matching = await Job.find(jobFilter).select('companyId').limit(200);
    const companyIds = [...new Set(matching.map((job) => String(job.companyId)))];
    if (companyIds.length) clauses.push({ _id: { $in: companyIds } });
  }

  // A narrowed search that matched nothing must return nothing, not everything.
  if (narrowed && clauses.length === 0) return [];
  const companies = await Company.find(clauses.length ? { $or: clauses } : {}).limit(filters.limit);
  const status = await hiringStatusByCompany(companies.map((company) => company._id));

  const cards = companies.map((company) => {
    const hiring = status.get(String(company._id));
    const office = company.officeLocations?.[0];
    const km = context.point ? distanceKm(context.point, office?.approximate) : null;
    return {
      companyId: String(company._id),
      name: company.name,
      initials: initialsOf(company.name),
      industry: company.industry,
      size: company.size,
      verificationStatus: company.verificationStatus,
      area: office?.label || '',
      distanceKm: km === null ? null : displayDistance(km, { precise: true }),
      hiringNow: hiring.hiringNow,
      totalOpenings: hiring.totalOpenings,
      openRoles: hiring.openRoles.slice(0, 4).map((role) => ({
        code: role.code,
        name: role.name,
        openings: role.openings,
        jobId: role.jobId,
      })),
    };
  });

  if (filters.hiringNow) return cards.filter((card) => card.hiringNow);
  return cards.sort((a, b) => Number(b.hiringNow) - Number(a.hiringNow));
}

// ── Candidates (recruiter side) ──────────────────────────────────────────────

async function searchCandidates(req, context, filters, blocked) {
  const { q } = filters;
  // The discoverability rule as a query — see CandidateProfile.isDiscoverable.
  const base = {
    stealthMode: false,
    openToWork: { $ne: 'not_looking' },
    profileVisibility: { $in: ['everyone', 'recruiters_only'] },
  };
  if (blocked.length) base.userId = { $nin: blocked };
  if (filters.titleCode) base['jobTitles.code'] = filters.titleCode;
  if (filters.experience) base.experienceLevel = filters.experience;
  if (filters.workMode) base.workModes = filters.workMode;
  if (filters.openToWork) base.openToWork = filters.openToWork;
  if (filters.availableToday) base.availableUntil = { $gt: new Date() };
  if (filters.skill) base.skills = new RegExp(escapeRegex(filters.skill), 'i');
  if (filters.activeWithinDays) {
    base.updatedAt = { $gte: new Date(Date.now() - filters.activeWithinDays * DAY_MS) };
  }
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    base.$or = [
      { name: pattern },
      { 'jobTitles.name': pattern },
      { headline: pattern },
      { skills: pattern },
    ];
  }

  const radiusKm = filters.maxDistanceKm || context.radiusKm;
  let profiles;
  if (context.point) {
    profiles = await CandidateProfile.find({
      ...base,
      'location.approximate': {
        $nearSphere: { $geometry: context.point, $maxDistance: radiusKm * 1000 },
      },
    }).limit(filters.limit);
  } else {
    profiles = await CandidateProfile.find(base).sort({ updatedAt: -1 }).limit(filters.limit);
  }

  const [saved, connections] = await Promise.all([
    SavedItem.find({
      userId: req.user._id,
      kind: 'person',
      refId: { $in: profiles.map((profile) => profile.userId) },
    }).select('refId'),
    Connection.find({
      pairKey: { $in: profiles.map((profile) => pairKeyOf(req.user._id, profile.userId)) },
    }),
  ]);
  const savedIds = new Set(saved.map((item) => String(item.refId)));
  const connectionByPair = new Map(connections.map((item) => [item.pairKey, item]));

  return profiles.map((profile) => {
    const km = context.point ? distanceKm(context.point, profile.location?.approximate) : null;
    const connection = connectionByPair.get(pairKeyOf(req.user._id, profile.userId));
    return {
      userId: String(profile.userId),
      name: profile.name,
      initials: initialsOf(profile.name),
      headline: profile.jobTitles[0]?.name || profile.headline || '',
      jobTitles: profile.jobTitles.map((title) => ({ code: title.code, name: title.name })),
      skills: (profile.skills || []).slice(0, 6),
      experienceLevel: profile.experienceLevel,
      workModes: profile.workModes,
      openToWork: profile.openToWork,
      availableToday: profile.isAvailableToday(),
      area: [profile.location?.area, profile.location?.city].filter(Boolean).join(', '),
      // Person-to-person distance keeps the coarser 0.5 km rounding.
      distanceKm: km === null ? null : displayDistance(km),
      matchesHiring: profile.jobTitles.some((title) => context.titleCodes.has(title.code)),
      saved: savedIds.has(String(profile.userId)),
      connectionStatus: !connection
        ? 'none'
        : connection.status === 'accepted'
          ? 'connected'
          : connection.status === 'pending'
            ? String(connection.requesterId) === String(req.user._id)
              ? 'pending_sent'
              : 'pending_received'
            : 'none',
    };
  });
}

// ── Entry point ──────────────────────────────────────────────────────────────

const search = asyncHandler(async (req, res) => {
  const role = req.user.role;
  const allowed = TYPES_FOR_ROLE[role];
  const requested = req.query.type && req.query.type !== 'all' ? [req.query.type] : allowed;
  const types = requested.filter((type) => allowed.includes(type));

  const filters = {
    q: (req.query.q || '').trim(),
    titleCode: req.query.titleCode || null,
    companyId: req.query.companyId || null,
    recruiterId: req.query.recruiterId || null,
    experience: req.query.experience || null,
    workMode: req.query.workMode || null,
    openToWork: req.query.openToWork || null,
    skill: req.query.skill || null,
    maxDistanceKm: req.query.maxDistanceKm || null,
    minOpenings: req.query.minOpenings || null,
    postedWithinDays: req.query.postedWithinDays || null,
    activeWithinDays: req.query.activeWithinDays || null,
    hiringNow: req.query.hiringNow === true || req.query.hiringNow === 'true',
    walkIn: req.query.walkIn === true || req.query.walkIn === 'true',
    remote: req.query.remote === true || req.query.remote === 'true',
    availableToday: req.query.availableToday === true || req.query.availableToday === 'true',
    openToFreshers: req.query.openToFreshers === true || req.query.openToFreshers === 'true',
    sort: req.query.sort || 'nearest',
    limit: req.query.limit || 25,
  };

  const [context, blocked] = await Promise.all([
    viewerContext(req.user),
    blockedUserIds(req.user._id),
  ]);

  const runners = {
    jobs: () => searchJobs(req, context, filters, blocked),
    recruiters: () => searchRecruiters(req, context, filters, blocked),
    companies: () => searchCompanies(req, context, filters),
    candidates: () => searchCandidates(req, context, filters, blocked),
  };

  const settled = await Promise.all(types.map((type) => runners[type]()));
  const results = {};
  const counts = {};
  types.forEach((type, index) => {
    results[type] = settled[index];
    counts[type] = settled[index].length;
  });

  res.json({
    success: true,
    data: {
      results,
      counts,
      meta: {
        query: filters.q,
        types: allowed,
        radiusKm: filters.maxDistanceKm || context.radiusKm,
        hasLocation: Boolean(context.point),
        areaLabel: context.areaLabel,
      },
    },
  });
});

module.exports = { search };
