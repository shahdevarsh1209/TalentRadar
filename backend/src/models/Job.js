'use strict';

const mongoose = require('mongoose');
const { locationSchema, publicLocation } = require('./location');
const { EXPERIENCE_VALUES, WORK_MODES } = require('../utils/constants');

const titleRefSchema = new mongoose.Schema(
  {
    code: { type: String, required: true },
    name: { type: String, required: true },
    category: { type: String, default: '' },
  },
  { _id: false }
);

/** A walk-in is an in-person drive on a specific day — the product's signature listing. */
const walkInSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    startTime: { type: String, required: true }, // "10:00", 24h
    endTime: { type: String, required: true },
    address: { type: String, trim: true, default: '' },
    instructions: { type: String, trim: true, default: '' },
  },
  { _id: false }
);

/**
 * A role a recruiter is hiring for. The title references the job-title master
 * by code, so candidates with the same code match exactly. Location is copied
 * from the company hiring location at posting time — a business address.
 */
const jobSchema = new mongoose.Schema(
  {
    recruiterUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    companyName: { type: String, required: true, trim: true },
    postedByName: { type: String, trim: true, default: '' },
    title: { type: titleRefSchema, required: true },
    description: { type: String, trim: true, default: '', maxlength: 2000 },
    experienceLevel: { type: String, enum: EXPERIENCE_VALUES, default: 'fresher' },
    workMode: { type: String, enum: WORK_MODES, required: true },
    openings: { type: Number, min: 1, max: 500, default: 1 },
    salaryMin: { type: Number, min: 0, default: null },
    salaryMax: { type: Number, min: 0, default: null },
    isWalkIn: { type: Boolean, default: false, index: true },
    walkIn: { type: walkInSchema, default: undefined },
    location: { type: locationSchema, default: () => ({}) },
    status: { type: String, enum: ['open', 'closed'], default: 'open', index: true },
    interestCount: { type: Number, default: 0 },
  },
  { timestamps: true, collection: 'jobs' }
);

jobSchema.index({ 'location.approximate': '2dsphere' });
jobSchema.index({ 'title.code': 1, status: 1 });

/** "Closing soon" when a walk-in is within 2 days, or a listing is 21+ days old. */
jobSchema.methods.isClosingSoon = function isClosingSoon() {
  const day = 24 * 60 * 60 * 1000;
  if (this.isWalkIn && this.walkIn?.date) {
    const until = this.walkIn.date.getTime() - Date.now();
    return until > -day && until < 2 * day;
  }
  return Date.now() - this.createdAt.getTime() > 21 * day;
};

jobSchema.methods.isWalkInToday = function isWalkInToday() {
  if (!this.isWalkIn || !this.walkIn?.date) return false;
  return new Date(this.walkIn.date).toDateString() === new Date().toDateString();
};

jobSchema.methods.toPublic = function toPublic({ distanceKm = null, saved = false, interested = false } = {}) {
  return {
    jobId: this._id.toString(),
    recruiterUserId: this.recruiterUserId.toString(),
    companyId: this.companyId.toString(),
    companyName: this.companyName,
    postedByName: this.postedByName,
    title: { code: this.title.code, name: this.title.name, category: this.title.category },
    description: this.description,
    experienceLevel: this.experienceLevel,
    workMode: this.workMode,
    openings: this.openings,
    salaryMin: this.salaryMin,
    salaryMax: this.salaryMax,
    isWalkIn: this.isWalkIn,
    walkIn: this.isWalkIn && this.walkIn
      ? {
          date: this.walkIn.date,
          startTime: this.walkIn.startTime,
          endTime: this.walkIn.endTime,
          address: this.walkIn.address,
          instructions: this.walkIn.instructions,
        }
      : null,
    walkInToday: this.isWalkInToday(),
    closingSoon: this.isClosingSoon(),
    location: publicLocation(this.location),
    distanceKm,
    status: this.status,
    interestCount: this.interestCount,
    saved,
    interested,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('Job', jobSchema);
