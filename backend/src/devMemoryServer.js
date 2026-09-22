'use strict';

/**
 * Runs the API against a local MongoDB that needs no installation.
 *
 *   npm run dev:memory   throwaway — the database is gone when the server stops
 *   npm run dev:local    keeps the database in backend/.data/mongo between runs
 *
 * Use dev:local while actually using the app, so accounts you create survive a
 * restart. Tests use dev:memory, which must start from a known clean state.
 */

const path = require('node:path');
const fs = require('node:fs');
const { MongoMemoryServer } = require('mongodb-memory-server');

(async () => {
  // A persistent run needs a directory of its own and a real storage engine;
  // the default ephemeral engine keeps everything in RAM.
  const persist = process.env.DEV_DB_PATH || (process.argv.includes('--persist')
    ? path.join(__dirname, '..', '.data', 'mongo')
    : null);
  if (persist) fs.mkdirSync(persist, { recursive: true });

  // First boot on a slow or busy machine can exceed the 10s library default.
  const mongo = await MongoMemoryServer.create({
    instance: {
      launchTimeout: 90000,
      ...(persist ? { dbPath: persist, storageEngine: 'wiredTiger' } : {}),
    },
  });
  process.env.MONGO_URI = mongo.getUri('talentradar');
  // A throwaway database is only useful for demos if it has something in it.
  if (process.env.SEED_DEMO === undefined) process.env.SEED_DEMO = 'true';
  // Automated test runs register and log in far more often than a person.
  if (process.env.AUTH_RATE_LIMIT === undefined) process.env.AUTH_RATE_LIMIT = '1000';
  console.log(persist
    ? `Local MongoDB started — data is kept in ${persist}`
    : 'In-memory MongoDB started — data will not persist.');

  const stop = async () => {
    await mongo.stop();
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);

  // server.js reads MONGO_URI at require time, so it must load after it is set.
  require('./server');
})().catch((err) => {
  console.error('Could not start in-memory MongoDB:', err.message);
  process.exit(1);
});
