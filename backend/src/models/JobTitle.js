'use strict';

const mongoose = require('mongoose');

/**
 * Job-title master. Candidates and recruiters both reference these documents by
 * `code` (JT_001…) so a candidate's "Software Support Executive" and a
 * recruiter's are provably the same thing at match time.
 */
const jobTitleSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, trim: true },
    name: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true, index: true },
    aliases: { type: [String], default: [] },
    // Drives default ordering so the common titles surface before the long tail.
    popularity: { type: Number, default: 0, index: true },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true, collection: 'job_titles' }
);

// Weighted so a name hit outranks an alias hit for the same query.
jobTitleSchema.index(
  { name: 'text', aliases: 'text', category: 'text' },
  { weights: { name: 10, aliases: 5, category: 1 }, name: 'job_title_search' }
);

jobTitleSchema.methods.toPublic = function toPublic() {
  return {
    code: this.code,
    name: this.name,
    category: this.category,
    aliases: this.aliases,
  };
};

module.exports = mongoose.model('JobTitle', jobTitleSchema);
