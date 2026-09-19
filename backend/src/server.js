'use strict';

const env = require('./config/env');
const { createApp } = require('./app');
const { connectDatabase } = require('./config/db');
const { seedJobTitles } = require('./seed/seedJobTitles');
const JobTitle = require('./models/JobTitle');

async function start() {
  const app = createApp();

  try {
    await connectDatabase();
    console.log(`MongoDB connected — ${env.mongoUri.replace(/\/\/.*@/, '//***@')}`);

    // A first run against an empty database would otherwise leave the job-title
    // selector with nothing to show.
    const count = await JobTitle.estimatedDocumentCount();
    if (count === 0) {
      const summary = await seedJobTitles();
      console.log(`Job-title master seeded with ${summary.total} titles.`);
    }
  } catch (err) {
    console.error('MongoDB connection failed:', err.message);
    console.error('The API will start, but requests needing data will return SERVICE_UNAVAILABLE.');
  }

  const server = app.listen(env.port, () => {
    console.log(`TalentRadar API listening on http://localhost:${env.port}/api/v1`);
  });

  const shutdown = (signal) => {
    console.log(`\n${signal} received — shutting down.`);
    server.close(() => process.exit(0));
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start();
