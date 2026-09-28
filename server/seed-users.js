const mongoose = require('mongoose');
const User = require('./src/models/User');

const demoUsers = [
  {
    name: 'Hardik Bhochiya',
    username: 'hardik_07',
    email: 'hardik@gmail.com',
    password: 'password123',
    campusOrCity: 'Nadiad',
    majorOrBio: 'Computer Engineering | Tech & Community Builder',
    reputation: 240,
    joinedCommunityIds: ['c-mumbai-dev', 'c-ddu-students'],
    badges: ['Top Contributor', 'DDU Verified'],
    isCollegeVerified: true,
  },
  {
    name: 'Rahul Patel',
    username: 'rahul123',
    email: 'rahul@gmail.com',
    password: 'password123',
    campusOrCity: 'Mumbai',
    majorOrBio: 'Mumbai Developers • Full Stack Engineer',
    reputation: 160,
    joinedCommunityIds: ['c-mumbai-dev'],
    badges: ['Campus Ambassador'],
    isCollegeVerified: true,
  },
  {
    name: 'Priya Shah',
    username: 'priya_it',
    email: 'priya@gmail.com',
    password: 'password123',
    campusOrCity: 'Ahmedabad',
    majorOrBio: 'Ahmedabad Students • Tech Enthusiast',
    reputation: 180,
    joinedCommunityIds: ['c-ahmedabad-students'],
    badges: ['Quiz Master'],
    isCollegeVerified: true,
  },
  {
    name: 'Dev Shah',
    username: 'devshah',
    email: 'dev@gmail.com',
    password: 'password123',
    campusOrCity: 'Dwarka',
    majorOrBio: 'Dwarka Developers • Mobile App Builder',
    reputation: 120,
    joinedCommunityIds: [],
    badges: ['New Member'],
    isCollegeVerified: true,
  },
];

async function seed() {
  await mongoose.connect('mongodb://127.0.0.1:27017/neartalk');
  console.log('Connected to MongoDB.');

  for (const du of demoUsers) {
    const existing = await User.findOne({
      $or: [{ email: du.email }, { username: du.username }]
    });
    if (!existing) {
      await User.create(du);
      console.log('Created user:', du.username);
    } else {
      existing.name = du.name;
      existing.username = du.username;
      existing.password = du.password;
      existing.campusOrCity = du.campusOrCity;
      existing.majorOrBio = du.majorOrBio;
      existing.reputation = du.reputation;
      existing.isCollegeVerified = du.isCollegeVerified;
      existing.joinedCommunityIds = du.joinedCommunityIds;
      existing.badges = du.badges;
      await existing.save();
      console.log('Updated user:', du.username);
    }
  }

  const all = await User.find().select('username email name');
  console.log('Current MongoDB users:', all);
  await mongoose.disconnect();
}

seed().catch(console.error);
