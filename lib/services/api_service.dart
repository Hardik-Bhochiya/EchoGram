import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/community.dart';
import '../models/question.dart';
import '../models/reply.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import 'mock_data_service.dart';
import 'local_store_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  bool _isServerReachable = false;
  bool _hasCheckedReachability = false;

  bool get isServerReachable => _isServerReachable;

  String get baseUrl {
    final customUrl = LocalStoreService().customBackendUrl;
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl.endsWith('/api') ? customUrl : '$customUrl/api';
    }

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:5000/api';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5000/api'
        : 'http://localhost:5000/api';
  }

  String? _authToken;

  Future<void> init() async {
    await LocalStoreService().init();
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    await checkServerReachability();
  }

  /// Fast 600ms non-blocking check to determine if an active backend server is connected
  Future<bool> checkServerReachability() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(milliseconds: 650));
      _isServerReachable = response.statusCode == 200;
    } catch (_) {
      _isServerReachable = false;
    }
    _hasCheckedReachability = true;
    return _isServerReachable;
  }

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<bool> checkUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;

    // Check locally registered cache first
    if (LocalStoreService().isUsernameTaken(clean)) {
      return false;
    }

    try {
      final res = await http
          .get(Uri.parse('$baseUrl/auth/check-username/$clean'), headers: _headers)
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        _isServerReachable = true;
        _hasCheckedReachability = true;
        final data = jsonDecode(res.body);
        return data['available'] as bool? ?? false;
      }
    } catch (_) {}
    return true;
  }

  Future<List<User>> searchPeers(String query) async {
    try {
      final qTrim = query.trim();
      final uri = Uri.parse('$baseUrl/auth/users').replace(
        queryParameters: qTrim.isNotEmpty ? {'q': qTrim} : null,
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _isServerReachable = true;
        _hasCheckedReachability = true;
        final data = jsonDecode(res.body);
        if (data['users'] != null) {
          return (data['users'] as List).map((j) => User.fromJson(j)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Friends: Send Request
  Future<bool> sendFriendRequest({
    required String senderId,
    required String senderUsername,
    required String senderName,
    required String receiverUsername,
    String? senderAvatar,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends/request'),
            headers: _headers,
            body: jsonEncode({
              'senderId': senderId,
              'senderUsername': senderUsername,
              'senderName': senderName,
              'senderAvatar': senderAvatar ?? '👤',
              'receiverUsername': receiverUsername,
            }),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Friends: Respond (accept/decline)
  Future<bool> respondFriendRequest(String requestId, String status, {String? senderUsername, String? receiverUsername}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends/respond'),
            headers: _headers,
            body: jsonEncode({
              'requestId': requestId,
              'status': status,
              'senderUsername': senderUsername,
              'receiverUsername': receiverUsername,
            }),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Friends: Cancel Request
  Future<bool> cancelFriendRequest(String senderUsername, String receiverUsername) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends/cancel'),
            headers: _headers,
            body: jsonEncode({
              'senderUsername': senderUsername,
              'receiverUsername': receiverUsername,
            }),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Friends: Unfriend
  Future<bool> unfriend(String user1, String user2) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends/unfriend'),
            headers: _headers,
            body: jsonEncode({
              'user1': user1,
              'user2': user2,
            }),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // Auth: Login
  Future<User?> login(String usernameOrEmail, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers,
            body: jsonEncode({
              'usernameOrEmail': usernameOrEmail.trim(),
              'email': usernameOrEmail.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await setAuthToken(data['token']);
        }
        _isServerReachable = true;
        _hasCheckedReachability = true;
        return User.fromJson(data['user']);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Invalid username/email or password');
      }
    } on Exception {
      rethrow;
    } catch (_) {}

    return null;
  }

  // Auth: Register
  Future<User?> register({
    required String name,
    String? username,
    required String email,
    required String password,
    String? campusOrCity,
    String? majorOrBio,
  }) async {
    final cleanUsername = (username ?? (email.contains('@') ? email.split('@').first : 'user'))
        .trim().toLowerCase().replaceAll('@', '');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'username': cleanUsername,
              'email': email.trim().toLowerCase(),
              'password': password,
              'campusOrCity': campusOrCity,
              'majorOrBio': majorOrBio,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await setAuthToken(data['token']);
        }
        _isServerReachable = true;
        _hasCheckedReachability = true;
        return User.fromJson(data['user']);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Registration failed.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Connection error during registration: $e');
    }
  }

  // Friends: Get Requests
  Future<List<Map<String, dynamic>>> getFriendRequests(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/friends/requests/$clean'), headers: _headers)
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['requests'] != null) {
          return List<Map<String, dynamic>>.from(data['requests']);
        }
      }
    } catch (_) {}
    return [];
  }

  // Friends: Get Friends list
  Future<List<User>> getFriends(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/friends/$clean'), headers: _headers)
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['friends'] != null) {
          return (data['friends'] as List).map((j) => User.fromJson(j)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Communities: Get All
  Future<List<Community>> getCommunities({String? userIdentifier}) async {
    try {
      final clean = (userIdentifier ?? '').trim().toLowerCase().replaceAll('@', '');
      final uri = Uri.parse('$baseUrl/communities').replace(
        queryParameters: clean.isNotEmpty ? {'username': clean, 'userId': clean} : null,
      );
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        _isServerReachable = true;
        _hasCheckedReachability = true;
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((json) => Community.fromJson(json)).toList();
      }
    } catch (_) {}

    return LocalStoreService().getCommunities();
  }

  // Communities: Toggle Join
  Future<Community?> toggleJoinCommunity(String communityId, {required String userIdentifier}) async {
    try {
      final clean = userIdentifier.trim().toLowerCase().replaceAll('@', '');
      final res = await http
          .post(
            Uri.parse('$baseUrl/communities/$communityId/join'),
            headers: _headers,
            body: jsonEncode({
              'userId': clean,
              'username': clean,
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          return Community.fromJson(data['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  // Communities: Create
  Future<Community?> createCommunity(Community community) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/communities'),
            headers: _headers,
            body: jsonEncode({
              'id': community.id,
              'name': community.name,
              'description': community.description,
              'regionId': community.regionId,
              'regionName': community.regionName,
              'locationSpot': community.locationSpot,
              'creatorId': community.creatorId,
              'category': community.category,
              'iconEmoji': community.iconEmoji,
              'bannerColorHex': community.bannerColorHex,
              'rules': community.rules,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Community.fromJson(data['data']);
      }
    } catch (_) {}
    return null;
  }

  // Communities: Delete
  Future<bool> deleteCommunity(String communityId, String userId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/communities/$communityId'),
            headers: _headers,
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // Questions: Get All
  Future<List<Question>> getQuestions({String? communityId, String? tag, String? search}) async {
    if (_hasCheckedReachability && _isServerReachable) {
      try {
        final uri = Uri.parse('$baseUrl/questions').replace(queryParameters: {
          if (communityId != null) 'communityId': communityId,
          if (tag != null && tag != 'All') 'tag': tag,
          if (search != null && search.isNotEmpty) 'search': search,
        });

        final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['data'] as List<dynamic>;
          if (list.isNotEmpty) {
            return list.map((json) => Question.fromJson(json)).toList();
          }
        }
      } catch (_) {
        _isServerReachable = false;
      }
    }

    return LocalStoreService().getQuestions(communityId: communityId, tag: tag, search: search);
  }

  // Questions: Create
  Future<Question?> createQuestion({
    required String title,
    required String content,
    required String communityId,
    required String communityName,
    required String regionId,
    required String regionName,
    required User user,
    required bool isAnonymous,
    required List<String> tags,
  }) async {
    final localQuestion = Question(
      id: MockDataService.generateId(),
      title: title,
      content: content,
      communityId: communityId,
      communityName: communityName,
      regionId: regionId,
      regionName: regionName,
      authorId: user.id,
      authorName: isAnonymous ? 'Anonymous' : user.name,
      authorAvatar: isAnonymous ? null : user.avatarUrl,
      isAnonymous: isAnonymous,
      tags: tags,
      upvotes: 1,
      views: 1,
      createdAt: DateTime.now(),
      isUpvotedByMe: true,
    );

    // Save locally first for guaranteed permanence
    LocalStoreService().addQuestion(localQuestion);

    if (_hasCheckedReachability && _isServerReachable) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/questions'),
              headers: _headers,
              body: jsonEncode({
                'title': title,
                'content': content,
                'communityId': communityId,
                'communityName': communityName,
                'regionId': regionId,
                'regionName': regionName,
                'authorId': user.id,
                'authorName': user.name,
                'isAnonymous': isAnonymous,
                'tags': tags,
              }),
            )
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final serverQuestion = Question.fromJson(data['data']);
          LocalStoreService().updateQuestion(serverQuestion);
          return serverQuestion;
        }
      } catch (_) {
        _isServerReachable = false;
      }
    }

    return localQuestion;
  }

  // Questions: Upvote
  Future<void> toggleUpvote(String questionId) async {
    LocalStoreService().toggleUpvote(questionId);

    if (_hasCheckedReachability && _isServerReachable) {
      try {
        await http
            .post(Uri.parse('$baseUrl/questions/$questionId/upvote'), headers: _headers)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  // Questions: Add Reply
  Future<Reply?> addReply({
    required String questionId,
    required String content,
    required User user,
    required bool isAnonymous,
  }) async {
    final localReply = Reply(
      id: MockDataService.generateId(),
      questionId: questionId,
      authorId: user.id,
      authorName: isAnonymous ? 'Anonymous' : user.name,
      authorAvatar: isAnonymous ? null : user.avatarUrl,
      isAnonymous: isAnonymous,
      content: content,
      createdAt: DateTime.now(),
      upvotes: 0,
      isUpvotedByMe: false,
    );

    LocalStoreService().addReply(questionId, localReply);

    if (_hasCheckedReachability && _isServerReachable) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/questions/$questionId/replies'),
              headers: _headers,
              body: jsonEncode({
                'content': content,
                'authorId': user.id,
                'authorName': user.name,
                'isAnonymous': isAnonymous,
              }),
            )
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return Reply.fromJson(data['data']);
        }
      } catch (_) {
        _isServerReachable = false;
      }
    }

    return localReply;
  }

  // Chat: Get Rooms
  Future<List<ChatRoom>> getChatRooms() async {
    if (_hasCheckedReachability && _isServerReachable) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/chat/rooms'), headers: _headers)
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['data'] as List<dynamic>;
          if (list.isNotEmpty) {
            return list.map((json) => ChatRoom.fromJson(json)).toList();
          }
        }
      } catch (_) {
        _isServerReachable = false;
      }
    }

    return LocalStoreService().getChatRooms();
  }

  // Chat: Get Messages
  Future<List<ChatMessage>> getMessages(String roomId) async {
    if (_hasCheckedReachability && _isServerReachable) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/chat/rooms/$roomId/messages'), headers: _headers)
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['data'] as List<dynamic>;
          return list.map((json) => ChatMessage.fromJson(json)).toList();
        }
      } catch (_) {
        _isServerReachable = false;
      }
    }

    return LocalStoreService().getMessages(roomId);
  }
}
