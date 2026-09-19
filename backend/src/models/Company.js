'use strict';

const mongoose = require('mongoose');
const { locationSchema } = require('./location');

/**
 * Companies exist separately from the recruiter who registered first, so a
 * second recruiter from the same company joins the existing company rather than
 * creating a duplicate. Everything past `name` belongs to profile completion.
 */
const companySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // Lowercased, punctuation-stripped name used to detect duplicates.
    slug: { type: String, required: true, unique: true, index: true },
    description: { type: String, trim: true, default: '' },
    industry: { type: String, trim: true, default: '' },
    size: {
      type: String,
      enum: ['1-10', '11-50', '51-200', '201-500', '501-1000', '1000+', ''],
      default: '',
    },
    website: { type: String, trim: true, default: '' },
    linkedinUrl: { type: String, trim: true, default: '' },
    logoUrl: { type: String, trim: true, default: '' },
    // Office / hiring locations. These are business addresses and are public.
    officeLocations: { type: [locationSchema], default: [] },
    verificationStatus: {
      type: String,
      enum: ['unverified', 'pending', 'verified', 'rejected'],
      default: 'unverified',
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { timestamps: true, collection: 'companies' }
);

companySchema.statics.toSlug = function toSlug(name) {
  return String(name)
    .toLowerCase()
    .replace(/(private|pvt|limited|ltd|llp|inc|corp)\b/g, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();
};

companySchema.methods.toPublic = function toPublic() {
  return {
    companyId: this._id.toString(),
    name: this.name,
    industry: this.industry,
    size: this.size,
    website: this.website,
    logoUrl: this.logoUrl,
    verificationStatus: this.verificationStatus,
  };
};

module.exports = mongoose.model('Company', companySchema);
