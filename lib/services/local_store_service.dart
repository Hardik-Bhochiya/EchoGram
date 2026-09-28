import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';
import '../models/reply.dart';
import '../models/community.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import 'mock_data_service.dart';

/// LocalStoreService delivers permanent offline persistence on physical mobile
/// devices with zero requirement for an active laptop or local server.
class LocalStoreService {
  static final LocalStoreService _instance = LocalStoreService._internal();
  factory LocalStoreService() => _instance;
  LocalStoreService._internal();

  static const String _keyQuestions = 'nt_local_questions_v2';
  static const String _keyCommunities = 'nt_local_communities_v4';
  static const String _keyChatRooms = 'nt_local_chat_rooms_v2';
  static const String _keyChatMessages = 'nt_local_chat_messages_v2';
  static const String _keyFriendRequests = 'nt_local_friend_requests_v2';
  static const String _keyUserFriends = 'nt_local_user_friends_v2';
  static const String _keyLocations = 'nt_local_locations_v2';
  static const String _keyUsers = 'nt_local_users_v2';
  static const String _keyCustomBackendUrl = 'nt_custom_backend_url';

  bool _initialized = false;
  List<Question> _questions = [];
  List<Community> _communities = [];
  List<String> _locations = [];
  List<User> _users = [];
  List<ChatRoom> _chatRooms = [];
  Map<String, List<ChatMessage>> _messages = {};
  List<FriendRequest> _friendRequests = [];
  Map<String, List<String>> _userFriends = {};
  String? _customBackendUrl;

  bool get isInitialized => _initialized;
  String? get customBackendUrl => _customBackendUrl;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Custom Server URL
      _customBackendUrl = prefs.getString(_keyCustomBackendUrl);

      // 2. Load Questions
      final qStr = prefs.getString(_keyQuestions);
      if (qStr != null && qStr.isNotEmpty) {
        final list = jsonDecode(qStr) as List<dynamic>;
        _questions = list.map((item) => Question.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _questions = [];
        _persistQuestions();
      }

      // 3. Load Communities (User-created communities only, purge fake mock communities)
      final cStr = prefs.getString(_keyCommunities);
      if (cStr != null && cStr.isNotEmpty) {
        final list = jsonDecode(cStr) as List<dynamic>;
        _communities = list
            .map((item) => Community.fromJson(item as Map<String, dynamic>))
            .where((c) => !c.id.startsWith('c') && c.memberCount < 100 && !c.name.toLowerCase().contains('canteen') && !c.name.toLowerCase().contains('mumbai'))
            .toList();
      } else {
        _communities = [];
      }
      _persistCommunities();

      // 4. Load Locations (Dynamic campus / city locations - 5 real defaults)
      final locStr = prefs.getString(_keyLocations);
      if (locStr != null && locStr.isNotEmpty) {
        final list = jsonDecode(locStr) as List<dynamic>;
        _locations = list.map((e) => e.toString()).where((l) => l != 'Mumbai' && l != 'Dwarka').toList();
        if (_locations.isEmpty) {
          _locations = ['DDU Nadiad', 'Nadiad', 'Ahmedabad', 'Vadodara', 'Gandhinagar'];
        }
      } else {
        _locations = ['DDU Nadiad', 'Nadiad', 'Ahmedabad', 'Vadodara', 'Gandhinagar'];
        _persistLocations();
      }

      // 5. Load Registered Users
      final uStr = prefs.getString(_keyUsers);
      if (uStr != null && uStr.isNotEmpty) {
        final list = jsonDecode(uStr) as List<dynamic>;
        _users = list.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _users = [];
      }

      // 6. Load Chat Rooms
      final rStr = prefs.getString(_keyChatRooms);
      if (rStr != null && rStr.isNotEmpty) {
        final list = jsonDecode(rStr) as List<dynamic>;
        _chatRooms = list.map((item) => ChatRoom.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _chatRooms = [];
        _persistChatRooms();
      }

      // 5. Load Chat Messages
      final mStr = prefs.getString(_keyChatMessages);
      if (mStr != null && mStr.isNotEmpty) {
        final map = jsonDecode(mStr) as Map<String, dynamic>;
        _messages = map.map((roomId, list) {
          final msgs = (list as List<dynamic>)
              .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
              .toList();
          return MapEntry(roomId, msgs);
        });
      } else {
        _messages = {};
        _persistMessages();
      }

      // 6. Load Friend Requests
      final frStr = prefs.getString(_keyFriendRequests);
      if (frStr != null && frStr.isNotEmpty) {
        final list = jsonDecode(frStr) as List<dynamic>;
        _friendRequests = list.map((item) => FriendRequest.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _friendRequests = [];
        _persistFriendRequests();
      }

      // 7. Load User Friends
      final ufStr = prefs.getString(_keyUserFriends);
      if (ufStr != null && ufStr.isNotEmpty) {
        final map = jsonDecode(ufStr) as Map<String, dynamic>;
        _userFriends = map.map((k, v) => MapEntry(k, List<String>.from(v as List<dynamic>)));
      } else {
        _userFriends = {};
        _persistUserFriends();
      }

      _initialized = true;
      debugPrint('[LocalStore] Initialized successfully with offline persistence.');
    } catch (e) {
      debugPrint('[LocalStore] Initialization fallback: $e');
      _questions = List.from(MockDataService.initialQuestions);
      _communities = [];
      _locations = ['DDU Nadiad', 'Nadiad', 'Ahmedabad', 'Vadodara', 'Gandhinagar'];
      _chatRooms = [];
      _friendRequests = [];
      _userFriends = {};
      _initialized = true;
    }
  }

  // --- Questions ---

  List<Question> getQuestions({String? communityId, String? tag, String? search}) {
    var list = List<Question>.from(_questions);

    if (communityId != null) {
      list = list.where((q) => q.communityId == communityId).toList();
    }
    if (tag != null && tag != 'All') {
      list = list.where((q) => q.tags.contains(tag)).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      list = list.where((q) =>
          q.title.toLowerCase().contains(query) ||
          q.content.toLowerCase().contains(query) ||
          q.communityName.toLowerCase().contains(query) ||
          q.tags.any((t) => t.toLowerCase().contains(query))).toList();
    }
    return list;
  }

  Question? getQuestionById(String id) {
    try {
      return _questions.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  void addQuestion(Question q) {
    _questions.insert(0, q);
    _persistQuestions();
  }

  void updateQuestion(Question q) {
    final index = _questions.indexWhere((item) => item.id == q.id);
    if (index != -1) {
      _questions[index] = q;
      _persistQuestions();
    }
  }

  void toggleUpvote(String questionId) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      final newUpvoted = !q.isUpvotedByMe;
      final newCount = newUpvoted ? q.upvotes + 1 : q.upvotes - 1;
      _questions[index] = q.copyWith(
        isUpvotedByMe: newUpvoted,
        upvotes: newCount < 0 ? 0 : newCount,
      );
      _persistQuestions();
    }
  }

  void addReply(String questionId, Reply reply) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      final updatedReplies = List<Reply>.from(q.replies)..add(reply);
      _questions[index] = q.copyWith(replies: updatedReplies);
      _persistQuestions();
    }
  }

  void toggleBookmark(String questionId) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      _questions[index] = q.copyWith(isBookmarked: !q.isBookmarked);
      _persistQuestions();
    }
  }

  // --- Communities ---

  List<Community> getCommunities() => List<Community>.from(_communities);

  Community? getCommunityById(String id) {
    try {
      return _communities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void addCommunity(Community community) {
    _communities.insert(0, community);
    _persistCommunities();
  }

  void deleteCommunity(String communityId) {
    _communities.removeWhere((c) => c.id == communityId);
    _persistCommunities();
  }

  void toggleJoinCommunity(String communityId) {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index != -1) {
      final current = _communities[index];
      final newJoined = !current.isJoined;
      final newCount = newJoined ? current.memberCount + 1 : current.memberCount - 1;
      _communities[index] = current.copyWith(
        isJoined: newJoined,
        memberCount: newCount < 0 ? 0 : newCount,
      );
      _persistCommunities();
    }
  }

  // --- Locations ---

  List<String> getLocations() => List<String>.from(_locations);

  void addLocation(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (trimmed.isEmpty) return;
    final exists = _locations.any((l) => l.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      _locations.add(trimmed);
      _persistLocations();
    }
  }

  Future<void> _persistLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocations, jsonEncode(_locations));
    } catch (_) {}
  }

  // --- Chat ---

  List<ChatRoom> getChatRooms() => List<ChatRoom>.from(_chatRooms);

  List<ChatMessage> getMessages(String roomId) {
    return List<ChatMessage>.from(_messages[roomId] ?? []);
  }

  void addMessage(ChatMessage message) {
    if (!_messages.containsKey(message.roomId)) {
      _messages[message.roomId] = [];
    }
    _messages[message.roomId]!.add(message);
    _persistMessages();

    // Update Room's last message
    final index = _chatRooms.indexWhere((r) => r.id == message.roomId);
    if (index != -1) {
      _chatRooms[index] = _chatRooms[index].copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
      );
      _persistChatRooms();
    }
  }

  void editMessage(String roomId, String messageId, String newContent) {
    final roomMsgs = _messages[roomId];
    if (roomMsgs != null) {
      final idx = roomMsgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        roomMsgs[idx] = roomMsgs[idx].copyWith(
          content: newContent,
          isEdited: true,
        );
        _persistMessages();
      }
    }
  }

  void deleteMessage(String roomId, String messageId, {bool forEveryone = false, String? userId}) {
    final roomMsgs = _messages[roomId];
    if (roomMsgs != null) {
      final idx = roomMsgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        if (forEveryone) {
          roomMsgs[idx] = roomMsgs[idx].copyWith(
            content: '🚫 This message was deleted',
            isDeleted: true,
          );
        } else if (userId != null) {
          final delUsers = List<String>.from(roomMsgs[idx].deletedForUserIds);
          if (!delUsers.contains(userId)) delUsers.add(userId);
          roomMsgs[idx] = roomMsgs[idx].copyWith(deletedForUserIds: delUsers);
        } else {
          roomMsgs.removeAt(idx);
        }
        _persistMessages();
      }
    }
  }

  void toggleLikeMessage(String roomId, String messageId, String userId) {
    final roomMsgs = _messages[roomId];
    if (roomMsgs != null) {
      final idx = roomMsgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final current = roomMsgs[idx];
        final newLikes = List<String>.from(current.likes);
        final newDislikes = List<String>.from(current.dislikes);

        newDislikes.remove(userId);
        if (newLikes.contains(userId)) {
          newLikes.remove(userId);
        } else {
          newLikes.add(userId);
        }

        roomMsgs[idx] = current.copyWith(likes: newLikes, dislikes: newDislikes);
        _persistMessages();
      }
    }
  }

  void toggleDislikeMessage(String roomId, String messageId, String userId) {
    final roomMsgs = _messages[roomId];
    if (roomMsgs != null) {
      final idx = roomMsgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final current = roomMsgs[idx];
        final newLikes = List<String>.from(current.likes);
        final newDislikes = List<String>.from(current.dislikes);

        newLikes.remove(userId);
        if (newDislikes.contains(userId)) {
          newDislikes.remove(userId);
        } else {
          newDislikes.add(userId);
        }

        roomMsgs[idx] = current.copyWith(likes: newLikes, dislikes: newDislikes);
        _persistMessages();
      }
    }
  }

  void addOrUpdateRoom(ChatRoom room) {
    final index = _chatRooms.indexWhere((r) => r.id == room.id);
    if (index != -1) {
      _chatRooms[index] = room;
    } else {
      _chatRooms.insert(0, room);
    }
    _persistChatRooms();
  }

  void markRoomAsRead(String roomId) {
    final index = _chatRooms.indexWhere((r) => r.id == roomId);
    if (index != -1 && _chatRooms[index].unreadCount > 0) {
      _chatRooms[index] = _chatRooms[index].copyWith(unreadCount: 0);
      _persistChatRooms();
    }
  }

  // --- Custom Server Configuration ---

  Future<void> setCustomBackendUrl(String? url) async {
    _customBackendUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    final prefs = await SharedPreferences.getInstance();
    if (_customBackendUrl != null) {
      await prefs.setString(_keyCustomBackendUrl, _customBackendUrl!);
    } else {
      await prefs.remove(_keyCustomBackendUrl);
    }
  }

  // --- Background Write-Through Helpers ---

  Future<void> _persistQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _questions.map((q) => q.toJson()).toList();
      await prefs.setString(_keyQuestions, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LocalStore] Persist questions error: $e');
    }
  }

  Future<void> _persistCommunities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _communities.map((c) => c.toJson()).toList();
      await prefs.setString(_keyCommunities, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LocalStore] Persist communities error: $e');
    }
  }

  Future<void> _persistChatRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _chatRooms.map((r) => r.toJson()).toList();
      await prefs.setString(_keyChatRooms, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LocalStore] Persist chat rooms error: $e');
    }
  }

  Future<void> _persistMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _messages.map((roomId, list) {
        return MapEntry(roomId, list.map((m) => m.toJson()).toList());
      });
      await prefs.setString(_keyChatMessages, jsonEncode(map));
    } catch (e) {
      debugPrint('[LocalStore] Persist messages error: $e');
    }
  }

  // --- Friends & Friend Requests ---

  List<FriendRequest> getFriendRequests(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    return _friendRequests.where((r) =>
        r.senderUsername.toLowerCase() == clean ||
        r.receiverUsername.toLowerCase() == clean).toList();
  }

  List<FriendRequest> getPendingIncomingRequests(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    return _friendRequests.where((r) =>
        r.receiverUsername.toLowerCase() == clean && r.status == 'pending').toList();
  }

  List<FriendRequest> getPendingOutgoingRequests(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    return _friendRequests.where((r) =>
        r.senderUsername.toLowerCase() == clean && r.status == 'pending').toList();
  }

  bool areFriends(String username1, String username2) {
    final u1 = username1.trim().toLowerCase().replaceAll('@', '');
    final u2 = username2.trim().toLowerCase().replaceAll('@', '');
    if (u1 == u2) return true;
    final friends = _userFriends[u1] ?? [];
    return friends.map((f) => f.toLowerCase()).contains(u2);
  }

  List<String> getFriendUsernames(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    return List<String>.unmodifiable(_userFriends[clean] ?? []);
  }

  void addFriendRequest(FriendRequest req) {
    final existingIdx = _friendRequests.indexWhere((r) =>
        (r.senderUsername.toLowerCase() == req.senderUsername.toLowerCase() &&
         r.receiverUsername.toLowerCase() == req.receiverUsername.toLowerCase()) ||
        r.id == req.id);
    if (existingIdx != -1) {
      _friendRequests[existingIdx] = req;
    } else {
      _friendRequests.insert(0, req);
    }
    _persistFriendRequests();
  }

  void respondFriendRequest(String requestId, String status) {
    final idx = _friendRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _friendRequests[idx].copyWith(status: status);
      _friendRequests[idx] = req;

      if (status == 'accepted') {
        final u1 = req.senderUsername.trim().toLowerCase().replaceAll('@', '');
        final u2 = req.receiverUsername.trim().toLowerCase().replaceAll('@', '');

        _userFriends.putIfAbsent(u1, () => []);
        if (!_userFriends[u1]!.contains(u2)) _userFriends[u1]!.add(u2);

        _userFriends.putIfAbsent(u2, () => []);
        if (!_userFriends[u2]!.contains(u1)) _userFriends[u2]!.add(u1);

        _persistUserFriends();
      }
      _persistFriendRequests();
    }
  }

  void cancelFriendRequest(String senderUsername, String receiverUsername) {
    final sUser = senderUsername.trim().toLowerCase().replaceAll('@', '');
    final rUser = receiverUsername.trim().toLowerCase().replaceAll('@', '');
    _friendRequests.removeWhere((r) =>
        (r.senderUsername.trim().toLowerCase().replaceAll('@', '') == sUser &&
         r.receiverUsername.trim().toLowerCase().replaceAll('@', '') == rUser) ||
        (r.senderUsername.trim().toLowerCase().replaceAll('@', '') == rUser &&
         r.receiverUsername.trim().toLowerCase().replaceAll('@', '') == sUser));
    _persistFriendRequests();
  }

  void addFriend(String user1, String user2) {
    final u1 = user1.trim().toLowerCase().replaceAll('@', '');
    final u2 = user2.trim().toLowerCase().replaceAll('@', '');
    if (u1.isEmpty || u2.isEmpty || u1 == u2) return;

    _userFriends.putIfAbsent(u1, () => []);
    if (!_userFriends[u1]!.contains(u2)) _userFriends[u1]!.add(u2);

    _userFriends.putIfAbsent(u2, () => []);
    if (!_userFriends[u2]!.contains(u1)) _userFriends[u2]!.add(u1);

    _persistUserFriends();
  }

  void removeFriend(String username1, String username2) {
    final u1 = username1.trim().toLowerCase().replaceAll('@', '');
    final u2 = username2.trim().toLowerCase().replaceAll('@', '');
    _userFriends[u1]?.remove(u2);
    _userFriends[u2]?.remove(u1);
    _persistUserFriends();
  }

  Future<void> _persistFriendRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _friendRequests.map((r) => r.toJson()).toList();
      await prefs.setString(_keyFriendRequests, jsonEncode(list));
    } catch (e) {
      debugPrint('[LocalStore] Persist friend requests error: $e');
    }
  }

  Future<void> _persistUserFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserFriends, jsonEncode(_userFriends));
    } catch (e) {
      debugPrint('[LocalStore] Persist user friends error: $e');
    }
  }

  // --- Registered Users ---

  List<User> getRegisteredUsers() => List.unmodifiable(_users);

  bool isUsernameTaken(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;
    return _users.any((u) => u.username.toLowerCase() == clean);
  }

  void saveUser(User user) {
    final idx = _users.indexWhere((u) =>
        u.id == user.id ||
        u.username.toLowerCase() == user.username.toLowerCase());
    if (idx != -1) {
      _users[idx] = user;
    } else {
      _users.insert(0, user);
    }
    _persistUsers();
  }

  List<User> searchUsers(String query, {String? excludeUserId}) {
    final clean = query.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return [];
    return _users.where((u) {
      if (excludeUserId != null && u.id == excludeUserId) return false;
      return u.username.toLowerCase().contains(clean) ||
             u.name.toLowerCase().contains(clean);
    }).toList();
  }

  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _users.map((u) => u.toJson()).toList();
      await prefs.setString(_keyUsers, jsonEncode(list));
    } catch (e) {
      debugPrint('[LocalStore] Persist users error: $e');
    }
  }
}
