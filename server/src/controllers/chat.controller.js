const { v4: uuidv4 } = require('uuid');
const store = require('./store');
const { Message, Room } = require('../models/Message');
const { isConnected } = require('../config/db');

exports.getRooms = async (req, res) => {
  try {
    if (isConnected()) {
      const dbRooms = await Room.find().sort({ lastMessageTime: -1 });
      const normalized = dbRooms.map((r) => ({
        id: r._id.toString(),
        title: r.title,
        subtitle: r.subtitle,
        avatarEmoji: r.avatarEmoji || '💬',
        communityId: r.communityId,
        isGroup: r.isGroup,
        lastMessage: r.lastMessage,
        lastMessageTime: r.lastMessageTime,
        unreadCount: 0,
        isOnline: true,
        participantIds: r.participantIds || [],
      }));

      // Merge default store rooms
      const existingIds = new Set(normalized.map((r) => r.id));
      for (const sr of store.rooms) {
        if (!existingIds.has(sr.id)) normalized.push(sr);
      }
      return res.json({ success: true, count: normalized.length, data: normalized });
    }
    return res.json({ success: true, count: store.rooms.length, data: store.rooms });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getMessages = async (req, res) => {
  try {
    const { roomId } = req.params;
    let messages = store.messages[roomId] || [];

    if (isConnected()) {
      const dbMsgs = await Message.find({ roomId }).sort({ createdAt: 1 });
      if (dbMsgs.length > 0) {
        const dbFormatted = dbMsgs.map((m) => ({
          id: m._id.toString(),
          roomId: m.roomId,
          senderId: m.senderId,
          senderName: m.senderName,
          content: m.content,
          isAnonymous: m.isAnonymous,
          status: 'seen',
          timestamp: m.createdAt.toISOString(),
        }));
        const existingIds = new Set(messages.map((m) => m.id));
        for (const dm of dbFormatted) {
          if (!existingIds.has(dm.id)) messages.push(dm);
        }
      }
    }

    return res.json({ success: true, count: messages.length, data: messages });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { content, senderId, senderName, isAnonymous } = req.body;

    if (!content) {
      return res.status(400).json({ success: false, message: 'Message content is required' });
    }

    const newMessage = {
      id: uuidv4(),
      roomId,
      senderId: senderId || 'user',
      senderName: isAnonymous ? 'Anonymous' : (senderName || 'Member'),
      content,
      isAnonymous: Boolean(isAnonymous),
      timestamp: new Date().toISOString(),
      isMine: false,
    };

    if (!store.messages[roomId]) store.messages[roomId] = [];
    store.messages[roomId].push(newMessage);

    if (isConnected()) {
      try {
        await Message.create({
          roomId,
          senderId: newMessage.senderId,
          senderName: newMessage.senderName,
          content,
          isAnonymous: Boolean(isAnonymous),
        });
      } catch (_) {}
    }

    // Update room last message
    const room = store.rooms.find((r) => r.id === roomId);
    if (room) {
      room.lastMessage = content;
      room.lastMessageTime = newMessage.timestamp;
    }

    return res.status(201).json({ success: true, data: newMessage });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

