const store = require('./store');
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const { isConnected } = require('../config/db');

exports.sendFriendRequest = async (req, res) => {
  const { senderId, senderUsername, senderName, senderAvatar, receiverUsername } = req.body;

  if (!senderUsername || !receiverUsername) {
    return res.status(400).json({ error: 'senderUsername and receiverUsername are required' });
  }

  const sUser = senderUsername.trim().toLowerCase().replaceAll('@', '');
  const rUser = receiverUsername.trim().toLowerCase().replaceAll('@', '');

  if (sUser === rUser) {
    return res.status(400).json({ error: 'Cannot send friend request to yourself' });
  }

  let targetUser = store.users.find((u) => u.username.toLowerCase() === rUser);
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

  // Check if already friends
  if (store.friends[sUser] && store.friends[sUser].has(rUser)) {
    return res.status(400).json({ error: `You are already friends with @${rUser}` });
  }

  // Check existing request
  const existing = store.friendRequests.find(
    (fr) =>
      (fr.senderUsername.toLowerCase() === sUser && fr.receiverUsername.toLowerCase() === rUser) ||
      (fr.senderUsername.toLowerCase() === rUser && fr.receiverUsername.toLowerCase() === sUser)
  );

  if (existing && existing.status === 'pending') {
    return res.status(200).json({ message: 'Friend request already pending', request: existing });
  }

  const newRequest = {
    id: uuidv4(),
    senderId: senderId || 'user-hardik',
    senderUsername: sUser,
    senderName: senderName || 'Hardik Bhochiya',
    senderAvatar: senderAvatar || '🎓',
    receiverId: targetUser.id,
    receiverUsername: rUser,
    receiverName: targetUser.name,
    status: 'pending',
    createdAt: new Date().toISOString(),
  };

  store.friendRequests.unshift(newRequest);
  res.status(201).json({ message: 'Friend request sent', request: newRequest });
};

exports.respondFriendRequest = (req, res) => {
  const { requestId, status, senderUsername, receiverUsername } = req.body;

  const reqObj = store.friendRequests.find((r) => r.id === requestId);
  if (!reqObj) {
    return res.status(404).json({ error: 'Friend request not found' });
  }

  reqObj.status = status; // 'accepted' or 'declined'

  if (status === 'accepted') {
    const u1 = (senderUsername || reqObj.senderUsername).toLowerCase().replaceAll('@', '');
    const u2 = (receiverUsername || reqObj.receiverUsername).toLowerCase().replaceAll('@', '');

    if (!store.friends[u1]) store.friends[u1] = new Set();
    store.friends[u1].add(u2);

    if (!store.friends[u2]) store.friends[u2] = new Set();
    store.friends[u2].add(u1);
  }

  res.json({ message: `Friend request ${status}`, request: reqObj });
};

exports.unfriend = (req, res) => {
  const { user1, user2 } = req.body;
  if (!user1 || !user2) {
    return res.status(400).json({ error: 'user1 and user2 are required' });
  }

  const u1 = user1.trim().toLowerCase().replaceAll('@', '');
  const u2 = user2.trim().toLowerCase().replaceAll('@', '');

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
};

exports.getFriendRequests = (req, res) => {
  const username = req.params.username.trim().toLowerCase().replaceAll('@', '');
  const requests = store.friendRequests.filter(
    (r) => r.receiverUsername.toLowerCase() === username || r.senderUsername.toLowerCase() === username
  );
  res.json({ requests });
};

exports.cancelFriendRequest = (req, res) => {
  const { requestId, senderUsername, receiverUsername } = req.body;
  const sUser = (senderUsername || '').trim().toLowerCase().replaceAll('@', '');
  const rUser = (receiverUsername || '').trim().toLowerCase().replaceAll('@', '');

  const idx = store.friendRequests.findIndex(
    (r) =>
      r.id === requestId ||
      (r.senderUsername.toLowerCase() === sUser && r.receiverUsername.toLowerCase() === rUser)
  );

  if (idx !== -1) {
    const [removed] = store.friendRequests.splice(idx, 1);
    return res.json({ success: true, message: 'Friend request cancelled', request: removed });
  }

  return res.status(404).json({ success: false, message: 'Friend request not found' });
};

exports.getFriends = async (req, res) => {
  const username = req.params.username.trim().toLowerCase().replaceAll('@', '');
  const friendUsernames = store.friends[username] ? Array.from(store.friends[username]) : [];

  let friendUsers = store.users.filter((u) => friendUsernames.includes(u.username.toLowerCase()));

  if (isConnected() && friendUsernames.length > 0) {
    try {
      const dbUsers = await User.find({ username: { $in: friendUsernames } }).select('-password');
      for (const dbu of dbUsers) {
        if (!friendUsers.some((u) => u.username.toLowerCase() === dbu.username.toLowerCase())) {
          friendUsers.push({
            id: dbu._id.toString(),
            username: dbu.username,
            name: dbu.name,
            campusOrCity: dbu.campusOrCity,
            majorOrBio: dbu.majorOrBio,
            reputation: dbu.reputation,
          });
        }
      }
    } catch (_) {}
  }

  res.json({ friends: friendUsers });
};


