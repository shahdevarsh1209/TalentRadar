'use strict';

const User = require('../models/User');
const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const { Connection, Block, pairKeyOf } = require('../models/social');

function initialsOf(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'TR';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

/**
 * Compact public card for a set of users, keyed by id. It carries area words
 * only — never coordinates — and is what chats, requests and saved lists show.
 */
async function summarize(userIds) {
  const ids = [...new Set(userIds.map(String))];
  if (ids.length === 0) return new Map();

  const [users, candidates, recruiters] = await Promise.all([
    User.find({ _id: { $in: ids } }).select('role'),
    CandidateProfile.find({ userId: { $in: ids } }),
    RecruiterProfile.find({ userId: { $in: ids } }),
  ]);

  const roleById = new Map(users.map((user) => [String(user._id), user.role]));
  const result = new Map();

  candidates.forEach((profile) => {
    const id = String(profile.userId);
    result.set(id, {
      userId: id,
      role: 'candidate',
      name: profile.name,
      initials: initialsOf(profile.name),
      headline: profile.jobTitles[0]?.name || profile.headline || '',
      subtitle: [profile.jobTitles[0]?.name, profile.location?.area || profile.location?.city]
        .filter(Boolean)
        .join(' · '),
      availableToday: profile.isAvailableToday() && !profile.stealthMode,
    });
  });

  recruiters.forEach((profile) => {
    const id = String(profile.userId);
    result.set(id, {
      userId: id,
      role: 'recruiter',
      name: profile.hrName,
      initials: initialsOf(profile.hrName),
      headline: profile.designation || 'Recruiter',
      subtitle: [profile.designation || 'Hiring', profile.companyName].filter(Boolean).join(' · '),
      companyName: profile.companyName,
      // Lets a card link straight through to the company profile.
      companyId: String(profile.companyId),
      area: profile.hiringLocations?.[0]?.label || '',
      availableToday: false,
    });
  });

  // A user whose profile is missing still gets a harmless placeholder card.
  ids.forEach((id) => {
    if (!result.has(id)) {
      result.set(id, {
        userId: id,
        role: roleById.get(id) || 'candidate',
        name: 'TalentRadar member',
        initials: 'TR',
        headline: '',
        subtitle: '',
        availableToday: false,
      });
    }
  });

  return result;
}

/**
 * True when either person has blocked the other. A block hides both ways, so
 * neither side can infer from the other's disappearance that it was them.
 */
async function isBlocked(userA, userB) {
  const block = await Block.findOne({ pairKey: pairKeyOf(userA, userB) });
  return Boolean(block);
}

/** Every user id this person has blocked or been blocked by, for query filters. */
async function blockedUserIds(userId) {
  const blocks = await Block.find({
    $or: [{ userId }, { blockedUserId: userId }],
  }).select('userId blockedUserId');
  const ids = new Set();
  blocks.forEach((block) => {
    ids.add(String(block.userId));
    ids.add(String(block.blockedUserId));
  });
  ids.delete(String(userId));
  return [...ids];
}

async function areConnected(userA, userB) {
  const connection = await Connection.findOne({
    pairKey: pairKeyOf(userA, userB),
    status: 'accepted',
  });
  return Boolean(connection);
}

/**
 * The one visibility rule for a candidate profile, applied everywhere a
 * candidate can be seen. Ninja mode and "not looking" hide them from
 * discovery; an accepted connection always keeps access.
 */
async function canViewCandidate(viewer, candidateProfile) {
  if (String(viewer._id) === String(candidateProfile.userId)) return true;
  // A block outranks every other rule, including an existing connection.
  if (await isBlocked(viewer._id, candidateProfile.userId)) return false;
  if (await areConnected(viewer._id, candidateProfile.userId)) return true;
  if (candidateProfile.stealthMode) return false;

  switch (candidateProfile.profileVisibility) {
    case 'everyone':
      return true;
    case 'recruiters_only':
      return viewer.role === 'recruiter';
    default:
      return false; // connections_only and private need a connection
  }
}

/**
 * A recruiter profile is a business identity — the point of TalentRadar is that
 * candidates can find out who is hiring — so it is visible to any signed-in
 * member. Only a block hides it. Personal whereabouts are never part of it.
 */
async function canViewRecruiter(viewer, recruiterProfile) {
  if (String(viewer._id) === String(recruiterProfile.userId)) return true;
  return !(await isBlocked(viewer._id, recruiterProfile.userId));
}

module.exports = {
  summarize,
  initialsOf,
  areConnected,
  canViewCandidate,
  canViewRecruiter,
  isBlocked,
  blockedUserIds,
};
