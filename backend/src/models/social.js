'use strict';

/**
 * Relationship and activity records: interest in a job, saved items,
 * connection requests, profile views. Each is small, indexed for the one
 * query that reads it, and unique where a duplicate would be meaningless.
 */

const mongoose = require('mongoose');

const { ObjectId } = mongoose.Schema.Types;

// ── "I'm interested" / "Meet in person" on a job ─────────────────────────────
const jobInterestSchema = new mongoose.Schema(
  {
    jobId: { type: ObjectId, ref: 'Job', required: true, index: true },
    candidateUserId: { type: ObjectId, ref: 'User', required: true, index: true },
    recruiterUserId: { type: ObjectId, ref: 'User', required: true, index: true },
    status: {
      type: String,
      enum: ['interested', 'shortlisted', 'rejected'],
      default: 'interested',
    },
  },
  { timestamps: true, collection: 'job_interests' }
);
jobInterestSchema.index({ jobId: 1, candidateUserId: 1 }, { unique: true });

// ── Saved jobs and people ────────────────────────────────────────────────────
const savedItemSchema = new mongoose.Schema(
  {
    userId: { type: ObjectId, ref: 'User', required: true, index: true },
    kind: { type: String, enum: ['job', 'person'], required: true },
    refId: { type: ObjectId, required: true },
  },
  { timestamps: true, collection: 'saved_items' }
);
savedItemSchema.index({ userId: 1, kind: 1, refId: 1 }, { unique: true });

// ── Connection requests ──────────────────────────────────────────────────────
const connectionSchema = new mongoose.Schema(
  {
    requesterId: { type: ObjectId, ref: 'User', required: true, index: true },
    recipientId: { type: ObjectId, ref: 'User', required: true, index: true },
    // Sorted "a:b" so a pair can only ever have one connection record.
    pairKey: { type: String, required: true, unique: true },
    message: { type: String, trim: true, default: '', maxlength: 300 },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'ignored'],
      default: 'pending',
      index: true,
    },
    respondedAt: { type: Date, default: null },
  },
  { timestamps: true, collection: 'connections' }
);

// ── Recruiter viewed a candidate's profile ───────────────────────────────────
const profileViewSchema = new mongoose.Schema(
  {
    viewerUserId: { type: ObjectId, ref: 'User', required: true },
    candidateUserId: { type: ObjectId, ref: 'User', required: true, index: true },
    viewedOn: { type: String, required: true }, // YYYY-MM-DD, one row per viewer per day
  },
  { timestamps: true, collection: 'profile_views' }
);
profileViewSchema.index({ viewerUserId: 1, candidateUserId: 1, viewedOn: 1 }, { unique: true });

// ── Blocks ───────────────────────────────────────────────────────────────────
/**
 * Directional: A blocks B. Visibility is cut both ways regardless of who
 * blocked whom, so a block cannot be used to work out that it happened.
 */
const blockSchema = new mongoose.Schema(
  {
    userId: { type: ObjectId, ref: 'User', required: true, index: true },
    blockedUserId: { type: ObjectId, ref: 'User', required: true, index: true },
    pairKey: { type: String, required: true, index: true },
  },
  { timestamps: true, collection: 'blocks' }
);
blockSchema.index({ userId: 1, blockedUserId: 1 }, { unique: true });

// ── Reports ──────────────────────────────────────────────────────────────────
const reportSchema = new mongoose.Schema(
  {
    reporterId: { type: ObjectId, ref: 'User', required: true, index: true },
    subjectKind: { type: String, enum: ['person', 'job', 'company'], required: true },
    subjectId: { type: ObjectId, required: true, index: true },
    reason: {
      type: String,
      enum: ['spam', 'fake_profile', 'misleading_job', 'harassment', 'other'],
      required: true,
    },
    details: { type: String, trim: true, default: '', maxlength: 1000 },
    status: { type: String, enum: ['open', 'reviewed', 'actioned'], default: 'open', index: true },
  },
  { timestamps: true, collection: 'reports' }
);

function pairKeyOf(a, b) {
  return [String(a), String(b)].sort().join(':');
}

module.exports = {
  JobInterest: mongoose.model('JobInterest', jobInterestSchema),
  SavedItem: mongoose.model('SavedItem', savedItemSchema),
  Connection: mongoose.model('Connection', connectionSchema),
  ProfileView: mongoose.model('ProfileView', profileViewSchema),
  Block: mongoose.model('Block', blockSchema),
  Report: mongoose.model('Report', reportSchema),
  pairKeyOf,
};
