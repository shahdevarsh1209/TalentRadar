'use strict';

const mongoose = require('mongoose');
const { connectDatabase } = require('../config/db');
const JobTitle = require('../models/JobTitle');
const JOB_TITLES = require('./jobTitles.data');

/** Idempotent: re-running updates existing titles instead of duplicating them. */
async function seedJobTitles() {
  const operations = JOB_TITLES.map((title) => ({
    updateOne: {
      filter: { code: title.code },
      update: { $set: { ...title, isActive: true } },
      upsert: true,
    },
  }));

  const result = await JobTitle.bulkWrite(operations, { ordered: false });
  return {
    inserted: result.upsertedCount || 0,
    updated: result.modifiedCount || 0,
    total: JOB_TITLES.length,
  };
}

if (require.main === module) {
  (async () => {
    try {
      await connectDatabase();
      const summary = await seedJobTitles();
      console.log(
        `Job-title master seeded — ${summary.total} titles (${summary.inserted} new, ${summary.updated} updated).`
      );
      await mongoose.disconnect();
      process.exit(0);
    } catch (err) {
      console.error('Seeding failed:', err.message);
      process.exit(1);
    }
  })();
}

module.exports = { seedJobTitles };
