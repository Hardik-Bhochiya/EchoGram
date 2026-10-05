const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  username: { type: String, unique: true, sparse: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  campusOrCity: { type: String, default: '' },
  majorOrBio: { type: String, default: 'Hey there! I am using EchoGram' },
  reputation: { type: Number, default: 50 },
  joinedCommunityIds: [{ type: String }],
  badges: [{ type: String }],
  isCollegeVerified: { type: Boolean, default: false },
  avatarUrl: { type: String, default: '👤' },
}, { timestamps: true });

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
