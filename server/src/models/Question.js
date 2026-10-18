const mongoose = require('mongoose');

const replySchema = new mongoose.Schema({
  questionId: { type: String, required: true },
  content: { type: String, required: true },
  authorId: { type: String, required: true },
  authorName: { type: String, required: true },
  authorAvatar: { type: String },
  isAnonymous: { type: Boolean, default: false },
  anonymousPseudonym: { type: String },
  upvotes: { type: Number, default: 0 },
  isAccepted: { type: Boolean, default: false },
}, { timestamps: true });

const questionSchema = new mongoose.Schema({
  title: { type: String, required: true },
  content: { type: String, default: '' },
  communityId: { type: String, required: true },
  communityName: { type: String, required: true },
  regionId: { type: String, default: 'region-ddu' },
  regionName: { type: String, default: 'DDU, Nadiad, Gujarat' },
  authorId: { type: String, required: true },
  authorName: { type: String, required: true },
  authorAvatar: { type: String },
  authorBadge: { type: String },
  isAnonymous: { type: Boolean, default: false },
  anonymousPseudonym: { type: String },
  tags: [{ type: String }],
  upvotes: { type: Number, default: 0 },
  views: { type: Number, default: 1 },
  replies: [replySchema],
  isResolved: { type: Boolean, default: false },
  bookmarkedBy: [{ type: String }],
}, { timestamps: true });

questionSchema.index({ communityId: 1, createdAt: -1 });
questionSchema.index({ regionId: 1 });

module.exports = {
  Question: mongoose.model('Question', questionSchema),
  Reply: mongoose.model('Reply', replySchema),
};
