const store = require('../controllers/store');
const { v4: uuidv4 } = require('uuid');
const { Message } = require('../models/Message');
const { isConnected } = require('../config/db');

const registerChatSocket = (io) => {
  const chatNamespace = io.of('/chat');

  chatNamespace.on('connection', (socket) => {
    console.log(`[Socket.IO] Client connected: ${socket.id}`);

    // Join personal user notification channel
    socket.on('join_user', ({ userId, username }) => {
      if (userId) socket.join(`user-${userId}`);
      if (username) {
        const cleanName = username.toLowerCase().replace(/^@/, '').trim();
        socket.join(`user-${cleanName}`);
        socket.join(`user-@${cleanName}`);
        console.log(`[Socket.IO] Joined user channel: user-${cleanName} (id: ${userId})`);
      }
    });

    socket.on('join_room', ({ roomId, userName }) => {
      socket.join(roomId);
      console.log(`[Socket.IO] User ${userName || 'Anonymous'} joined room: ${roomId}`);
      socket.to(roomId).emit('user_joined', {
        roomId,
        userName: userName || 'Anonymous',
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('leave_room', ({ roomId, userName }) => {
      socket.leave(roomId);
      socket.to(roomId).emit('user_left', {
        roomId,
        userName: userName || 'Anonymous',
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('send_message', ({ id, roomId, content, senderId, senderName, isAnonymous, senderUsername, timestamp }) => {
      const sentTime = timestamp ? new Date(timestamp).toISOString() : new Date().toISOString();
      const newMessage = {
        id: id || uuidv4(),
        roomId,
        senderId: senderId || 'user',
        senderName: isAnonymous ? 'Anonymous' : (senderName || 'Member'),
        content,
        isAnonymous: Boolean(isAnonymous),
        status: 'seen',
        likes: [],
        dislikes: [],
        isEdited: false,
        isDeleted: false,
        deletedForUserIds: [],
        timestamp: sentTime,
        createdAt: sentTime,
      };

      if (!store.messages[roomId]) store.messages[roomId] = [];
      // Deduplicate in store as well
      const existingIdx = store.messages[roomId].findIndex((m) => m.id === newMessage.id);
      if (existingIdx === -1) {
        store.messages[roomId].push(newMessage);
      } else {
        store.messages[roomId][existingIdx] = newMessage;
      }

      if (isConnected()) {
        try {
          Message.create({
            id: newMessage.id,
            roomId,
            senderId: newMessage.senderId,
            senderName: newMessage.senderName,
            content,
            isAnonymous: Boolean(isAnonymous),
            likes: [],
            dislikes: [],
            createdAt: new Date(sentTime),
          }).catch((err) => {
            console.error('[Socket.IO Message.create error]', err.message);
          });
        } catch (_) {}
      }


      const room = store.rooms.find((r) => r.id === roomId);
      if (room) {
        room.lastMessage = content;
        room.lastMessageTime = newMessage.timestamp;
      }

      // Broadcast to other clients in the room (excluding sender socket to prevent duplicate appearance)
      socket.to(roomId).emit('receive_message', newMessage);

      // If DM, notify recipient user channel so they see incoming message if not currently inside the room
      if (roomId.startsWith('dm-')) {
        const stripped = roomId.substring(3).toLowerCase().trim();
        const sHandle = (senderUsername || senderName || '').toLowerCase().replace(/^@/, '').trim();
        let recipientHandle = '';
        if (sHandle && stripped.startsWith(`${sHandle}_`)) {
          recipientHandle = stripped.substring(sHandle.length + 1);
        } else if (sHandle && stripped.endsWith(`_${sHandle}`)) {
          recipientHandle = stripped.substring(0, stripped.length - sHandle.length - 1);
        }

        if (recipientHandle) {
          socket.to(`user-${recipientHandle}`).emit('receive_message', newMessage);
          socket.to(`user-@${recipientHandle}`).emit('receive_message', newMessage);
          console.log(`[Socket.IO] Dispatched DM to user-${recipientHandle} for room ${roomId}`);
        } else {
          // Fallback broadcast across socket if recipient handle could not be uniquely isolated
          socket.broadcast.emit('receive_message', newMessage);
        }
      }
    });

    socket.on('edit_message', ({ roomId, messageId, newContent }) => {
      const roomMsgs = store.messages[roomId];
      if (roomMsgs) {
        const msg = roomMsgs.find((m) => m.id === messageId);
        if (msg) {
          msg.content = newContent;
          msg.isEdited = true;
        }
      }
      chatNamespace.to(roomId).emit('message_edited', { roomId, messageId, newContent });
    });

    socket.on('delete_message', ({ roomId, messageId, forEveryone }) => {
      const roomMsgs = store.messages[roomId];
      if (roomMsgs) {
        const msg = roomMsgs.find((m) => m.id === messageId);
        if (msg) {
          msg.isDeleted = true;
          msg.content = '🚫 This message was deleted';
        }
      }
      chatNamespace.to(roomId).emit('message_deleted', { roomId, messageId, forEveryone });
    });

    // Handles real-time message like toggling with database and memory persistence
    socket.on('like_message', async ({ roomId, messageId, userId }) => {
      const uid = String(userId || '').trim();
      // Guard against invalid or unauthenticated like triggers
      if (!uid || !roomId || !messageId) return;

      let updatedLikes = [];
      let updatedDislikes = [];

      // 1. Update in in-memory store
      if (!store.messages[roomId]) store.messages[roomId] = [];
      const msg = store.messages[roomId].find((m) => m.id === messageId);
      if (msg) {
        if (!Array.isArray(msg.likes)) msg.likes = [];
        if (!Array.isArray(msg.dislikes)) msg.dislikes = [];
        msg.dislikes = msg.dislikes.filter((u) => u !== uid);
        if (msg.likes.includes(uid)) {
          msg.likes = msg.likes.filter((u) => u !== uid);
        } else {
          msg.likes.push(uid);
        }
        updatedLikes = [...msg.likes];
        updatedDislikes = [...msg.dislikes];
      }

      // 2. Update in MongoDB
      if (isConnected()) {
        try {
          const mongoose = require('mongoose');
          const isIdObj = mongoose.Types.ObjectId.isValid(messageId);
          const filter = {
            $or: [
              { id: messageId },
              ...(isIdObj ? [{ _id: messageId }] : []),
            ],
          };
          const dbMsg = await Message.findOne(filter);
          if (dbMsg) {
            let dLikes = Array.isArray(dbMsg.likes) ? dbMsg.likes : [];
            let dDislikes = Array.isArray(dbMsg.dislikes) ? dbMsg.dislikes : [];
            dDislikes = dDislikes.filter((u) => u !== uid);
            if (dLikes.includes(uid)) {
              dLikes = dLikes.filter((u) => u !== uid);
            } else {
              dLikes.push(uid);
            }
            dbMsg.likes = dLikes;
            dbMsg.dislikes = dDislikes;
            await dbMsg.save();
            updatedLikes = dLikes;
            updatedDislikes = dDislikes;
          }
        } catch (dbErr) {
          console.error('[Socket.IO like_message DB error]', dbErr.message);
        }
      }

      const payload = {
        roomId,
        messageId,
        userId: uid,
        likes: updatedLikes,
        dislikes: updatedDislikes,
      };

      chatNamespace.to(roomId).emit('message_liked', payload);
      socket.broadcast.emit('message_liked', payload);
      socket.emit('message_liked', payload);
      console.log(`[Socket.IO] message_liked: msg ${messageId} in room ${roomId} (likes: ${updatedLikes.length}, dislikes: ${updatedDislikes.length})`);
    });

    // Handles real-time message dislike toggling with database and memory persistence
    socket.on('dislike_message', async ({ roomId, messageId, userId }) => {
      const uid = String(userId || '').trim();
      // Guard against invalid or unauthenticated dislike triggers
      if (!uid || !roomId || !messageId) return;

      let updatedLikes = [];
      let updatedDislikes = [];

      // 1. Update in in-memory store
      if (!store.messages[roomId]) store.messages[roomId] = [];
      const msg = store.messages[roomId].find((m) => m.id === messageId);
      if (msg) {
        if (!Array.isArray(msg.likes)) msg.likes = [];
        if (!Array.isArray(msg.dislikes)) msg.dislikes = [];
        msg.likes = msg.likes.filter((u) => u !== uid);
        if (msg.dislikes.includes(uid)) {
          msg.dislikes = msg.dislikes.filter((u) => u !== uid);
        } else {
          msg.dislikes.push(uid);
        }
        updatedLikes = [...msg.likes];
        updatedDislikes = [...msg.dislikes];
      }

      // 2. Update in MongoDB
      if (isConnected()) {
        try {
          const mongoose = require('mongoose');
          const isIdObj = mongoose.Types.ObjectId.isValid(messageId);
          const filter = {
            $or: [
              { id: messageId },
              ...(isIdObj ? [{ _id: messageId }] : []),
            ],
          };
          const dbMsg = await Message.findOne(filter);
          if (dbMsg) {
            let dLikes = Array.isArray(dbMsg.likes) ? dbMsg.likes : [];
            let dDislikes = Array.isArray(dbMsg.dislikes) ? dbMsg.dislikes : [];
            dLikes = dLikes.filter((u) => u !== uid);
            if (dDislikes.includes(uid)) {
              dDislikes = dDislikes.filter((u) => u !== uid);
            } else {
              dDislikes.push(uid);
            }
            dbMsg.likes = dLikes;
            dbMsg.dislikes = dDislikes;
            await dbMsg.save();
            updatedLikes = dLikes;
            updatedDislikes = dDislikes;
          }
        } catch (dbErr) {
          console.error('[Socket.IO dislike_message DB error]', dbErr.message);
        }
      }

      const payload = {
        roomId,
        messageId,
        userId: uid,
        likes: updatedLikes,
        dislikes: updatedDislikes,
      };

      chatNamespace.to(roomId).emit('message_disliked', payload);
      socket.broadcast.emit('message_disliked', payload);
      socket.emit('message_disliked', payload);
      console.log(`[Socket.IO] message_disliked: msg ${messageId} in room ${roomId} (likes: ${updatedLikes.length}, dislikes: ${updatedDislikes.length})`);
    });

    socket.on('mark_seen', ({ roomId, messageId }) => {
      chatNamespace.to(roomId).emit('message_seen', { roomId, messageId });
    });

    socket.on('typing_start', ({ roomId, userName }) => {
      socket.to(roomId).emit('user_typing', {
        roomId,
        userName: userName || 'Someone',
        isTyping: true,
      });
    });

    socket.on('typing_stop', ({ roomId, userName }) => {
      socket.to(roomId).emit('user_typing', {
        roomId,
        userName: userName || 'Someone',
        isTyping: false,
      });
    });

    socket.on('send_friend_request', (data) => {
      const { receiverUsername } = data;
      if (receiverUsername) {
        const cleanRec = receiverUsername.toLowerCase().replace(/^@/, '').trim();
        chatNamespace.to(`user-${cleanRec}`).emit('friend_request_received', data);
        chatNamespace.to(`user-@${cleanRec}`).emit('friend_request_received', data);
        console.log(`[Socket.IO] Broadcasted friend request to user-${cleanRec}`);
      }
    });

    socket.on('respond_friend_request', (data) => {
      const { senderUsername, receiverUsername, status } = data;
      const sUser = (senderUsername || '').toLowerCase().replace(/^@/, '').trim();
      const rUser = (receiverUsername || '').toLowerCase().replace(/^@/, '').trim();
      const eventName = status === 'accepted' ? 'friend_request_accepted' : 'friend_request_declined';

      if (sUser) {
        chatNamespace.to(`user-${sUser}`).emit(eventName, data);
        chatNamespace.to(`user-@${sUser}`).emit(eventName, data);
      }
      if (rUser) {
        chatNamespace.to(`user-${rUser}`).emit(eventName, data);
        chatNamespace.to(`user-@${rUser}`).emit(eventName, data);
      }
      chatNamespace.emit(eventName, data);
      console.log(`[Socket.IO] Broadcasted ${eventName} to all clients, user-${sUser} & user-${rUser}`);
    });

    socket.on('disconnect', () => {
      console.log(`[Socket.IO] Client disconnected: ${socket.id}`);
    });
  });
};

module.exports = registerChatSocket;
