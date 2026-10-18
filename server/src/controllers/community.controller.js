const store = require('./store');
const Community = require('../models/Community');
const User = require('../models/User');
const { isConnected } = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const normalizeCommunity = (c, userIdentifier, userResolvedMap) => {
  const obj = c.toObject ? c.toObject() : { ...c };
  const members = Array.isArray(obj.members) ? obj.members : [];

  let isJoined = false;
  if (userIdentifier) {
    const cleanUser = String(userIdentifier).toLowerCase().replace(/^@/, '').trim();
    const cleanCreator = String(obj.creatorId || '').toLowerCase().replace(/^@/, '').trim();

    // A user is joined ONLY if they are explicitly in the members list or are the creator
    if (cleanCreator === cleanUser && cleanCreator.length > 0) {
      isJoined = true;
    } else {
      isJoined = members.some((m) => {
        const cleanM = String(m).toLowerCase().replace(/^@/, '').trim();
        return cleanM === cleanUser;
      });
    }

    // Also check through resolved aliases (id <-> username) if provided
    if (!isJoined && userResolvedMap) {
      const aliases = userResolvedMap.get(cleanUser) || [];
      for (const alias of aliases) {
        if (cleanCreator === alias || members.some((m) => String(m).toLowerCase().replace(/^@/, '').trim() === alias)) {
          isJoined = true;
          break;
        }
      }
    }
  }

  // Remove static isJoined on the document so it never bleeds to other users
  delete obj.isJoined;

  return {
    ...obj,
    id: obj.id || (obj._id ? obj._id.toString() : uuidv4()),
    members,
    isJoined: Boolean(isJoined),
    memberCount: members.length > 0 ? members.length : (obj.memberCount || 1),
    rules: obj.rules || [
      '1. Treat all members with respect and courtesy.',
      '2. No abusive language, harassment, or hate speech.',
      '3. No commercial spam or unauthorized promotions.',
      '4. Keep discussions genuine and relevant.',
    ],
  };
};

exports.getCommunities = async (req, res) => {
  try {
    const rawUser = (req.query.userId || req.query.username || '').trim();
    let userResolvedMap = null;

    if (rawUser && isConnected()) {
      try {
        const uDoc = await User.findOne({
          $or: [
            { _id: rawUser.match(/^[0-9a-fA-F]{24}$/) ? rawUser : null },
            { username: rawUser.toLowerCase().replace(/^@/, '') },
          ],
        });
        if (uDoc) {
          const uId = uDoc._id.toString().toLowerCase();
          const uName = (uDoc.username || '').toLowerCase();
          userResolvedMap = new Map();
          userResolvedMap.set(rawUser.toLowerCase().replace(/^@/, ''), [uId, uName]);
          userResolvedMap.set(uId, [rawUser.toLowerCase().replace(/^@/, ''), uName]);
          userResolvedMap.set(uName, [rawUser.toLowerCase().replace(/^@/, ''), uId]);
        }
      } catch (_) {}
    }

    if (isConnected()) {
      const dbCommunities = await Community.find().sort({ createdAt: -1 });
      const normalized = dbCommunities.map((c) => normalizeCommunity(c, rawUser, userResolvedMap));

      // Merge with in-memory store so default campus communities are always available
      const existingIds = new Set(normalized.map((c) => c.id));
      for (const sc of store.communities) {
        if (!existingIds.has(sc.id)) {
          normalized.push(normalizeCommunity(sc, rawUser, userResolvedMap));
        }
      }

      return res.json({ success: true, count: normalized.length, data: normalized });
    } else {
      const list = store.communities.map((c) => normalizeCommunity(c, rawUser, userResolvedMap));
      return res.json({ success: true, count: list.length, data: list });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getCommunityById = async (req, res) => {
  try {
    const { id } = req.params;
    const userIdentifier = req.query.userId || req.query.username || '';

    if (isConnected()) {
      let community = await Community.findOne({ $or: [{ id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }] });
      if (!community) {
        community = store.communities.find((c) => c.id === id);
      }
      if (!community) return res.status(404).json({ success: false, message: 'Community not found' });
      return res.json({ success: true, data: normalizeCommunity(community, userIdentifier) });
    } else {
      const community = store.communities.find((c) => c.id === id);
      if (!community) return res.status(404).json({ success: false, message: 'Community not found' });
      return res.json({ success: true, data: normalizeCommunity(community, userIdentifier) });
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
    const effectiveRegionName = regionName || 'Global';
    const effectiveRegionId = regionId || `region_${effectiveRegionName.toLowerCase().replace(/[^a-z0-9]/g, '')}`;
    const cleanCreator = (creatorId || 'user').toLowerCase().replace(/^@/, '');

    const newCommunityData = {
      id: commId,
      name: name || 'Community Group',
      description: description || 'Discussion and updates space',
      regionId: effectiveRegionId,
      regionName: effectiveRegionName,
      locationSpot: locationSpot || 'Everywhere',
      creatorId: cleanCreator,
      category: category || 'General',
      memberCount: 1,
      questionCount: 0,
      iconEmoji: iconEmoji || '💬',
      bannerColorHex: bannerColorHex || 0xFF6366F1,
      rules: rules || [
        '1. Respect all members',
        '2. No spam or commercial promotions',
        '3. No abusive language or harassment',
        '4. Stay on topic and share relevant updates',
      ],
      members: [cleanCreator],
    };

    if (isConnected()) {
      try {
        await Community.create(newCommunityData);

        // Add community to creator's joinedCommunityIds in MongoDB
        await User.findOneAndUpdate(
          {
            $or: [
              { _id: cleanCreator.match(/^[0-9a-fA-F]{24}$/) ? cleanCreator : null },
              { username: cleanCreator },
            ],
          },
          { $addToSet: { joinedCommunityIds: commId } }
        );
      } catch (e) {
        console.error('[DB] Error creating community in MongoDB:', e);
      }
    }

    // Also update in-memory store
    store.communities.unshift(newCommunityData);

    // Update in-memory user
    const storeUser = store.users.find((u) => u.id === cleanCreator || (u.username && u.username.toLowerCase() === cleanCreator));
    if (storeUser) {
      if (!storeUser.joinedCommunityIds) storeUser.joinedCommunityIds = [];
      if (!storeUser.joinedCommunityIds.includes(commId)) {
        storeUser.joinedCommunityIds.push(commId);
      }
    }

    const responseData = normalizeCommunity(newCommunityData, cleanCreator);
    responseData.isJoined = true;

    // Real-time broadcast: notify all connected sockets that a new group has been created.
    // Broadcast to other users with isJoined: false so they are NOT auto-joined and have a "Join" option!
    try {
      const io = req.app.get('io');
      if (io) {
        const broadcastData = {
          ...responseData,
          isJoined: false,
        };
        io.of('/chat').emit('community_created', broadcastData);
        console.log(`[Socket.IO] Broadcasted community_created: "${broadcastData.name}" (${broadcastData.id}) (isJoined: false for other users)`);
      }
    } catch (socketErr) {
      console.error('[Socket.IO community_created error]', socketErr.message);
    }

    return res.status(201).json({
      success: true,
      message: 'Community created successfully',
      data: responseData,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteCommunity = async (req, res) => {
  try {
    const { id } = req.params;

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
    const userIdentifier = (req.body.userId || req.body.username || '').toLowerCase().replace(/^@/, '');

    let community = null;

    if (isConnected()) {
      community = await Community.findOne({ $or: [{ id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }] });
    }
    if (!community) {
      community = store.communities.find((c) => c.id === id);
    }

    if (!community) return res.status(404).json({ success: false, message: 'Community not found' });

    let userObjectId = null;
    let cleanUsername = userIdentifier;
    if (isConnected() && userIdentifier) {
      try {
        const uDoc = await User.findOne({
          $or: [
            { _id: userIdentifier.match(/^[0-9a-fA-F]{24}$/) ? userIdentifier : null },
            { username: userIdentifier },
          ],
        });
        if (uDoc) {
          userObjectId = uDoc._id.toString().toLowerCase();
          cleanUsername = (uDoc.username || '').toLowerCase();
        }
      } catch (_) {}
    }

    let members = Array.isArray(community.members) ? [...community.members] : [];
    const isMember = userIdentifier && members.some((m) => {
      const cleanM = String(m).toLowerCase().replace(/^@/, '');
      return cleanM === userIdentifier || (userObjectId && cleanM === userObjectId) || (cleanUsername && cleanM === cleanUsername);
    });

    let isJoinedNow = false;
    if (isMember) {
      // Leave: remove all matching identifiers for this user
      members = members.filter((m) => {
        const cleanM = String(m).toLowerCase().replace(/^@/, '');
        return cleanM !== userIdentifier && (userObjectId ? cleanM !== userObjectId : true) && (cleanUsername ? cleanM !== cleanUsername : true);
      });
      isJoinedNow = false;
    } else {
      // Join: explicitly add user
      if (userObjectId && !members.some((m) => String(m).toLowerCase() === userObjectId)) {
        members.push(userObjectId);
      } else if (userIdentifier && !members.some((m) => String(m).toLowerCase() === userIdentifier)) {
        members.push(userIdentifier);
      }
      isJoinedNow = true;
    }

    community.members = members;
    community.memberCount = members.length;
    // Do not set isJoined as a static property on the shared community record

    if (community.save) {
      await community.save();
    }

    // Also update in-memory store community
    const storeComm = store.communities.find((c) => c.id === id);
    if (storeComm) {
      storeComm.members = members;
      storeComm.memberCount = members.length;
      delete storeComm.isJoined;
    }

    // Update user's joinedCommunityIds in MongoDB
    if (isConnected() && userIdentifier) {
      try {
        if (isJoinedNow) {
          await User.findOneAndUpdate(
            {
              $or: [
                { _id: userIdentifier.match(/^[0-9a-fA-F]{24}$/) ? userIdentifier : null },
                { username: userIdentifier },
              ],
            },
            { $addToSet: { joinedCommunityIds: id } }
          );
        } else {
          await User.findOneAndUpdate(
            {
              $or: [
                { _id: userIdentifier.match(/^[0-9a-fA-F]{24}$/) ? userIdentifier : null },
                { username: userIdentifier },
              ],
            },
            { $pull: { joinedCommunityIds: id } }
          );
        }
      } catch (uErr) {
        console.error('[DB] Error updating user joinedCommunityIds:', uErr.message);
      }
    }

    const normalized = normalizeCommunity(community, userIdentifier);
    normalized.isJoined = isJoinedNow;

    return res.json({ success: true, data: normalized });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
