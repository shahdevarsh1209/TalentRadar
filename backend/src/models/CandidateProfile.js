'use strict';

const mongoose = require('mongoose');
const { locationSchema, publicLocation } = require('./location');
const {
  EXPERIENCE_VALUES,
  WORK_MODES,
  OPEN_TO_WORK,
  PROFILE_VISIBILITY,
  MAX_JOB_TITLES,
} = require('../utils/constants');

/** Denormalised title reference: code for matching, name for display. */
const titleRefSchema = new mongoose.Schema(
  {
    code: { type: String, required: true },
    name: { type: String, required: true },
    category: { type: String, default: '' },
  },
  { _id: false }
);

const candidateProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true, index: true },
    headline: { type: String, trim: true, default: '' },
    jobTitles: {
      type: [titleRefSchema],
      validate: [
        (value) => value.length > 0 && value.length <= MAX_JOB_TITLES,
        `Select between 1 and ${MAX_JOB_TITLES} job titles`,
      ],
    },
    experienceLevel: { type: String, enum: EXPERIENCE_VALUES, default: 'fresher' },
    // Filled in later from the detailed profile; the level above is enough to match on.
    experienceYears: { type: Number, default: null, min: 0, max: 60 },
    workModes: {
      type: [String],
      enum: WORK_MODES,
      validate: [(value) => value.length > 0, 'Select at least one work mode'],
    },
    openToWork: { type: String, enum: OPEN_TO_WORK, default: 'open_to_opportunities' },
    profileVisibility: { type: String, enum: PROFILE_VISIBILITY, default: 'recruiters_only' },
    // Ninja mode. Overrides visibility and removes the candidate from radar results.
    stealthMode: { type: Boolean, default: false },
    skills: { type: [String], default: [] },
    // Set by the centre 'go live' button; the candidate shows as available
    // today until this passes. Null means not currently live.
    availableUntil: { type: Date, default: null },
    // Privacy screen preferences.
    openToConnect: { type: Boolean, default: true },
    walkInAlerts: { type: Boolean, default: true },
    location: { type: locationSchema, default: () => ({}) },
    profileCompletion: { type: Number, default: 0, min: 0, max: 100 },
  },
  { timestamps: true, collection: 'candidate_profiles' }
);

// Radar queries: "available candidates near this point matching these titles".
candidateProfileSchema.index({ 'location.approximate': '2dsphere' });
candidateProfileSchema.index({ 'jobTitles.code': 1, openToWork: 1, stealthMode: 1 });

/** True when this candidate may appear in a recruiter's radar results. */
candidateProfileSchema.methods.isDiscoverable = function isDiscoverable() {
  if (this.stealthMode) return false;
  if (this.openToWork === 'not_looking') return false;
  return ['everyone', 'recruiters_only'].includes(this.profileVisibility);
};

candidateProfileSchema.methods.isAvailableToday = function isAvailableToday() {
  return Boolean(this.availableUntil && this.availableUntil.getTime() > Date.now());
};

candidateProfileSchema.methods.toPublic = function toPublic() {
  return {
    userId: this.userId.toString(),
    role: 'candidate',
    name: this.name,
    email: this.email,
    headline: this.headline,
    jobTitles: this.jobTitles.map((title) => ({
      code: title.code,
      name: title.name,
      category: title.category,
    })),
    experienceLevel: this.experienceLevel,
    experienceYears: this.experienceYears,
    workModes: this.workModes,
    openToWork: this.openToWork,
    profileVisibility: this.profileVisibility,
    stealthMode: this.stealthMode,
    availableToday: this.isAvailableToday(),
    availableUntil: this.availableUntil,
    openToConnect: this.openToConnect,
    walkInAlerts: this.walkInAlerts,
    skills: this.skills,
    location: publicLocation(this.location),
    profileCompletion: this.profileCompletion,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('CandidateProfile', candidateProfileSchema);
