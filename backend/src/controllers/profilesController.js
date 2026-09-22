'use strict';

/**
 * Public profile views: the recruiter behind a job, and the company behind the
 * recruiter. Both are read-only business identities — a recruiter's personal
 * whereabouts are never part of either, only the company's hiring location.
 */

const Job = require('../models/Job');
const User = require('../models/User');
const Company = require('../models/Company');
const RecruiterProfile = require('../models/RecruiterProfile');
const { SavedItem, Connection, Block, Report, pairKeyOf } = require('../models/social');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { distanceKm, displayDistance } = require('../utils/geo');
const { canViewRecruiter, initialsOf, summarize } = require('../services/peopleService');
const { hiringStatusByRecruiter, hiringStatusByCompany, mergeDeclaredWithLive } =
  require('../services/hiringService');
const { viewerContext } = require('./jobsController');

function connectionStatusFor(connection, meId) {
  if (!connection) return 'none';
  if (connection.status === 'accepted') return 'connected';
  if (connection.status !== 'pending') return 'none';
  return String(connection.requesterId) === String(meId) ? 'pending_sent' : 'pending_received';
}

/** GET /recruiters/:userId — the profile behind every recruiter card in the app. */
const recruiterProfile = asyncHandler(async (req, res) => {
  const profile = await RecruiterProfile.findOne({ userId: req.params.userId }).catch(() => null);
  if (!profile || !(await canViewRecruiter(req.user, profile))) {
    throw ApiError.notFound('This profile is no longer available.');
  }

  const isSelf = String(profile.userId) === String(req.user._id);
  const [context, status, saved, connection, company, account] = await Promise.all([
    viewerContext(req.user),
    hiringStatusByRecruiter([profile.userId]),
    SavedItem.exists({ userId: req.user._id, kind: 'person', refId: profile.userId }),
    Connection.findOne({ pairKey: pairKeyOf(req.user._id, profile.userId) }),
    Company.findById(profile.companyId).catch(() => null),
    User.findById(profile.userId).select('createdAt'),
  ]);

  const hiring = status.get(String(profile.userId));
  const hiringLocation = profile.hiringLocations?.[0] || null;
  const km = context.point ? distanceKm(context.point, hiringLocation?.approximate) : null;

  res.json({
    success: true,
    data: {
      recruiter: {
        userId: String(profile.userId),
        role: 'recruiter',
        name: profile.hrName,
        initials: initialsOf(profile.hrName),
        designation: profile.designation || 'Recruiter',
        companyId: String(profile.companyId),
        companyName: profile.companyName,
        companyIndustry: company?.industry || '',
        companySize: company?.size || '',
        // Advisory only: a work-domain address, not an identity check.
        verifiedEmailDomain: profile.isOfficialEmailDomain,
        companyVerification: company?.verificationStatus || 'unverified',
        area: hiringLocation?.label || '',
        city: hiringLocation?.city || '',
        distanceKm: km === null ? null : displayDistance(km, { precise: true }),
        hiringWorkModes: profile.hiringWorkModes,
        hiringRadiusKm: profile.hiringRadiusKm,
        memberSince: account?.createdAt || profile.createdAt,
        saved: Boolean(saved),
        isSelf,
      },
      hiringNow: hiring.hiringNow,
      totalOpenings: hiring.totalOpenings,
      openJobCount: hiring.openJobCount,
      // Declared hiring profiles, each marked with its live state.
      roles: mergeDeclaredWithLive(profile.hiringProfiles, hiring),
      connectionStatus: connectionStatusFor(connection, req.user._id),
      connectionId: connection ? String(connection._id) : null,
      // A candidate may always open a chat with a recruiter; see chatService.
      canMessage: !isSelf,
    },
  });
});

/** GET /companies/:companyId — every open role at one company, and who posts them. */
const companyProfile = asyncHandler(async (req, res) => {
  const company = await Company.findById(req.params.companyId).catch(() => null);
  if (!company) throw ApiError.notFound('We could not find that company.');

  const [context, status, recruiters] = await Promise.all([
    viewerContext(req.user),
    hiringStatusByCompany([company._id]),
    RecruiterProfile.find({ companyId: company._id }).limit(25),
  ]);

  const hiring = status.get(String(company._id));
  const office = company.officeLocations?.[0] || recruiters[0]?.hiringLocations?.[0] || null;
  const km = context.point ? distanceKm(context.point, office?.approximate) : null;

  const jobs = await Job.find({ companyId: company._id, status: 'open' })
    .sort({ createdAt: -1 })
    .limit(30);
  const savedJobs = await SavedItem.find({
    userId: req.user._id,
    kind: 'job',
    refId: { $in: jobs.map((job) => job._id) },
  }).select('refId');
  const savedIds = new Set(savedJobs.map((item) => String(item.refId)));

  res.json({
    success: true,
    data: {
      company: {
        companyId: String(company._id),
        name: company.name,
        initials: initialsOf(company.name),
        description: company.description,
        industry: company.industry,
        size: company.size,
        website: company.website,
        linkedinUrl: company.linkedinUrl,
        verificationStatus: company.verificationStatus,
        area: office?.label || '',
        city: office?.city || '',
        distanceKm: km === null ? null : displayDistance(km, { precise: true }),
      },
      hiringNow: hiring.hiringNow,
      totalOpenings: hiring.totalOpenings,
      roles: hiring.openRoles,
      jobs: jobs.map((job) =>
        job.toPublic({
          distanceKm: context.point
            ? displayDistance(distanceKm(context.point, job.location?.approximate), { precise: true })
            : null,
          saved: savedIds.has(String(job._id)),
        })
      ),
      // The people a candidate can actually talk to at this company.
      recruiters: recruiters.map((profile) => ({
        userId: String(profile.userId),
        name: profile.hrName,
        initials: initialsOf(profile.hrName),
        designation: profile.designation || 'Recruiter',
        role: 'recruiter',
        companyId: String(profile.companyId),
        companyName: profile.companyName,
        subtitle: [profile.designation || 'Hiring', profile.companyName].filter(Boolean).join(' · '),
      })),
    },
  });
});

/** PUT /blocks — block or unblock. Hides both people from each other everywhere. */
const setBlock = asyncHandler(async (req, res) => {
  const { userId, blocked } = req.body;
  if (String(userId) === String(req.user._id)) {
    throw ApiError.badRequest('You cannot block yourself.');
  }
  const target = await User.findById(userId).catch(() => null);
  if (!target) throw ApiError.notFound('That person is no longer on TalentRadar.');

  if (blocked) {
    await Block.updateOne(
      { userId: req.user._id, blockedUserId: target._id },
      { $setOnInsert: { pairKey: pairKeyOf(req.user._id, target._id) } },
      { upsert: true }
    );
    // A block should not leave the person sitting in your saved list.
    await SavedItem.deleteOne({ userId: req.user._id, kind: 'person', refId: target._id });
  } else {
    await Block.deleteOne({ userId: req.user._id, blockedUserId: target._id });
  }

  res.json({ success: true, data: { userId: String(target._id), blocked: Boolean(blocked) } });
});

const listBlocks = asyncHandler(async (req, res) => {
  const blocks = await Block.find({ userId: req.user._id }).sort({ createdAt: -1 });
  const people = await summarize(blocks.map((block) => block.blockedUserId));
  res.json({
    success: true,
    data: {
      blocked: blocks.map((block) => ({
        ...people.get(String(block.blockedUserId)),
        blockedAt: block.createdAt,
      })),
    },
  });
});

/** POST /reports — recorded for review; nothing is auto-actioned. */
const createReport = asyncHandler(async (req, res) => {
  const { subjectKind, subjectId, reason, details } = req.body;
  await Report.create({
    reporterId: req.user._id,
    subjectKind,
    subjectId,
    reason,
    details: details || '',
  });
  res.status(201).json({
    success: true,
    data: { received: true, message: 'Thanks — our team will review this.' },
  });
});

module.exports = { recruiterProfile, companyProfile, setBlock, listBlocks, createReport };
