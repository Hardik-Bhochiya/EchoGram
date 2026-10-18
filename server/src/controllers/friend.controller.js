const store = require('./store');
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const FriendRequest = require('../models/FriendRequest');
const Friendship = require('../models/Friendship');
const { isConnected } = require('../config/db');

const emitSocketEvent = (req, eventName, room, data) => {
  try {
    const io = req.app.get('io');
    if (io) {
      io.of('/chat').to(room).emit(eventName, data);
      console.log(`[Socket.IO emitted] ${eventName} -> ${room}`);
    }
  } catch (err) {
    console.error(`[Socket.IO error]`, err.message);
  }
};

exports.sendFriendRequest = async (req, res) => {
  try {
    const { senderId, senderUsername, senderName, senderAvatar, receiverUsername } = req.body;

    if (!senderUsername || !receiverUsername) {
      return res.status(400).json({ error: 'senderUsername and receiverUsername are required' });
    }

    const sUser = senderUsername.trim().toLowerCase().replaceAll('@', '');
    const rUser = receiverUsername.trim().toLowerCase().replaceAll('@', '');

    if (sUser === rUser) {
      return res.status(400).json({ error: 'Cannot send friend request to yourself' });
    }

    let targetUser = store.users.find((u) => u.username && u.username.toLowerCase() === rUser);
    if (!targetUser && isConnected()) {
      try {
        const dbUser = await User.findOne({ username: rUser });
        if (dbUser) {
          targetUser = {
            id: dbUser._id.toString(),
            username: dbUser.username,
            name: dbUser.name,
          };
        }
      } catch (_) {}
    }

    if (!targetUser) {
      return res.status(404).json({ error: `@${rUser} was not found` });
    }

    // Check if already friends in DB or memory
    let alreadyFriends = false;
    if (store.friends[sUser] && store.friends[sUser].has(rUser)) {
      alreadyFriends = true;
    }
    if (!alreadyFriends && isConnected()) {
      const dbFriendship = await Friendship.findOne({
        $or: [
          { user1: sUser, user2: rUser },
          { user1: rUser, user2: sUser },
        ],
      });
      if (dbFriendship) alreadyFriends = true;
    }

    if (alreadyFriends) {
      return res.status(400).json({ error: `You are already friends with @${rUser}` });
    }

    // Check existing pending request in DB or memory
    let existingPending = null;
    if (isConnected()) {
      existingPending = await FriendRequest.findOne({
        $or: [
          { senderUsername: sUser, receiverUsername: rUser },
          { senderUsername: rUser, receiverUsername: sUser },
        ],
        status: 'pending',
      });
    }

    if (!existingPending) {
      existingPending = store.friendRequests.find(
        (fr) =>
          ((fr.senderUsername.toLowerCase() === sUser && fr.receiverUsername.toLowerCase() === rUser) ||
           (fr.senderUsername.toLowerCase() === rUser && fr.receiverUsername.toLowerCase() === sUser)) &&
          fr.status === 'pending'
      );
    }

    if (existingPending) {
      return res.status(200).json({ message: 'Friend request already pending', request: existingPending });
    }

    const newRequestData = {
      id: uuidv4(),
      senderId: senderId || 'user',
      senderUsername: sUser,
      senderName: senderName || sUser || 'Member',
      senderAvatar: senderAvatar || '🎓',
      receiverId: targetUser.id,
      receiverUsername: rUser,
      receiverName: targetUser.name,
      status: 'pending',
    };

    if (isConnected()) {
      await FriendRequest.create(newRequestData);
    }

    // Also update in-memory store
    store.friendRequests.unshift({
      ...newRequestData,
      createdAt: new Date().toISOString(),
    });

    // Notify receiver via WebSocket immediately
    emitSocketEvent(req, 'friend_request_received', `user-${rUser}`, newRequestData);
    emitSocketEvent(req, 'friend_request_received', `user-@${rUser}`, newRequestData);

    return res.status(201).json({ message: 'Friend request sent', request: newRequestData });
  } catch (err) {
    console.error('Error sending friend request:', err);
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};

exports.respondFriendRequest = async (req, res) => {
  try {
    const { requestId, status, senderUsername, receiverUsername } = req.body;
    const mongoose = require('mongoose');

    const u1 = (senderUsername || '').trim().toLowerCase().replaceAll('@', '');
    const u2 = (receiverUsername || '').trim().toLowerCase().replaceAll('@', '');

    let reqObj = null;
    if (isConnected()) {
      const conditions = [];
      if (requestId) {
        conditions.push({ id: requestId });
        if (mongoose.Types.ObjectId.isValid(requestId)) {
          conditions.push({ _id: requestId });
        }
      }
      if (u1 && u2) {
        conditions.push({ senderUsername: u1, receiverUsername: u2 });
        conditions.push({ senderUsername: u2, receiverUsername: u1 });
      }
      if (conditions.length > 0) {
        reqObj = await FriendRequest.findOne({ $or: conditions });
      }
    }
    if (!reqObj) {
      reqObj = store.friendRequests.find((r) =>
        r.id === requestId ||
        (u1 && u2 && ((r.senderUsername.toLowerCase() === u1 && r.receiverUsername.toLowerCase() === u2) ||
         (r.senderUsername.toLowerCase() === u2 && r.receiverUsername.toLowerCase() === u1)))
      );
    }

    if (!reqObj) {
      return res.status(404).json({ error: 'Friend request not found' });
    }

    const finalU1 = (reqObj.senderUsername || u1).trim().toLowerCase().replaceAll('@', '');
    const finalU2 = (reqObj.receiverUsername || u2).trim().toLowerCase().replaceAll('@', '');
    const actualReqId = reqObj.id || (reqObj._id ? reqObj._id.toString() : requestId);

    if (status === 'accepted') {
      reqObj.status = 'accepted';
      if (reqObj.save) {
        await reqObj.save();
      }

      // Add friendship to DB
      if (isConnected()) {
        try {
          await Friendship.updateOne(
            {
              $or: [
                { user1: finalU1, user2: finalU2 },
                { user1: finalU2, user2: finalU1 },
              ],
            },
            { $setOnInsert: { user1: finalU1, user2: finalU2 } },
            { upsert: true }
          );
        } catch (dbErr) {
          console.error('[DB] Friendship creation error:', dbErr.message);
        }
      }

      // Add to in-memory store
      if (!store.friends[finalU1]) store.friends[finalU1] = new Set();
      store.friends[finalU1].add(finalU2);

      if (!store.friends[finalU2]) store.friends[finalU2] = new Set();
      store.friends[finalU2].add(finalU1);

      // Remove from store.friendRequests
      store.friendRequests = store.friendRequests.filter((r) => r.id !== actualReqId && r.id !== requestId);

      const eventPayload = {
        requestId: actualReqId,
        status: 'accepted',
        senderUsername: finalU1,
        receiverUsername: finalU2,
      };

      // Emit accepted socket event to both parties & globally
      emitSocketEvent(req, 'friend_request_accepted', `user-${finalU1}`, eventPayload);
      emitSocketEvent(req, 'friend_request_accepted', `user-${finalU2}`, eventPayload);
      emitSocketEvent(req, 'friend_request_accepted', `user-@${finalU1}`, eventPayload);
      emitSocketEvent(req, 'friend_request_accepted', `user-@${finalU2}`, eventPayload);
      try {
        const io = req.app.get('io');
        if (io) io.of('/chat').emit('friend_request_accepted', eventPayload);
      } catch (_) {}
    } else {
      // Rejection / Decline: completely remove pending request so sender can request again
      if (isConnected()) {
        try {
          await FriendRequest.deleteOne({ id: requestId });
        } catch (_) {}
      }
      store.friendRequests = store.friendRequests.filter((r) => r.id !== requestId);

      // Emit declined event to both parties
      emitSocketEvent(req, 'friend_request_declined', `user-${u1}`, {
        requestId,
        status: 'declined',
        senderUsername: u1,
        receiverUsername: u2,
      });
      emitSocketEvent(req, 'friend_request_declined', `user-${u2}`, {
        requestId,
        status: 'declined',
        senderUsername: u1,
        receiverUsername: u2,
      });
      emitSocketEvent(req, 'friend_request_declined', `user-@${u1}`, {
        requestId,
        status: 'declined',
        senderUsername: u1,
        receiverUsername: u2,
      });
      emitSocketEvent(req, 'friend_request_declined', `user-@${u2}`, {
        requestId,
        status: 'declined',
        senderUsername: u1,
        receiverUsername: u2,
      });
    }

    return res.json({ message: `Friend request ${status}`, request: reqObj });
  } catch (err) {
    console.error('Error responding to friend request:', err);
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};

exports.unfriend = async (req, res) => {
  try {
    const { user1, user2 } = req.body;
    if (!user1 || !user2) {
      return res.status(400).json({ error: 'user1 and user2 are required' });
    }

    const u1 = user1.trim().toLowerCase().replaceAll('@', '');
    const u2 = user2.trim().toLowerCase().replaceAll('@', '');

    if (isConnected()) {
      await Friendship.deleteMany({
        $or: [
          { user1: u1, user2: u2 },
          { user1: u2, user2: u1 },
        ],
      });
      await FriendRequest.deleteMany({
        $or: [
          { senderUsername: u1, receiverUsername: u2 },
          { senderUsername: u2, receiverUsername: u1 },
        ],
      });
    }

    if (store.friends[u1]) store.friends[u1].delete(u2);
    if (store.friends[u2]) store.friends[u2].delete(u1);

    // Remove any friend requests connecting them
    store.friendRequests = store.friendRequests.filter(
      (r) =>
        !(
          (r.senderUsername.toLowerCase() === u1 && r.receiverUsername.toLowerCase() === u2) ||
          (r.senderUsername.toLowerCase() === u2 && r.receiverUsername.toLowerCase() === u1)
        )
    );

    return res.json({ success: true, message: `Successfully unfriended @${u2}` });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};

exports.getFriendRequests = async (req, res) => {
  try {
    const username = req.params.username.trim().toLowerCase().replaceAll('@', '');
    let dbRequests = [];
    if (isConnected()) {
      dbRequests = await FriendRequest.find({
        $or: [
          { receiverUsername: username },
          { senderUsername: username },
        ],
      }).sort({ createdAt: -1 });
    }

    const reqMap = new Map();
    // In-memory store requests
    const memoryRequests = store.friendRequests.filter(
      (r) => r.receiverUsername.toLowerCase() === username || r.senderUsername.toLowerCase() === username
    );

    for (const r of memoryRequests) {
      reqMap.set(r.id, r);
    }
    for (const r of dbRequests) {
      const obj = r.toObject ? r.toObject() : r;
      reqMap.set(obj.id, obj);
    }

    const allRequests = Array.from(reqMap.values()).sort(
      (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0)
    );

    return res.json({ requests: allRequests });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};

exports.cancelFriendRequest = async (req, res) => {
  try {
    const { requestId, senderUsername, receiverUsername } = req.body;
    const sUser = (senderUsername || '').trim().toLowerCase().replaceAll('@', '');
    const rUser = (receiverUsername || '').trim().toLowerCase().replaceAll('@', '');

    if (isConnected()) {
      if (requestId) {
        await FriendRequest.deleteOne({ id: requestId });
      } else if (sUser && rUser) {
        await FriendRequest.deleteOne({ senderUsername: sUser, receiverUsername: rUser, status: 'pending' });
      }
    }

    const idx = store.friendRequests.findIndex(
      (r) =>
        r.id === requestId ||
        (r.senderUsername.toLowerCase() === sUser && r.receiverUsername.toLowerCase() === rUser)
    );

    if (idx !== -1) {
      const [removed] = store.friendRequests.splice(idx, 1);
      return res.json({ success: true, message: 'Friend request cancelled', request: removed });
    }

    return res.json({ success: true, message: 'Friend request cancelled' });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};

exports.getFriends = async (req, res) => {
  try {
    const username = req.params.username.trim().toLowerCase().replaceAll('@', '');
    const friendSet = new Set(store.friends[username] ? Array.from(store.friends[username]) : []);

    if (isConnected()) {
      const dbFriendships = await Friendship.find({
        $or: [{ user1: username }, { user2: username }],
      });
      for (const fs of dbFriendships) {
        if (fs.user1.toLowerCase() === username) {
          friendSet.add(fs.user2.toLowerCase());
        } else {
          friendSet.add(fs.user1.toLowerCase());
        }
      }
    }

    const friendUsernames = Array.from(friendSet);
    const userMap = new Map();

    // From store
    for (const u of store.users) {
      if (u.username && friendUsernames.includes(u.username.toLowerCase())) {
        userMap.set(u.username.toLowerCase(), {
          id: u.id || u.username,
          username: u.username,
          name: u.name,
          campusOrCity: u.campusOrCity,
          majorOrBio: u.majorOrBio,
          reputation: u.reputation,
        });
      }
    }

    // From MongoDB
    if (isConnected() && friendUsernames.length > 0) {
      try {
        const dbUsers = await User.find({ username: { $in: friendUsernames } }).select('-password');
        for (const dbu of dbUsers) {
          userMap.set(dbu.username.toLowerCase(), {
            id: dbu._id.toString(),
            username: dbu.username,
            name: dbu.name,
            campusOrCity: dbu.campusOrCity,
            majorOrBio: dbu.majorOrBio,
            reputation: dbu.reputation,
          });
        }
      } catch (_) {}
    }

    return res.json({ friends: Array.from(userMap.values()) });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Server error' });
  }
};
