const store = require('./store');
const Community = require('../models/Community');
const { isConnected } = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const normalizeCommunity = (c) => {
  const obj = c.toObject ? c.toObject() : c;
  return {
    ...obj,
    id: obj.id || (obj._id ? obj._id.toString() : uuidv4()),
    rules: obj.rules || [
      '1. Respect all members',
      '2. No spam or commercial promotions',
      '3. No abusive language or harassment',
      '4. Stay on topic and share relevant updates',
    ],
  };
};

exports.getCommunities = async (req, res) => {
  try {
    if (isConnected()) {
      const dbCommunities = await Community.find().sort({ createdAt: -1 });
      const normalized = dbCommunities.map(normalizeCommunity);

      // If DB has communities, merge with in-memory store so default campus communities are always available
      const existingIds = new Set(normalized.map((c) => c.id));
      for (const sc of store.communities) {
        if (!existingIds.has(sc.id)) {
          normalized.push(sc);
        }
      }

      return res.json({ success: true, count: normalized.length, data: normalized });
    } else {
      return res.json({ success: true, count: store.communities.length, data: store.communities });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getCommunityById = async (req, res) => {
  try {
    const { id } = req.params;
    if (isConnected()) {
      let community = await Community.findOne({ $or: [{ id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }] });
      if (!community) {
        community = store.communities.find((c) => c.id === id);
      }
      if (!community) return res.status(404).json({ success: false, message: 'Community not found' });
      return res.json({ success: true, data: normalizeCommunity(community) });
    } else {
      const community = store.communities.find((c) => c.id === id);
      if (!community) return res.status(404).json({ success: false, message: 'Community not found' });
      return res.json({ success: true, data: community });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createCommunity = async (req, res) => {
  try {
    const {
      id,
      name,
      description,
      category,
      iconEmoji,
      bannerColorHex,
      regionId,
      regionName,
      locationSpot,
      creatorId,
      rules,
    } = req.body;

    const commId = id || uuidv4();
    const effectiveRegionName = regionName || 'DDU, Nadiad, Gujarat';
    const effectiveRegionId = regionId || `region_${effectiveRegionName.toLowerCase().replace(/[^a-z0-9]/g, '')}`;

    const newCommunityData = {
      id: commId,
      name: name || 'Campus Community',
      description: description || 'Local discussion space',
      regionId: effectiveRegionId,
      regionName: effectiveRegionName,
      locationSpot: locationSpot || 'Campus / City Spot',
      creatorId: creatorId || 'user',
      category: category || 'Campus',
      memberCount: 1,
      questionCount: 0,
      iconEmoji: iconEmoji || '🎓',
      bannerColorHex: bannerColorHex || 0xFF6366F1,
      rules: rules || [
        '1. Respect all members',
        '2. No spam or commercial promotions',
        '3. No abusive language or harassment',
        '4. Stay on topic and share relevant updates',
      ],
      members: [creatorId || 'user'],
    };

    if (isConnected()) {
      try {
        await Community.create(newCommunityData);
      } catch (e) {
        console.error('[DB] Error creating community in MongoDB:', e);
      }
    }

    // Also update in-memory store
    store.communities.unshift(newCommunityData);

    return res.status(201).json({
      success: true,
      message: 'Community created successfully',
      data: newCommunityData,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteCommunity = async (req, res) => {
  try {
    const { id } = req.params;
    const { userId } = req.body;

    if (isConnected()) {
      await Community.deleteOne({ $or: [{ id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }] });
    }

    const idx = store.communities.findIndex((c) => c.id === id);
    if (idx !== -1) {
      store.communities.splice(idx, 1);
    }

    return res.json({ success: true, message: 'Community deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.toggleJoin = async (req, res) => {
  try {
    const { id } = req.params;
    let community = store.communities.find((c) => c.id === id);

    if (isConnected()) {
      const dbComm = await Community.findOne({ $or: [{ id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }] });
      if (dbComm) community = dbComm;
    }

    if (!community) return res.status(404).json({ success: false, message: 'Community not found' });

    community.isJoined = !community.isJoined;
    community.memberCount = community.isJoined ? (community.memberCount || 0) + 1 : Math.max(0, (community.memberCount || 1) - 1);

    if (community.save) {
      await community.save();
    }

    return res.json({ success: true, data: normalizeCommunity(community) });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

