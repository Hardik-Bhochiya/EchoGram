const mongoose = require('mongoose');

const friendshipSchema = new mongoose.Schema({
  user1: { type: String, required: true }, // lowercase username
  user2: { type: String, required: true }, // lowercase username
}, { timestamps: true });

friendshipSchema.index({ user1: 1, user2: 1 }, { unique: true });

module.exports = mongoose.model('Friendship', friendshipSchema);
