const mongoose = require('mongoose');

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/neartalk';
  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 2500,
      socketTimeoutMS: 15000,
      maxPoolSize: 25,
      minPoolSize: 2,
    });
    console.log(`[Database] MongoDB Connected: ${conn.connection.host}`);
  } catch (err) {
    console.log(`[Database] Live MongoDB not reachable (${err.message}).`);
    console.log(`[Database] Running in-memory database store for seamless local execution.`);
  }

  mongoose.connection.on('error', (err) => {
    console.error(`[Database Error] ${err.message}`);
  });

  mongoose.connection.on('disconnected', () => {
    console.log('[Database] MongoDB connection lost. Falling back to in-memory store.');
  });
};

module.exports = {
  connectDB,
  isConnected: () => mongoose.connection.readyState === 1,
};
