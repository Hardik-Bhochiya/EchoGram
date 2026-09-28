const mongoose = require('mongoose');
const Community = require('../models/Community');
const { Question } = require('../models/Question');
const User = require('../models/User');
const store = require('../controllers/store');

let isConnected = false;

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/neartalk';
  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 2000,
    });
    isConnected = true;
    console.log(`[Database] MongoDB Connected: ${conn.connection.host}`);
  } catch (err) {
    console.log(`[Database] Live MongoDB not reachable (${err.message}).`);
    console.log(`[Database] Running in-memory database store for seamless local execution.`);
    isConnected = false;
  }
};

module.exports = { connectDB, isConnected: () => isConnected };
