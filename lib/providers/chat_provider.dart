import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/user.dart';
import '../services/mock_data_service.dart';
import '../services/socket_service.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatRoom> _rooms = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, String?> _typingUser = {};
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _editSub;
  StreamSubscription<Map<String, dynamic>>? _deleteSub;
  StreamSubscription<Map<String, dynamic>>? _likeSub;
  StreamSubscription<Map<String, dynamic>>? _dislikeSub;
  StreamSubscription<Map<String, dynamic>>? _seenSub;

  List<ChatRoom> get rooms => _rooms;
  String? getTypingUser(String roomId) => _typingUser[roomId];
  bool isTyping(String roomId) => _typingUser[roomId] != null;

  ChatProvider() {
    _initChat();
  }

  void _initChat() {
    // 1. Immediately load rooms from local storage
    _rooms = LocalStoreService().getChatRooms();
    notifyListeners();

    // 2. Connect to WebSocket if online
    SocketService().connect();

    // Handle incoming messages
    _messageSub = SocketService().onMessageReceived.listen((msg) {
      if (!_messages.containsKey(msg.roomId)) {
        _messages[msg.roomId] = [];
      }

      // Robust deduplication: check ID and identical content from sender within 5s
      final existingIdx = _messages[msg.roomId]!.indexWhere((m) =>
          m.id == msg.id ||
          (m.senderId == msg.senderId &&
              m.content == msg.content &&
              m.timestamp.difference(msg.timestamp).abs().inSeconds < 5));
      if (existingIdx != -1) {
        // If message already exists (e.g. sent optimistically), sync without duplicating
        _messages[msg.roomId]![existingIdx] = msg;
        LocalStoreService().addMessage(msg);
        notifyListeners();
        return;
      }

      _messages[msg.roomId]!.add(msg);
      LocalStoreService().addMessage(msg);

      final index = _rooms.indexWhere((r) => r.id == msg.roomId);
      if (index != -1) {
        _rooms[index] = _rooms[index].copyWith(
          lastMessage: msg.content,
          lastMessageTime: msg.timestamp,
          unreadCount: _rooms[index].unreadCount + (msg.isMine ? 0 : 1),
        );
        LocalStoreService().addOrUpdateRoom(_rooms[index]);
      } else {
        // Auto-create direct conversation room if recipient hasn't opened it yet
        final newRoom = ChatRoom(
          id: msg.roomId,
          title: msg.senderName,
          subtitle: 'Direct Message',
          avatarEmoji: '👤',
          isGroup: false,
          lastMessage: msg.content,
          lastMessageTime: msg.timestamp,
          unreadCount: msg.isMine ? 0 : 1,
          isOnline: true,
          participantIds: [msg.senderId],
        );
        _rooms.insert(0, newRoom);
        LocalStoreService().addOrUpdateRoom(newRoom);
      }
      notifyListeners();
    });

    // Handle real-time typing indicators
    _typingSub = SocketService().onTypingStatus.listen((data) {
      final roomId = data['roomId'] as String?;
      final userName = data['userName'] as String?;
      final isTypingStatus = data['isTyping'] as bool? ?? false;

      if (roomId != null) {
        _typingUser[roomId] = isTypingStatus ? userName : null;
        notifyListeners();
      }
    });

    // Handle real-time edits
    _editSub = SocketService().onMessageEdited.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      final newContent = data['newContent'] as String?;

      if (roomId != null && messageId != null && newContent != null) {
        final list = _messages[roomId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            list[idx] = list[idx].copyWith(content: newContent, isEdited: true);
            LocalStoreService().editMessage(roomId, messageId, newContent);
            notifyListeners();
          }
        }
      }
    });

    // Handle real-time deletes
    _deleteSub = SocketService().onMessageDeleted.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      final forEveryone = data['forEveryone'] as bool? ?? false;

      if (roomId != null && messageId != null) {
        final list = _messages[roomId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            if (forEveryone) {
              list[idx] = list[idx].copyWith(
                content: '🚫 This message was deleted',
                isDeleted: true,
              );
            } else {
              list.removeAt(idx);
            }
            LocalStoreService().deleteMessage(roomId, messageId, forEveryone: forEveryone);
            notifyListeners();
          }
        }
      }
    });

    // Handle real-time likes
    _likeSub = SocketService().onMessageLiked.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      final userId = data['userId'] as String?;

      if (roomId != null && messageId != null && userId != null) {
        final list = _messages[roomId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final cur = list[idx];
            final likes = List<String>.from(cur.likes);
            final dislikes = List<String>.from(cur.dislikes);
            dislikes.remove(userId);
            if (likes.contains(userId)) {
              likes.remove(userId);
            } else {
              likes.add(userId);
            }
            list[idx] = cur.copyWith(likes: likes, dislikes: dislikes);
            notifyListeners();
          }
        }
      }
    });

    // Handle real-time dislikes
    _dislikeSub = SocketService().onMessageDisliked.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      final userId = data['userId'] as String?;

      if (roomId != null && messageId != null && userId != null) {
        final list = _messages[roomId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final cur = list[idx];
            final likes = List<String>.from(cur.likes);
            final dislikes = List<String>.from(cur.dislikes);
            likes.remove(userId);
            if (dislikes.contains(userId)) {
              dislikes.remove(userId);
            } else {
              dislikes.add(userId);
            }
            list[idx] = cur.copyWith(likes: likes, dislikes: dislikes);
            notifyListeners();
          }
        }
      }
    });

    // Handle real-time seen status
    _seenSub = SocketService().onMessageSeen.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;

      if (roomId != null) {
        final list = _messages[roomId];
        if (list != null) {
          if (messageId != null) {
            final idx = list.indexWhere((m) => m.id == messageId);
            if (idx != -1) {
              list[idx] = list[idx].copyWith(status: 'seen');
            }
          } else {
            // Mark all sent messages as seen
            for (int i = 0; i < list.length; i++) {
              if (list[i].isMine && list[i].status != 'seen') {
                list[i] = list[i].copyWith(status: 'seen');
              }
            }
          }
          notifyListeners();
        }
      }
    });

    // 3. If online server is reachable, update in background
    if (ApiService().isServerReachable) {
      _loadRoomsFromApi();
    }
  }

  Future<void> _loadRoomsFromApi() async {
    try {
      final remoteRooms = await ApiService().getChatRooms();
      if (remoteRooms.isNotEmpty) {
        _rooms = remoteRooms;
        for (final r in remoteRooms) {
          LocalStoreService().addOrUpdateRoom(r);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  ChatRoom getOrCreateCommunityRoom(String communityId, String communityName, String iconEmoji) {
    final existing = _rooms.firstWhere(
      (r) => r.communityId == communityId,
      orElse: () {
        final newRoom = ChatRoom(
          id: 'room-$communityId',
          title: '$communityName Chat',
          subtitle: 'Community discussion',
          avatarEmoji: iconEmoji,
          communityId: communityId,
          isGroup: true,
          lastMessage: 'Welcome to $communityName live chat!',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isOnline: true,
          participantIds: ['user-hardik'],
        );
        _rooms.insert(0, newRoom);
        LocalStoreService().addOrUpdateRoom(newRoom);
        return newRoom;
      },
    );
    return existing;
  }

  void markRoomAsRead(String roomId) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1 && _rooms[index].unreadCount > 0) {
      _rooms[index] = _rooms[index].copyWith(unreadCount: 0);
      LocalStoreService().markRoomAsRead(roomId);
      SocketService().markSeen(roomId, '');
      notifyListeners();
    }
  }

  List<ChatMessage> getMessages(String roomId, {String? currentUserId}) {
    if (!_messages.containsKey(roomId)) {
      final localMsgs = LocalStoreService().getMessages(roomId);
      if (localMsgs.isNotEmpty) {
        _messages[roomId] = localMsgs;
      } else {
        _messages[roomId] = [];
      }

      if (ApiService().isServerReachable) {
        ApiService().getMessages(roomId).then((msgs) {
          if (msgs.isNotEmpty) {
            _messages[roomId] = msgs;
            for (final m in msgs) {
              LocalStoreService().addMessage(m);
            }
            notifyListeners();
          }
        });
      }
    }

    final list = _messages[roomId] ?? [];
    if (currentUserId != null) {
      // Correct isMine flag relative to the active logged-in user
      return list.map((m) => m.copyWith(isMine: m.senderId == currentUserId)).toList();
    }
    return list;
  }

  void joinRoom(String roomId, String userName) {
    SocketService().joinRoom(roomId, userName);
  }

  void leaveRoom(String roomId, String userName) {
    SocketService().leaveRoom(roomId, userName);
  }

  void startTyping(String roomId, String userName) {
    SocketService().startTyping(roomId, userName);
  }

  void stopTyping(String roomId, String userName) {
    SocketService().stopTyping(roomId, userName);
  }

  /// Deterministic 1-on-1 direct room ID: sorted alphabetically so both peers land in the same room
  static String getDirectRoomId(String username1, String username2) {
    final u1 = username1.trim().toLowerCase().replaceAll('@', '');
    final u2 = username2.trim().toLowerCase().replaceAll('@', '');
    final sorted = [u1, u2]..sort();
    return 'dm-${sorted[0]}_${sorted[1]}';
  }

  ChatRoom startPersonalChat({required User peerUser, required User currentUser}) {
    final directRoomId = getDirectRoomId(currentUser.username, peerUser.username);

    final existing = _rooms.firstWhere(
      (r) => r.id == directRoomId,
      orElse: () {
        final newRoom = ChatRoom(
          id: directRoomId,
          title: peerUser.name,
          subtitle: peerUser.handle,
          avatarEmoji: '👤',
          isGroup: false,
          lastMessage: 'Started personal chat with ${peerUser.handle}',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isOnline: true,
          participantIds: [currentUser.id, peerUser.id],
        );
        _rooms.insert(0, newRoom);
        LocalStoreService().addOrUpdateRoom(newRoom);
        return newRoom;
      },
    );
    notifyListeners();
    return existing;
  }

  void editMessage(String roomId, String messageId, String newContent) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(content: newContent, isEdited: true);
        LocalStoreService().editMessage(roomId, messageId, newContent);

        // If it was the last message, update room subtitle
        if (idx == list.length - 1) {
          final roomIdx = _rooms.indexWhere((r) => r.id == roomId);
          if (roomIdx != -1) {
            _rooms[roomIdx] = _rooms[roomIdx].copyWith(lastMessage: newContent);
            LocalStoreService().addOrUpdateRoom(_rooms[roomIdx]);
          }
        }
        SocketService().editMessage(roomId, messageId, newContent);
        notifyListeners();
      }
    }
  }

  void deleteMessage(String roomId, String messageId, {bool forEveryone = false, String? userId}) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        if (forEveryone) {
          list[idx] = list[idx].copyWith(
            content: '🚫 This message was deleted',
            isDeleted: true,
          );
        } else if (userId != null) {
          final delUsers = List<String>.from(list[idx].deletedForUserIds);
          if (!delUsers.contains(userId)) delUsers.add(userId);
          list[idx] = list[idx].copyWith(deletedForUserIds: delUsers);
        } else {
          list.removeAt(idx);
        }
        LocalStoreService().deleteMessage(roomId, messageId, forEveryone: forEveryone, userId: userId);
        SocketService().deleteMessage(roomId, messageId, forEveryone);
        notifyListeners();
      }
    }
  }

  void toggleLikeMessage(String roomId, String messageId, String userId) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final current = list[idx];
        final newLikes = List<String>.from(current.likes);
        final newDislikes = List<String>.from(current.dislikes);

        newDislikes.remove(userId);
        if (newLikes.contains(userId)) {
          newLikes.remove(userId);
        } else {
          newLikes.add(userId);
        }

        list[idx] = current.copyWith(likes: newLikes, dislikes: newDislikes);
        LocalStoreService().toggleLikeMessage(roomId, messageId, userId);
        SocketService().likeMessage(roomId, messageId, userId);
        notifyListeners();
      }
    }
  }

  void toggleDislikeMessage(String roomId, String messageId, String userId) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final current = list[idx];
        final newLikes = List<String>.from(current.likes);
        final newDislikes = List<String>.from(current.dislikes);

        newLikes.remove(userId);
        if (newDislikes.contains(userId)) {
          newDislikes.remove(userId);
        } else {
          newDislikes.add(userId);
        }

        list[idx] = current.copyWith(likes: newLikes, dislikes: newDislikes);
        LocalStoreService().toggleDislikeMessage(roomId, messageId, userId);
        SocketService().dislikeMessage(roomId, messageId, userId);
        notifyListeners();
      }
    }
  }

  void sendMessage({
    required String roomId,
    required String content,
    required User currentUser,
    bool isAnonymous = false,
  }) {
    final newMsg = ChatMessage(
      id: MockDataService.generateId(),
      roomId: roomId,
      senderId: currentUser.id,
      senderName: isAnonymous ? 'Anonymous' : currentUser.name,
      senderAvatar: isAnonymous ? null : currentUser.avatarUrl,
      content: content,
      timestamp: DateTime.now(),
      isMine: true,
      isAnonymous: isAnonymous,
      status: 'seen', // Seen indicator
      likes: [],
      dislikes: [],
      isEdited: false,
      isDeleted: false,
    );

    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    _messages[roomId]!.add(newMsg);
    LocalStoreService().addMessage(newMsg);

    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(
        lastMessage: content,
        lastMessageTime: DateTime.now(),
      );
      LocalStoreService().addOrUpdateRoom(_rooms[index]);
    }
    notifyListeners();

    SocketService().sendMessage(
      id: newMsg.id,
      roomId: roomId,
      content: content,
      senderId: currentUser.id,
      senderName: isAnonymous ? 'Anonymous' : currentUser.name,
      senderUsername: currentUser.username,
      isAnonymous: isAnonymous,
    );

    // If in standalone offline mobile mode, trigger interactive realistic peer reply
    if (!SocketService.disabledForTests && !SocketService().isConnected) {
      _triggerSimulatedPeerReply(roomId, content);
    }
  }

  void _triggerSimulatedPeerReply(String roomId, String prompt) {
    final isRahulDM = roomId.contains('rahul');
    final responderName = isRahulDM ? 'Rahul Patel (@rahul_ce)' : 'DDU Peer';
    final responderId = isRahulDM ? 'user-rahul' : 'u-senior';

    // 1. Show Typing Indicator after 500ms
    Timer(const Duration(milliseconds: 500), () {
      _typingUser[roomId] = responderName;
      notifyListeners();
    });

    // 2. Deliver Realistic Response after 1.8s
    Timer(const Duration(milliseconds: 1800), () {
      _typingUser[roomId] = null;

      String replyContent = 'Got it! Check the DDU notice board or student portal for updates.';
      final lower = prompt.toLowerCase();

      if (lower.contains('basketball') || lower.contains('court') || lower.contains('gym') || lower.contains('sport')) {
        replyContent = 'Yes! Ground is open till 7:00 PM today. Let me know if you want to team up! 🏀';
      } else if (lower.contains('canteen') || lower.contains('food') || lower.contains('lunch') || lower.contains('eat')) {
        replyContent = 'The canteen behind library has fresh meals ready by 12:30 PM! 🍲';
      } else if (lower.contains('exam') || lower.contains('timetable') || lower.contains('syllabus') || lower.contains('result')) {
        replyContent = 'Mid-sem schedule was uploaded on DDU student portal. Verify with your class CR once.';
      } else if (lower.contains('hostel') || lower.contains('room') || lower.contains('gate') || lower.contains('entry')) {
        replyContent = 'Main gate in-time is 9:30 PM. Out-pass is available from the warden desk.';
      } else if (lower.contains('hi') || lower.contains('hello') || lower.contains('hey')) {
        replyContent = 'Hey Hardik! How is your semester going at DDU? Let me know if you need any notes! 👋';
      }

      final peerMsg = ChatMessage(
        id: MockDataService.generateId(),
        roomId: roomId,
        senderId: responderId,
        senderName: responderName,
        content: replyContent,
        timestamp: DateTime.now(),
        isMine: false,
        isAnonymous: false,
        status: 'seen',
      );

      if (!_messages.containsKey(roomId)) {
        _messages[roomId] = [];
      }
      _messages[roomId]!.add(peerMsg);
      LocalStoreService().addMessage(peerMsg);

      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        _rooms[index] = _rooms[index].copyWith(
          lastMessage: replyContent,
          lastMessageTime: DateTime.now(),
          unreadCount: _rooms[index].unreadCount + 1,
        );
        LocalStoreService().addOrUpdateRoom(_rooms[index]);
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _editSub?.cancel();
    _deleteSub?.cancel();
    _likeSub?.cancel();
    _dislikeSub?.cancel();
    _seenSub?.cancel();
    super.dispose();
  }
}
