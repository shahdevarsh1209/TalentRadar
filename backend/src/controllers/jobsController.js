'use strict';

const Job = require('../models/Job');
const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const { JobInterest, SavedItem } = require('../models/social');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { distanceKm, displayDistance } = require('../utils/geo');
const { resolveTitleCodes } = require('../services/jobTitleService');
const { summarize } = require('../services/peopleService');
const { openConversation, postMessage } = require('../services/chatService');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * The point a viewer searches from: a candidate's own precise point (never
 * returned to anyone), or the recruiter's company hiring location.
 */
async function viewerContext(user) {
  if (user.role === 'candidate') {
    const profile = await CandidateProfile.findOne({ userId: user._id }).select('+location.precise');
    return {
      point: profile?.location?.precise || profile?.location?.approximate || null,
      titleCodes: new Set((profile?.jobTitles || []).map((title) => title.code)),
      radiusKm: 10,
      areaLabel: profile?.location?.label || '',
    };
  }
  const profile = await RecruiterProfile.findOne({ userId: user._id });
  const hiring = profile?.hiringLocations?.[0];
  return {
    point: hiring?.approximate || null,
    titleCodes: new Set((profile?.hiringProfiles || []).map((title) => title.code)),
    radiusKm: profile?.hiringRadiusKm || 10,
    areaLabel: hiring?.label || '',
  };
}

/** Adds per-viewer flags (saved, interested) and distance to a page of jobs. */
async function decorate(jobs, user, point) {
  const ids = jobs.map((job) => job._id);
  const [saved, interests] = await Promise.all([
    SavedItem.find({ userId: user._id, kind: 'job', refId: { $in: ids } }).select('refId'),
    user.role === 'candidate'
      ? JobInterest.find({ candidateUserId: user._id, jobId: { $in: ids } }).select('jobId')
      : [],
  ]);
  const savedIds = new Set(saved.map((item) => String(item.refId)));
  const interestedIds = new Set(interests.map((item) => String(item.jobId)));

  return jobs.map((job) => {
    const km = point ? distanceKm(point, job.location?.approximate) : null;
    return job.toPublic({
      distanceKm: km === null ? null : displayDistance(km, { precise: true }),
      saved: savedIds.has(String(job._id)),
      interested: interestedIds.has(String(job._id)),
    });
  });
}

const createJob = asyncHandler(async (req, res) => {
  const recruiter = await RecruiterProfile.findOne({ userId: req.user._id });
  if (!recruiter) throw ApiError.notFound('We could not find your hiring profile.');

  const hiring = recruiter.hiringLocations?.[0];
  if (!hiring || !hiring.approximate) {
    throw ApiError.conflict(
      'HIRING_LOCATION_REQUIRED',
      'Set your company hiring location first, so nearby candidates can find this role.'
    );
  }

  const [title] = await resolveTitleCodes([req.body.titleCode], { fieldLabel: 'job title' });
  const body = req.body;

  if (body.salaryMin && body.salaryMax && body.salaryMin > body.salaryMax) {
    throw ApiError.validation('The minimum salary is higher than the maximum.', [
      { field: 'salaryMin', message: 'Minimum must not exceed maximum.' },
    ]);
  }

  const job = await Job.create({
    recruiterUserId: req.user._id,
    companyId: recruiter.companyId,
    companyName: recruiter.companyName,
    postedByName: recruiter.hrName,
    title,
    description: body.description || '',
    experienceLevel: body.experienceLevel,
    workMode: body.workMode,
    openings: body.openings,
    salaryMin: body.salaryMin ?? null,
    salaryMax: body.salaryMax ?? null,
    isWalkIn: Boolean(body.isWalkIn),
    walkIn: body.isWalkIn
      ? {
          date: new Date(body.walkIn.date),
          startTime: body.walkIn.startTime,
          endTime: body.walkIn.endTime,
          address: body.walkIn.address || hiring.label || '',
          instructions: body.walkIn.instructions || '',
        }
      : undefined,
    location: {
      source: hiring.source,
      approximate: hiring.approximate,
      privacyRadiusKm: hiring.privacyRadiusKm,
      area: hiring.area,
      city: hiring.city,
      state: hiring.state,
      country: hiring.country,
      pincode: hiring.pincode,
      label: hiring.label,
      updatedAt: new Date(),
    },
  });

  // A hiring profile the recruiter was not yet listing becomes part of it.
  if (!recruiter.hiringProfiles.some((item) => item.code === title.code)) {
    recruiter.hiringProfiles.push(title);
    await recruiter.save();
  }

  const [decorated] = await decorate([job], req.user, hiring.approximate);
  res.status(201).json({ success: true, data: { job: decorated } });
});

/**
 * The Jobs tab and the candidate radar. Nearby open roles sorted by distance,
 * followed by remote roles from anywhere (a remote job has no "near").
 */
const listJobs = asyncHandler(async (req, res) => {
  const { filter, q, sort, limit } = req.query;
  const context = await viewerContext(req.user);
  const radiusKm = req.query.radiusKm || context.radiusKm;

  const base = { status: 'open' };
  if (filter === 'walkins') base.isWalkIn = true;
  if (filter === 'remote') base.workMode = 'remote';
  if (q) {
    const pattern = new RegExp(escapeRegex(q), 'i');
    base.$or = [{ 'title.name': pattern }, { companyName: pattern }, { 'title.category': pattern }];
  }

  let jobs;
  if (context.point && filter !== 'remote' && sort !== 'newest') {
    const nearby = await Job.find({
      ...base,
      'location.approximate': {
        $nearSphere: { $geometry: context.point, $maxDistance: radiusKm * 1000 },
      },
    }).limit(limit);

    const remote =
      filter === 'walkins'
        ? []
        : await Job.find({
            ...base,
            workMode: 'remote',
            _id: { $nin: nearby.map((job) => job._id) },
          })
            .sort({ createdAt: -1 })
            .limit(Math.max(0, limit - nearby.length));
    jobs = [...nearby, ...remote];
  } else {
    jobs = await Job.find(base).sort({ createdAt: -1 }).limit(limit);
  }

  const decorated = await decorate(jobs, req.user, context.point);
  // Titles that match the viewer's own profile float to the top of equals.
  decorated.forEach((job) => {
    job.matchesProfile = context.titleCodes.has(job.title.code);
  });

  res.json({
    success: true,
    data: {
      jobs: decorated,
      meta: {
        total: decorated.length,
        nearbyCount: decorated.filter((job) => job.distanceKm !== null && job.distanceKm <= radiusKm).length,
        walkInsToday: decorated.filter((job) => job.walkInToday).length,
        radiusKm,
        hasLocation: Boolean(context.point),
        areaLabel: context.areaLabel,
        updatedAt: new Date(),
      },
    },
  });
});

const getJob = asyncHandler(async (req, res) => {
  const job = await Job.findById(req.params.jobId).catch(() => null);
  if (!job) throw ApiError.notFound('This role is no longer listed.');

  const context = await viewerContext(req.user);
  const [decorated] = await decorate([job], req.user, context.point);
  const people = await summarize([job.recruiterUserId]);

  res.json({
    success: true,
    data: {
      job: { ...decorated, matchesProfile: context.titleCodes.has(job.title.code) },
      postedBy: people.get(String(job.recruiterUserId)),
    },
  });
});

const myJobs = asyncHandler(async (req, res) => {
  const jobs = await Job.find({ recruiterUserId: req.user._id }).sort({ status: -1, createdAt: -1 });
  const context = await viewerContext(req.user);
  const decorated = await decorate(jobs, req.user, context.point);
  res.json({ success: true, data: { jobs: decorated } });
});

const setJobStatus = asyncHandler(async (req, res) => {
  const job = await Job.findOne({ _id: req.params.jobId, recruiterUserId: req.user._id }).catch(
    () => null
  );
  if (!job) throw ApiError.notFound('We could not find that role.');

  job.status = req.body.status;
  await job.save();
  const [decorated] = await decorate([job], req.user, null);
  res.json({ success: true, data: { job: decorated } });
});

/**
 * "I'm interested" / "Meet in person". Records interest once, and opens (or
 * reuses) the chat with the recruiter so the conversation can start at once.
 */
const expressInterest = asyncHandler(async (req, res) => {
  const job = await Job.findById(req.params.jobId).catch(() => null);
  if (!job || job.status !== 'open') throw ApiError.notFound('This role is no longer open.');

  let created = false;
  try {
    await JobInterest.create({
      jobId: job._id,
      candidateUserId: req.user._id,
      recruiterUserId: job.recruiterUserId,
    });
    created = true;
  } catch (err) {
    if (err.code !== 11000) throw err; // Already interested: carry on.
  }

  if (created) {
    job.interestCount += 1;
    await job.save();
  }

  const conversation = await openConversation(req.user, job.recruiterUserId, { jobId: job._id });
  if (created) {
    const candidate = await CandidateProfile.findOne({ userId: req.user._id });
    const when = job.isWalkIn ? ' I would like to attend the walk-in.' : '';
    await postMessage(conversation, req.user._id, {
      text: `Hi, I'm ${candidate?.name || 'interested'} — I'm interested in the ${job.title.name} role at ${job.companyName}.${when}`,
    });
  }

  res.status(created ? 201 : 200).json({
    success: true,
    data: { conversationId: conversation._id.toString(), alreadyInterested: !created },
  });
});

/** Candidates who raised their hand for one of the recruiter's roles. */
const jobInterests = asyncHandler(async (req, res) => {
  const job = await Job.findOne({ _id: req.params.jobId, recruiterUserId: req.user._id }).catch(
    () => null
  );
  if (!job) throw ApiError.notFound('We could not find that role.');

  const interests = await JobInterest.find({ jobId: job._id }).sort({ createdAt: -1 });
  const people = await summarize(interests.map((item) => item.candidateUserId));

  res.json({
    success: true,
    data: {
      job: job.toPublic(),
      candidates: interests.map((item) => ({
        ...people.get(String(item.candidateUserId)),
        status: item.status,
        interestedAt: item.createdAt,
      })),
    },
  });
});

module.exports = {
  createJob,
  listJobs,
  getJob,
  myJobs,
  setJobStatus,
  expressInterest,
  jobInterests,
  viewerContext,
};
