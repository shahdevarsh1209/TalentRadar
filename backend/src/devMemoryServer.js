'use strict';

/**
 * Runs the API against a throwaway in-memory MongoDB. For demos and end-to-end
 * tests on a machine with no MongoDB installed — all data is lost on exit.
 *
 *   npm run dev:memory
 */

const { MongoMemoryServer } = require('mongodb-memory-server');

(async () => {
  const mongo = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongo.getUri('talentradar');
  console.log('In-memory MongoDB started — data will not persist.');

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
