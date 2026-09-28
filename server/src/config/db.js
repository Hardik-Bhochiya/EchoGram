const mongoose = require('mongoose');
const Community = require('../models/Community');
const { Question } = require('../models/Question');
const User = require('../models/User');
const store = require('../controllers/store');

let isConnected = false;

const seedDatabaseIfEmpty = async () => {
  try {
    const count = await Community.countDocuments();
    if (count === 0) {
      console.log('[Database] Seeding initial DDU communities and questions into MongoDB...');
      for (const c of store.communities) {
        await Community.create({
          name: c.name,
          description: c.description,
          regionId: c.regionId,
          regionName: c.regionName,
          category: c.category,
          memberCount: c.memberCount,
          questionCount: c.questionCount,
          iconEmoji: c.iconEmoji,
          bannerColorHex: c.bannerColorHex,
          rules: c.rules,
        });
      }
      for (const q of store.questions) {
        await Question.create({
          title: q.title,
          content: q.content,
          communityId: q.communityId,
          communityName: q.communityName,
          regionId: q.regionId,
          regionName: q.regionName,
          authorId: q.authorId,
          authorName: q.authorName,
          authorBadge: q.authorBadge,
          isAnonymous: q.isAnonymous,
          anonymousPseudonym: q.anonymousPseudonym,
          tags: q.tags,
          upvotes: q.upvotes,
          views: q.views,
          replies: q.replies,
          isResolved: q.isResolved,
        });
      }
      console.log('[Database] MongoDB seed completed successfully!');
    }

    const userCount = await User.countDocuments();
    if (userCount <= 1) {
      console.log('[Database] Seeding default campus users into MongoDB...');
      for (const u of store.users) {
        const exists = await User.findOne({ username: u.username });
        if (!exists) {
          await User.create({
            name: u.name,
            username: u.username,
            email: u.email,
            password: 'password123',
            campusOrCity: u.campusOrCity,
            majorOrBio: u.majorOrBio,
            reputation: u.reputation,
            joinedCommunityIds: u.joinedCommunityIds,
            badges: u.badges,
            isCollegeVerified: u.isCollegeVerified,
          });
        }
      }
      console.log('[Database] Campus users seeded into MongoDB!');
    }
  } catch (err) {
    console.error('[Database Seed Error]', err.message);
  }
};

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/neartalk';
  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 2000,
    });
    isConnected = true;
    console.log(`[Database] MongoDB Connected: ${conn.connection.host}`);
    await seedDatabaseIfEmpty();
  } catch (err) {
    console.log(`[Database] Live MongoDB not reachable (${err.message}).`);
    console.log(`[Database] Running in-memory database store for seamless local execution.`);
    isConnected = false;
  }
};

module.exports = { connectDB, isConnected: () => isConnected };
