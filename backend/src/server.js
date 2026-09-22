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

    if (process.env.SEED_DEMO === 'true' && env.nodeEnv !== 'production') {
      const { seedDemo, DEMO_PASSWORD } = require('./seed/demoData');
      try {
        const demo = await seedDemo();
        if (demo.created) {
          console.log(`Demo data: ${demo.recruiters} recruiters, ${demo.candidates} candidates, ${demo.jobs} roles (password ${DEMO_PASSWORD}).`);
        }
      } catch (err) {
        console.error('Demo data could not be seeded:', err.message);
      }
    }
  } catch (err) {
    console.error('MongoDB connection failed:', err.message);
    console.error('The API will start, but requests needing data will return SERVICE_UNAVAILABLE.');
  }

  const server = app.listen(env.port, () => {
    console.log(`TalentRadar API listening on http://localhost:${env.port}/api/v1`);
  });

  // The common one by far is a previous run still holding the port. Say so,
  // rather than printing a stack trace that buries the actual problem.
  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(
        `Port ${env.port} is already in use — another TalentRadar API is probably still running.\n` +
          'Stop it first, or start this one on a different port with PORT=4001.'
      );
      process.exit(1);
    }
    throw err;
  });

  const shutdown = (signal) => {
    console.log(`\n${signal} received — shutting down.`);
    server.close(() => process.exit(0));
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start();
