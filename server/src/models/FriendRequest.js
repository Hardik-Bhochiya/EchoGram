const mongoose = require('mongoose');

const friendRequestSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  senderId: { type: String, required: true },
  senderUsername: { type: String, required: true },
  senderName: { type: String, required: true },
  senderAvatar: { type: String, default: '🎓' },
  receiverId: { type: String, required: true },
  receiverUsername: { type: String, required: true },
  receiverName: { type: String, required: true },
  status: { type: String, enum: ['pending', 'accepted', 'declined'], default: 'pending' },
}, { timestamps: true });

module.exports = mongoose.model('FriendRequest', friendRequestSchema);
