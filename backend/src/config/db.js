'use strict';

const mongoose = require('mongoose');
const env = require('./env');

async function connectDatabase() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri, {
    serverSelectionTimeoutMS: 10000,
    autoIndex: env.nodeEnv !== 'production',
  });
  return mongoose.connection;
}

module.exports = { connectDatabase };
