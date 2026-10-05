const mongoose = require('mongoose');

const communitySchema = new mongoose.Schema({
  id: { type: String },
  name: { type: String, required: true },
  description: { type: String, required: true },
  regionId: { type: String, default: 'general' },
  regionName: { type: String, default: 'General' },
  locationSpot: { type: String, default: 'General' },
  creatorId: { type: String, default: 'user-hardik' },
  category: { type: String, default: 'General' },
  memberCount: { type: Number, default: 1 },
  questionCount: { type: Number, default: 0 },
  iconEmoji: { type: String, default: '💬' },
  bannerColorHex: { type: Number, default: 0xFF6366F1 },
  rules: [{ type: String }],
  members: [{ type: String }],
}, { timestamps: true });

module.exports = mongoose.model('Community', communitySchema);

