'use strict';

const mongoose = require('mongoose');
const { locationSchema, publicLocation } = require('./location');
const { PROFILE_VISIBILITY, WORK_MODES, MAX_HIRING_PROFILES } = require('../utils/constants');

const titleRefSchema = new mongoose.Schema(
  {
    code: { type: String, required: true },
    name: { type: String, required: true },
    category: { type: String, default: '' },
  },
  { _id: false }
);

const recruiterProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    companyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    companyName: { type: String, required: true, trim: true },
    hrName: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true, index: true },
    designation: { type: String, trim: true, default: '' },
    // True when the address domain is not a free mail provider. Advisory only —
    // a recruiter on a generic domain is never blocked from registering.
    isOfficialEmailDomain: { type: Boolean, default: false },
    hiringProfiles: {
      type: [titleRefSchema],
      validate: [
        (value) => value.length > 0 && value.length <= MAX_HIRING_PROFILES,
        `Select between 1 and ${MAX_HIRING_PROFILES} hiring profiles`,
      ],
    },
    hiringWorkModes: { type: [String], enum: WORK_MODES, default: [] },
    /**
     * Where the company hires. This is a business location and is deliberately
     * NOT the recruiter's personal whereabouts — the radar map renders these.
     */
    hiringLocations: { type: [locationSchema], default: [] },
    hiringRadiusKm: { type: Number, default: 10, min: 1, max: 100 },
    profileVisibility: { type: String, enum: PROFILE_VISIBILITY, default: 'everyone' },
    profileCompletion: { type: Number, default: 0, min: 0, max: 100 },
  },
  { timestamps: true, collection: 'recruiter_profiles' }
);

recruiterProfileSchema.index({ 'hiringLocations.approximate': '2dsphere' });
recruiterProfileSchema.index({ 'hiringProfiles.code': 1 });

recruiterProfileSchema.methods.toPublic = function toPublic() {
  return {
    userId: this.userId.toString(),
    role: 'recruiter',
    companyId: this.companyId.toString(),
    companyName: this.companyName,
    hrName: this.hrName,
    email: this.email,
    designation: this.designation,
    isOfficialEmailDomain: this.isOfficialEmailDomain,
    hiringProfiles: this.hiringProfiles.map((title) => ({
      code: title.code,
      name: title.name,
      category: title.category,
    })),
    hiringWorkModes: this.hiringWorkModes,
    hiringLocations: (this.hiringLocations || []).map(publicLocation),
    hiringRadiusKm: this.hiringRadiusKm,
    profileVisibility: this.profileVisibility,
    profileCompletion: this.profileCompletion,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('RecruiterProfile', recruiterProfileSchema);
