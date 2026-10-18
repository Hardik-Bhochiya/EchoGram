const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  id: { type: String, index: true },
  roomId: { type: String, required: true },
  senderId: { type: String, required: true },
  senderName: { type: String, required: true },
  senderAvatar: { type: String },
  content: { type: String, required: true },
  isAnonymous: { type: Boolean, default: false },
  type: { type: String, default: 'text' },
  likes: [{ type: String }],
  dislikes: [{ type: String }],
  isEdited: { type: Boolean, default: false },
  isDeleted: { type: Boolean, default: false },
}, { timestamps: true });

messageSchema.index({ roomId: 1, createdAt: 1 });
messageSchema.index({ roomId: 1 });

const roomSchema = new mongoose.Schema({
  title: { type: String, required: true },
  subtitle: { type: String },
  avatarEmoji: { type: String, default: '💬' },
  communityId: { type: String },
  isGroup: { type: Boolean, default: false },
  lastMessage: { type: String, default: '' },
  lastMessageTime: { type: Date, default: Date.now },
  participantIds: [{ type: String }],
}, { timestamps: true });

roomSchema.index({ lastMessageTime: -1 });
roomSchema.index({ communityId: 1 });

module.exports = {
  Message: mongoose.model('Message', messageSchema),
  Room: mongoose.model('Room', roomSchema),
};
