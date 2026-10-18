import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
  final Map<String, StreamSubscription> _roomFirestoreSubs = {};
  final Set<String> _loadingRooms = {};
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _editSub;
  StreamSubscription<Map<String, dynamic>>? _deleteSub;
  StreamSubscription<Map<String, dynamic>>? _likeSub;
  StreamSubscription<Map<String, dynamic>>? _dislikeSub;
  StreamSubscription<Map<String, dynamic>>? _seenSub;
  StreamSubscription<Map<String, dynamic>>? _frAcceptedSub;
  String? _currentUsername;
  StreamSubscription? _userFirestoreMessagesSub;

  List<ChatRoom> get rooms => _rooms;
  String? getTypingUser(String roomId) => _typingUser[roomId];
  bool isTyping(String roomId) => _typingUser[roomId] != null;
  String? get currentUsername => _currentUsername;

  ChatProvider() {
    _initChat();
  }

  int get totalUnread => _rooms.fold<int>(0, (acc, r) => acc + r.unreadCount);

  void setCurrentUser(User? user) {
    if (user == null) {
      _currentUsername = null;
      _userFirestoreMessagesSub?.cancel();
      return;
    }
    final clean = user.username.toLowerCase().replaceAll('@', '').trim();
    if (_currentUsername == clean && _userFirestoreMessagesSub != null) return;
    _currentUsername = clean;
    _initUserFirestoreSync(clean);
  }

  void _initUserFirestoreSync(String myUsername) {
    _userFirestoreMessagesSub?.cancel();
    // Bypassed: Real-time messaging uses local Socket.IO and MongoDB.
    return;
  }

  void _initChat() {
    // 1. Immediately load rooms from local storage (purge dummy and rogue rooms)
    _rooms = LocalStoreService().getChatRooms().where((r) {
      final t = r.title.toLowerCase();
      final s = r.subtitle?.toLowerCase() ?? '';
      final id = r.id.toLowerCase();
      if (id.startsWith('room-dm-') ||
          t == 'chat' ||
          t.endsWith(' chat') ||
          t.contains('rahul') ||
          t.contains('canteen') ||
          t.contains('mumbai developer') ||
          t.contains('hostel group') ||
          t.contains('official chat') ||
          t.contains('robotics') ||
          s.contains('rahul') ||
          id.startsWith('room-c') ||
          id.contains('rahul')) {
        return false;
      }
      return true;
    }).toList();
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
        _messages[msg.roomId]![existingIdx] = msg;
        LocalStoreService().addMessage(msg);
        notifyListeners();
        return;
      }

      _messages[msg.roomId]!.add(msg);
      LocalStoreService().addMessage(msg);

      final index = _rooms.indexWhere((r) => r.id == msg.roomId);
      if (index != -1) {
        final currentRoom = _rooms.removeAt(index);
        final updated = currentRoom.copyWith(
          lastMessage: msg.content,
          lastMessageTime: msg.timestamp,
          unreadCount: currentRoom.unreadCount + (msg.isMine ? 0 : 1),
        );
        _rooms.insert(0, updated);
        LocalStoreService().addOrUpdateRoom(updated);
      } else {
        // Auto-create direct conversation room if recipient hasn't opened it yet
        final displayHandle = msg.senderName.startsWith('@')
            ? msg.senderName
            : '@${msg.senderName.toLowerCase().replaceAll(' ', '')}';
        final newRoom = ChatRoom(
          id: msg.roomId,
          title: displayHandle,
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
      final serverLikes = data['likes'] != null ? List<String>.from(data['likes']) : null;
      final serverDislikes = data['dislikes'] != null ? List<String>.from(data['dislikes']) : null;

      if (roomId != null && messageId != null) {
        var list = _messages[roomId];
        if (list == null) {
          _messages[roomId] = LocalStoreService().getMessages(roomId);
          list = _messages[roomId];
        }

        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final cur = list[idx];
            List<String> finalLikes;
            List<String> finalDislikes;
            if (serverLikes != null && serverDislikes != null) {
              finalLikes = serverLikes;
              finalDislikes = serverDislikes;
            } else if (userId != null) {
              finalLikes = List<String>.from(cur.likes);
              finalDislikes = List<String>.from(cur.dislikes);
              finalDislikes.remove(userId);
              if (finalLikes.contains(userId)) {
                finalLikes.remove(userId);
              } else {
                finalLikes.add(userId);
              }
            } else {
              return;
            }
            list[idx] = cur.copyWith(likes: finalLikes, dislikes: finalDislikes);
            LocalStoreService().updateMessageLikes(roomId, messageId, finalLikes, finalDislikes);
            notifyListeners();
          } else if (serverLikes != null && serverDislikes != null) {
            LocalStoreService().updateMessageLikes(roomId, messageId, serverLikes, serverDislikes);
          }
        }
      }
    });

    // Handle real-time dislikes
    _dislikeSub = SocketService().onMessageDisliked.listen((data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      final userId = data['userId'] as String?;
      final serverLikes = data['likes'] != null ? List<String>.from(data['likes']) : null;
      final serverDislikes = data['dislikes'] != null ? List<String>.from(data['dislikes']) : null;

      if (roomId != null && messageId != null) {
        var list = _messages[roomId];
        if (list == null) {
          _messages[roomId] = LocalStoreService().getMessages(roomId);
          list = _messages[roomId];
        }

        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final cur = list[idx];
            List<String> finalLikes;
            List<String> finalDislikes;
            if (serverLikes != null && serverDislikes != null) {
              finalLikes = serverLikes;
              finalDislikes = serverDislikes;
            } else if (userId != null) {
              finalLikes = List<String>.from(cur.likes);
              finalDislikes = List<String>.from(cur.dislikes);
              finalLikes.remove(userId);
              if (finalDislikes.contains(userId)) {
                finalDislikes.remove(userId);
              } else {
                finalDislikes.add(userId);
              }
            } else {
              return;
            }
            list[idx] = cur.copyWith(likes: finalLikes, dislikes: finalDislikes);
            LocalStoreService().updateMessageLikes(roomId, messageId, finalLikes, finalDislikes);
            notifyListeners();
          } else if (serverLikes != null && serverDislikes != null) {
            LocalStoreService().updateMessageLikes(roomId, messageId, serverLikes, serverDislikes);
          }
        }
      }
    });

    // Handle real-time friend request accepted: dynamically add DM room to chat list for both peers
    _frAcceptedSub = SocketService().onFriendRequestAccepted.listen((data) async {
      try {
        final sUser = (data['senderUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        final rUser = (data['receiverUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        
        // Ensure my username is available; fallback to cached session if ChatProvider was newly created
        String cleanMy = (_currentUsername ?? '').trim().toLowerCase().replaceAll('@', '');
        if (cleanMy.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getString('saved_user');
          if (saved != null) {
            final u = jsonDecode(saved);
            final uname = u['username'] as String?;
            if (uname != null && uname.isNotEmpty) {
              cleanMy = uname.toLowerCase().replaceAll('@', '').trim();
              _currentUsername = cleanMy;
            }
          }
        }

        // Determine who the other peer is in this accepted friendship
        final otherUname = (sUser == cleanMy) ? rUser : (rUser == cleanMy ? sUser : '');
        if (otherUname.isNotEmpty) {
          final directRoomId = getDirectRoomId(cleanMy, otherUname);
          // Auto-instantiate the direct conversation room and dynamically update the UI
          getOrCreateDirectRoom(directRoomId, cleanMy, otherUsername: otherUname);
          debugPrint('[ChatProvider] Dynamically created direct room $directRoomId for @$otherUname');
        }
      } catch (e) {
        debugPrint('[ChatProvider] onFriendRequestAccepted error: $e');
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
      final cleanRooms = remoteRooms.where((r) {
        final t = r.title.toLowerCase();
        final s = r.subtitle?.toLowerCase() ?? '';
        final id = r.id.toLowerCase();
        if (t.contains('rahul') ||
            t.contains('canteen') ||
            t.contains('mumbai developer') ||
            t.contains('hostel group') ||
            t.contains('official chat') ||
            t.contains('robotics') ||
            s.contains('rahul') ||
            id.startsWith('room-c') ||
            id.contains('rahul')) {
          return false;
        }
        return true;
      }).toList();

      if (cleanRooms.isNotEmpty) {
        _rooms = cleanRooms;
        for (final r in cleanRooms) {
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
          title: communityName,
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

  ChatRoom getOrCreateDirectRoom(String roomId, String currentUsername, {String? otherUsername, String? otherName}) {
    final existingIdx = _rooms.indexWhere((r) => r.id == roomId);
    if (existingIdx != -1) {
      return _rooms[existingIdx];
    }
    final other = (otherUsername ?? getOtherUsernameFromDmRoomId(roomId, currentUsername) ?? 'Member')
        .toLowerCase()
        .replaceAll('@', '')
        .trim();
    final newRoom = ChatRoom(
      id: roomId,
      title: '@$other',
      subtitle: (otherName != null && otherName.isNotEmpty) ? otherName : '@$other',
      avatarEmoji: '👤',
      isGroup: false,
      lastMessage: 'You are connected! Say hello 👋',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isOnline: true,
      participantIds: [currentUsername, other],
    );
    _rooms.insert(0, newRoom);
    LocalStoreService().addOrUpdateRoom(newRoom);
    notifyListeners();
    return newRoom;
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

  ChatMessage? getLastMessage(String roomId) {
    final cached = _messages[roomId];
    if (cached != null && cached.isNotEmpty) {
      return cached.last;
    }
    final localMsgs = LocalStoreService().getMessages(roomId);
    if (localMsgs.isNotEmpty) {
      _messages[roomId] = List<ChatMessage>.from(localMsgs);
      return localMsgs.last;
    }
    return null;
  }

  List<ChatMessage> getMessages(String roomId, {String? currentUserId}) {
    if (!_messages.containsKey(roomId)) {
      final localMsgs = LocalStoreService().getMessages(roomId);
      _messages[roomId] = List<ChatMessage>.from(localMsgs);

      if (ApiService().isServerReachable && !_loadingRooms.contains(roomId)) {
        _loadingRooms.add(roomId);
        ApiService().getMessages(roomId).then((msgs) {
          if (msgs.isNotEmpty) {
            bool hasNew = false;
            for (final m in msgs) {
              final existingIdx = _messages[roomId]!.indexWhere((item) =>
                  item.id == m.id ||
                  (item.senderId == m.senderId &&
                      item.content.trim() == m.content.trim() &&
                      item.timestamp.difference(m.timestamp).abs().inSeconds < 5));
              if (existingIdx != -1) {
                _messages[roomId]![existingIdx] = m;
              } else {
                _messages[roomId]!.add(m);
                hasNew = true;
              }
            }
            LocalStoreService().addMessages(msgs);
            if (hasNew) {
              _messages[roomId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              notifyListeners();
            }
          }
        }).catchError((_) {}).whenComplete(() {
          _loadingRooms.remove(roomId);
        });
      }
    }

    final raw = _messages[roomId] ?? [];
    // Deduplicate in memory
    final List<ChatMessage> deduplicated = [];
    for (final m in raw) {
      final sContent = m.content.trim();
      final hasDup = deduplicated.any((u) =>
          u.id == m.id ||
          (u.senderId == m.senderId &&
              u.content.trim() == sContent &&
              u.timestamp.difference(m.timestamp).abs().inSeconds < 5));
      if (!hasDup) {
        deduplicated.add(m);
      }
    }

    if (currentUserId != null) {
      return deduplicated.map((m) => m.copyWith(isMine: m.senderId == currentUserId)).toList();
    }
    return deduplicated;
  }

  void joinRoom(String roomId, String userName) {
    SocketService().joinRoom(roomId, userName);
    _listenToRoomFirestore(roomId);
  }

  void clearAllRooms() {
    _rooms = [];
    _messages.clear();
    LocalStoreService().clearChatData();
    notifyListeners();
  }

  void _listenToRoomFirestore(String roomId) {
    // Bypassed: Real-time messaging uses local Socket.IO and MongoDB.
    // Disabling legacy Firestore room stream prevents old messages from polluting live chat.
    return;
  }

  void leaveRoom(String roomId, String userName) {
    SocketService().leaveRoom(roomId, userName);
    _roomFirestoreSubs[roomId]?.cancel();
    _roomFirestoreSubs.remove(roomId);
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

  /// Safely extracts the other peer's username from a deterministic DM room ID
  /// (Works seamlessly even when usernames contain underscores, dots, or hyphens)
  static String? getOtherUsernameFromDmRoomId(String roomId, String currentUsername) {
    if (!roomId.startsWith('dm-')) return null;
    final stripped = roomId.substring(3).toLowerCase().trim();
    final cleanCurrent = currentUsername.toLowerCase().replaceAll('@', '').trim();
    if (stripped.startsWith('${cleanCurrent}_')) {
      return stripped.substring(cleanCurrent.length + 1);
    } else if (stripped.endsWith('_$cleanCurrent')) {
      return stripped.substring(0, stripped.length - cleanCurrent.length - 1);
    }
    return null;
  }

  ChatRoom startPersonalChat({required User peerUser, required User currentUser}) {
    final directRoomId = getDirectRoomId(currentUser.username, peerUser.username);

    final existingIdx = _rooms.indexWhere((r) => r.id == directRoomId);
    if (existingIdx != -1) {
      _listenToRoomFirestore(directRoomId);
      return _rooms[existingIdx];
    }

    final newRoom = ChatRoom(
      id: directRoomId,
      title: peerUser.handle,
      subtitle: peerUser.name,
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
    _listenToRoomFirestore(directRoomId);

    // Sync room to Firestore for persistence
    if (Firebase.apps.isNotEmpty) {
      try {
        final cUserClean = currentUser.username.toLowerCase().replaceAll('@', '');
        final pUserClean = peerUser.username.toLowerCase().replaceAll('@', '');
        FirebaseFirestore.instance.collection('chatRooms').doc(directRoomId).set({
          'id': directRoomId,
          'title': peerUser.handle,
          'subtitle': peerUser.name,
          'avatarEmoji': '👤',
          'isGroup': false,
          'lastMessage': newRoom.lastMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participantIds': [currentUser.id, peerUser.id],
          'participantUsernames': [cUserClean, pUserClean],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    notifyListeners();
    return newRoom;
  }

  void editMessage(String roomId, String messageId, String newContent) {
    final list = _messages[roomId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(content: newContent, isEdited: true);
        LocalStoreService().editMessage(roomId, messageId, newContent);

        // 1. Cloud Firestore update
        if (Firebase.apps.isNotEmpty) {
          try {
            FirebaseFirestore.instance.collection('messages').doc(messageId).update({
              'content': newContent,
              'isEdited': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }

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

        // 1. Cloud Firestore delete / update
        if (Firebase.apps.isNotEmpty) {
          try {
            if (forEveryone) {
              FirebaseFirestore.instance.collection('messages').doc(messageId).update({
                'content': '🚫 This message was deleted',
                'isDeleted': true,
              });
            } else {
              FirebaseFirestore.instance.collection('messages').doc(messageId).delete();
            }
          } catch (_) {}
        }
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

        // Online Cloud Firestore sync
        if (Firebase.apps.isNotEmpty) {
          try {
            FirebaseFirestore.instance.collection('messages').doc(messageId).update({
              'likes': newLikes,
              'dislikes': newDislikes,
            });
          } catch (_) {}
        }

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

        // Online Cloud Firestore sync
        if (Firebase.apps.isNotEmpty) {
          try {
            FirebaseFirestore.instance.collection('messages').doc(messageId).update({
              'likes': newLikes,
              'dislikes': newDislikes,
            });
          } catch (_) {}
        }

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
      status: 'sent', // 1. Initial WhatsApp status: Single grey tick
      likes: [],
      dislikes: [],
      isEdited: false,
      isDeleted: false,
    );

    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    _messages[roomId]!.add(newMsg);
    _messages[roomId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    LocalStoreService().addMessage(newMsg);

    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final currentRoom = _rooms.removeAt(index);
      final updated = currentRoom.copyWith(
        lastMessage: content,
        lastMessageTime: DateTime.now(),
      );
      _rooms.insert(0, updated);
      LocalStoreService().addOrUpdateRoom(updated);
    }
    notifyListeners();

    // 1. Cloud Firestore write
    if (Firebase.apps.isNotEmpty) {
      try {
        FirebaseFirestore.instance.collection('messages').doc(newMsg.id).set({
          ...newMsg.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[ChatProvider] Firestore sendMessage notice: $e');
      }
    }

    SocketService().sendMessage(
      id: newMsg.id,
      roomId: roomId,
      content: content,
      senderId: currentUser.id,
      senderName: isAnonymous ? 'Anonymous' : currentUser.name,
      senderUsername: currentUser.username,
      isAnonymous: isAnonymous,
      timestamp: newMsg.timestamp.toIso8601String(),
    );

    // Realistic WhatsApp tick progression:
    // After 600ms: transition to 'delivered' (double grey tick)
    Timer(const Duration(milliseconds: 600), () {
      final list = _messages[roomId];
      if (list != null) {
        final mIdx = list.indexWhere((m) => m.id == newMsg.id);
        if (mIdx != -1 && list[mIdx].status == 'sent') {
          list[mIdx] = list[mIdx].copyWith(status: 'delivered');
          LocalStoreService().addMessage(list[mIdx]);
          notifyListeners();
        }
      }
    });

    // After 1800ms: transition to 'seen' (double blue tick)
    Timer(const Duration(milliseconds: 1800), () {
      final list = _messages[roomId];
      if (list != null) {
        final mIdx = list.indexWhere((m) => m.id == newMsg.id);
        if (mIdx != -1 && list[mIdx].status != 'seen') {
          list[mIdx] = list[mIdx].copyWith(status: 'seen');
          LocalStoreService().addMessage(list[mIdx]);
          notifyListeners();
        }
      }
    });

  }

  void _triggerSimulatedPeerReply(String roomId, String prompt) {
    final isRahulDM = roomId.contains('rahul');
    final responderName = isRahulDM ? 'Rahul Patel (@rahul_ce)' : 'EchoGram Peer';
    final responderId = isRahulDM ? 'user-rahul' : 'u-peer';

    // 1. Show Typing Indicator after 500ms
    Timer(const Duration(milliseconds: 500), () {
      _typingUser[roomId] = responderName;
      notifyListeners();
    });

    // 2. Deliver Realistic Response after 1.8s
    Timer(const Duration(milliseconds: 1800), () {
      _typingUser[roomId] = null;

      String replyContent = 'Got it! Thanks for reaching out.';
      final lower = prompt.toLowerCase();

      if (lower.contains('basketball') || lower.contains('court') || lower.contains('gym') || lower.contains('sport')) {
        replyContent = 'Yes! Let me know if you want to team up! 🏀';
      } else if (lower.contains('coffee') || lower.contains('food') || lower.contains('lunch') || lower.contains('eat')) {
        replyContent = 'Sounds great, let me know the place and time! 🍲';
      } else if (lower.contains('project') || lower.contains('code') || lower.contains('work')) {
        replyContent = 'Sounds interesting! Let me know if you want to collaborate on it.';
      } else if (lower.contains('hi') || lower.contains('hello') || lower.contains('hey')) {
        replyContent = 'Hey! Doing great, how is everything going with you? 👋';
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
    _frAcceptedSub?.cancel();
    _userFirestoreMessagesSub?.cancel();
    super.dispose();
  }
}
