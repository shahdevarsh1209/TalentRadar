'use strict';

/**
 * "Hiring Now" is never stored. It is derived from open jobs every time it is
 * asked for, so closing a role stops it appearing as active in search, on the
 * radar, on the recruiter profile and on the company profile at the same
 * moment — there is no second copy of the status to fall out of step.
 *
 * A recruiter's `hiringProfiles` list stays what it is: the roles they say they
 * recruit for. This layer answers the different question "which of those are
 * live right now, and how many seats are open?".
 */

const Job = require('../models/Job');

/** Sums open jobs per title code for one owner (a recruiter or a company). */
function foldByTitle(jobs) {
  const byCode = new Map();
  jobs.forEach((job) => {
    const code = job.title.code;
    const entry = byCode.get(code) || {
      code,
      name: job.title.name,
      category: job.title.category || '',
      openings: 0,
      jobCount: 0,
      jobId: String(job._id),
      workMode: job.workMode,
      isWalkIn: false,
      area: job.location?.area || job.location?.city || '',
      postedAt: job.createdAt,
    };
    entry.openings += job.openings || 1;
    entry.jobCount += 1;
    entry.isWalkIn = entry.isWalkIn || Boolean(job.isWalkIn);
    // Surface the most recent posting as the one a tap should open.
    if (job.createdAt > entry.postedAt) {
      entry.postedAt = job.createdAt;
      entry.jobId = String(job._id);
    }
    byCode.set(code, entry);
  });
  return [...byCode.values()].sort((a, b) => b.openings - a.openings);
}

/**
 * Live hiring state for a set of recruiters, keyed by user id. Every recruiter
 * asked for gets an entry, so callers never have to guard for a missing key.
 */
async function hiringStatusByRecruiter(recruiterUserIds) {
  const ids = [...new Set(recruiterUserIds.map(String))];
  const result = new Map(
    ids.map((id) => [id, { hiringNow: false, openRoles: [], totalOpenings: 0, openJobCount: 0 }])
  );
  if (ids.length === 0) return result;

  const jobs = await Job.find({ recruiterUserId: { $in: ids }, status: 'open' });
  const byRecruiter = new Map();
  jobs.forEach((job) => {
    const id = String(job.recruiterUserId);
    if (!byRecruiter.has(id)) byRecruiter.set(id, []);
    byRecruiter.get(id).push(job);
  });

  byRecruiter.forEach((ownJobs, id) => {
    const openRoles = foldByTitle(ownJobs);
    result.set(id, {
      hiringNow: openRoles.length > 0,
      openRoles,
      totalOpenings: openRoles.reduce((sum, role) => sum + role.openings, 0),
      openJobCount: ownJobs.length,
    });
  });

  return result;
}

/** The same, aggregated across every recruiter at a company. */
async function hiringStatusByCompany(companyIds) {
  const ids = [...new Set(companyIds.map(String))];
  const result = new Map(
    ids.map((id) => [id, { hiringNow: false, openRoles: [], totalOpenings: 0, openJobCount: 0 }])
  );
  if (ids.length === 0) return result;

  const jobs = await Job.find({ companyId: { $in: ids }, status: 'open' });
  const byCompany = new Map();
  jobs.forEach((job) => {
    const id = String(job.companyId);
    if (!byCompany.has(id)) byCompany.set(id, []);
    byCompany.get(id).push(job);
  });

  byCompany.forEach((ownJobs, id) => {
    const openRoles = foldByTitle(ownJobs);
    result.set(id, {
      hiringNow: openRoles.length > 0,
      openRoles,
      totalOpenings: openRoles.reduce((sum, role) => sum + role.openings, 0),
      openJobCount: ownJobs.length,
    });
  });

  return result;
}

/**
 * Merges a recruiter's declared hiring profiles with their live openings, so a
 * profile can show every role they recruit for and mark only the live ones.
 */
function mergeDeclaredWithLive(hiringProfiles, status) {
  const live = new Map(status.openRoles.map((role) => [role.code, role]));
  const merged = (hiringProfiles || []).map((title) => {
    const open = live.get(title.code);
    live.delete(title.code);
    return {
      code: title.code,
      name: title.name,
      category: title.category || '',
      hiringNow: Boolean(open),
      openings: open?.openings || 0,
      jobId: open?.jobId || null,
      isWalkIn: open?.isWalkIn || false,
      area: open?.area || '',
    };
  });

  // A role posted without being on the declared list still belongs on the
  // profile — the posting is the stronger signal of what they are hiring for.
  live.forEach((role) => {
    merged.push({
      code: role.code,
      name: role.name,
      category: role.category,
      hiringNow: true,
      openings: role.openings,
      jobId: role.jobId,
      isWalkIn: role.isWalkIn,
      area: role.area,
    });
  });

  // Live roles first, then the rest alphabetically.
  return merged.sort((a, b) => {
    if (a.hiringNow !== b.hiringNow) return a.hiringNow ? -1 : 1;
    if (a.openings !== b.openings) return b.openings - a.openings;
    return a.name.localeCompare(b.name);
  });
}

module.exports = { hiringStatusByRecruiter, hiringStatusByCompany, mergeDeclaredWithLive };
