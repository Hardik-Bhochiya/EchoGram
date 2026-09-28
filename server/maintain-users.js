const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./src/models/User');

const usersToEnsure = [
  {
    name: 'Hardik Bhochiya',
    username: 'hardik_07',
    email: 'hardik@gmail.com',
    password: 'password123',
    campusOrCity: 'DDU, Nadiad',
    majorOrBio: 'Computer Engineering | Tech & Community Builder',
    isCollegeVerified: true,
  },
  {
    name: 'Rahul Patel',
    username: 'rahul123',
    email: 'rahul@gmail.com',
    password: 'password123',
    campusOrCity: 'Mumbai',
    majorOrBio: 'Full Stack Engineer & Tech Explorer',
    isCollegeVerified: true,
  },
  {
    name: 'Priya Shah',
    username: 'priya_it',
    email: 'priya@gmail.com',
    password: 'password123',
    campusOrCity: 'Ahmedabad',
    majorOrBio: 'IT Student & Mobile UI Enthusiast',
    isCollegeVerified: true,
  },
  {
    name: 'Dhruv Chaudhari',
    username: 'dhruv_027',
    email: 'dhruvchaudhary@gmail.com',
    password: 'password123',
    campusOrCity: 'Mumbai',
    majorOrBio: 'Mumbai Community Member',
    isCollegeVerified: false,
  },
  {
    name: 'Gopal Italiya',
    username: 'gopal07',
    email: 'abcd@gmail.com',
    password: 'password123',
    campusOrCity: 'Nadiad',
    majorOrBio: 'Nadiad Community Member',
    isCollegeVerified: false,
  },
  {
    name: 'Hardik',
    username: 'hardik',
    email: 'ahirhardik027@gmail.com',
    password: 'password123',
    campusOrCity: 'DDU, Nadiad, Gujarat',
    majorOrBio: 'DDU Student',
    isCollegeVerified: true,
  },
];

async function maintainDatabase() {
  await mongoose.connect('mongodb://127.0.0.1:27017/neartalk');
  console.log('Connected to MongoDB.');

  const salt = await bcrypt.genSalt(10);
  const standardHash = await bcrypt.hash('password123', salt);

  // Directly set standardHash for all existing documents via MongoDB updateMany (bypasses pre-save hook)
  await mongoose.connection.db.collection('users').updateMany({}, {
    $set: { password: standardHash }
  });
  console.log('Reset all existing users passwords to password123');

  // Insert any missing users from usersToEnsure
  for (const u of usersToEnsure) {
    const existing = await User.findOne({
      $or: [{ username: u.username }, { email: u.email }]
    });

    if (!existing) {
      // create will trigger pre('save') and hash plain 'password123'
      await User.create(u);
      console.log(`Created user: ${u.username} (${u.name})`);
    } else {
      await mongoose.connection.db.collection('users').updateOne(
        { _id: existing._id },
        {
          $set: {
            name: u.name,
            username: u.username,
            email: u.email,
            password: standardHash,
            campusOrCity: u.campusOrCity,
            majorOrBio: u.majorOrBio,
            isCollegeVerified: u.isCollegeVerified,
          }
        }
      );
      console.log(`Updated user: ${u.username} (${u.name})`);
    }
  }

  const allUsers = await User.find({}).select('name username email campusOrCity');
  console.log('\n=========================================');
  console.log('NearTalk Database Users Maintained:');
  console.log('Default password for all accounts: password123');
  console.log('=========================================');
  allUsers.forEach((u, i) => {
    console.log(`${i + 1}. Name: ${u.name} | Username: @${u.username} | Email: ${u.email} | Location: ${u.campusOrCity}`);
  });
  console.log('=========================================\n');

  // Test bcrypt verification for each user
  for (const u of allUsers) {
    const full = await User.findById(u._id);
    const valid = await full.matchPassword('password123');
    console.log(`Verified login for @${u.username}: ${valid ? 'PASS' : 'FAIL'}`);
  }

  await mongoose.disconnect();
}

maintainDatabase().catch((err) => {
  console.error('Error maintaining database:', err);
  process.exit(1);
});
