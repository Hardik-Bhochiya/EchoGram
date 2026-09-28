import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import '../services/auth_service.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/socket_service.dart';
import '../services/friendship_service.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isGuest = false;
  bool _isLoading = false;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.unauthenticated;
  StreamSubscription? _authSub;
  StreamSubscription? _frReceivedSub;
  StreamSubscription? _frAcceptedSub;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;

  AuthProvider() {
    _knownUsers = [];
    _setupSocketListeners();
    _initAuthListener();
  }

  void _initAuthListener() {
    // 1. If real Firebase configuration is present, listen to Firebase Auth
    if (_authService.hasValidFirebaseConfig) {
      _authSub = _authService.authStateChanges.listen((fbUser) async {
        if (fbUser != null) {
          try {
            final profile = await _authService.getUserProfile(fbUser.uid);
            if (profile != null) {
              _currentUser = profile;
              _isAuthenticated = true;
              _isGuest = false;
              _status = AuthStatus.authenticated;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_user', jsonEncode(profile.toJson()));
              notifyListeners();
              return;
            }
          } catch (_) {}
        }
      });
    }

    // 2. Restore cached session from SharedPreferences
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('saved_user');
      if (userJson != null) {
        _currentUser = User.fromJson(jsonDecode(userJson));
        _isAuthenticated = true;
        _isGuest = false;
        _status = AuthStatus.authenticated;
        SocketService().joinUser(_currentUser!.id, _currentUser!.username);
        syncFriendData();
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<User> _knownUsers = [];
  List<User> get knownUsers => List.unmodifiable(_knownUsers);

  void setKnownUsers(List<User> users) {
    _knownUsers = users;
    notifyListeners();
  }

  User? findUserByUsername(String query) {
    final clean = query.trim().toLowerCase().replaceAll('@', '');
    try {
      return _knownUsers.firstWhere((u) => u.username.toLowerCase() == clean);
    } catch (_) {
      return null;
    }
  }

  /// Check username availability against Firestore or Backend
  Future<bool> checkUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;

    if (_authService.hasValidFirebaseConfig) {
      return await _authService.checkUsernameAvailable(clean);
    }
    return await ApiService().checkUsernameAvailable(clean);
  }

  /// Legacy synchronous helper for backward compatibility
  bool isUsernameAvailable(String username) {
    final sanitized = username.trim().toLowerCase().replaceAll('@', '');
    return sanitized.length >= 3;
  }

  /// Smart Multi-Backend Login (Firebase -> Node.js/MongoDB -> Demo Profile)
  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      User? user;
      String? lastAuthError;

      // 1. Try Firebase Auth FIRST (Cloud Firestore + Firebase Auth)
      if (_authService.hasValidFirebaseConfig) {
        try {
          user = await _authService.login(usernameOrEmail, password);
        } catch (e) {
          final msg = e.toString().replaceFirst('Exception: ', '');
          debugPrint('Firebase login notice: $msg');
          if (msg.contains('wrong-password') ||
              msg.contains('user-not-found') ||
              msg.contains('invalid-credential') ||
              msg.contains('too-many-requests') ||
              msg.contains('configuration-not-found') ||
              msg.contains('Firebase Authentication is not activated')) {
            throw Exception(msg);
          }
          lastAuthError = msg;
        }
      }

      // 2. Fallback: Try Backend API
      if (user == null) {
        try {
          user = await ApiService().login(usernameOrEmail, password);
        } catch (e) {
          lastAuthError ??= e.toString().replaceFirst('Exception: ', '');
          debugPrint('ApiService login notice: $e');
        }
      }

      // 3. Session recovery for known registered local users
      if (user == null && lastAuthError == null) {
        final clean = usernameOrEmail.trim().toLowerCase().replaceAll('@', '');
        final matches = _knownUsers.where(
          (u) => u.username.toLowerCase() == clean || u.email.toLowerCase() == clean,
        );

        if (matches.isNotEmpty) {
          user = matches.first;
        }
      }

      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        _isGuest = false;
        _status = AuthStatus.authenticated;
        _isLoading = false;

        LocalStoreService().saveUser(user);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user', jsonEncode(user.toJson()));

        SocketService().joinUser(user.id, user.username);
        syncFriendData();

        notifyListeners();
        return true;
      }

      throw Exception(lastAuthError ?? 'Invalid email/username or password.');
    } catch (e) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Smart Multi-Backend Register (Firebase -> Node.js/MongoDB -> Local Record)
  Future<bool> register({
    required String name,
    required String username,
    String? firstName,
    String? lastName,
    required String email,
    required String password,
    String? campusOrCity,
    String? campus,
    String? majorOrBio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _status = AuthStatus.authenticating;
    notifyListeners();

    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');

    // 0. Pre-validate username uniqueness against local cache
    if (LocalStoreService().isUsernameTaken(cleanUsername)) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      _errorMessage = "Username '@$cleanUsername' is already taken. Please choose another username.";
      notifyListeners();
      return false;
    }

    try {
      User? user;

      // 1. Try Firebase Auth (if valid project configured)
      if (_authService.hasValidFirebaseConfig) {
        try {
          user = await _authService.register(
            name: name,
            username: cleanUsername,
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            campusOrCity: campusOrCity ?? campus,
            majorOrBio: majorOrBio,
          );
        } catch (e) {
          final errStr = e.toString().replaceFirst('Exception: ', '');
          debugPrint('Firebase register notice: $e');

          // If it's a user input issue (email exists, weak password, invalid format), report it
          if (errStr.contains('already registered') ||
              errStr.contains('already taken') ||
              errStr.contains('too weak') ||
              errStr.contains('invalid')) {
            rethrow;
          }
        }
      }

      // 2. Try Node.js + Express + MongoDB Backend API
      if (user == null) {
        try {
          user = await ApiService().register(
            name: name,
            username: cleanUsername,
            email: email,
            password: password,
            campusOrCity: campusOrCity ?? campus,
            majorOrBio: majorOrBio,
          );
        } catch (e) {
          final errStr = e.toString().replaceFirst('Exception: ', '');
          if (errStr.contains('already taken') || errStr.contains('already exists')) {
            _isLoading = false;
            _status = AuthStatus.unauthenticated;
            _errorMessage = errStr;
            notifyListeners();
            return false;
          }
          debugPrint('ApiService register notice: $e');
        }
      }

      // 3. Fallback: Initialize local profile
      if (user == null) {
        final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
        final parts = name.trim().split(' ');
        final resolvedFirst = firstName ?? (parts.isNotEmpty ? parts.first : 'User');
        final resolvedLast = lastName ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
        final city = campusOrCity ?? campus ?? 'DDU, Nadiad';

        user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: cleanUsername,
          name: name.trim(),
          firstName: resolvedFirst,
          lastName: resolvedLast,
          email: email.trim(),
          campusOrCity: city,
          majorOrBio: majorOrBio ?? 'NearTalk Member',
          reputation: 50,
          joinedCommunityIds: const [],
          badges: const ['Newcomer'],
          isCollegeVerified: email.contains('ddu.ac.in') || email.contains('edu'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      _currentUser = user;
      _isAuthenticated = true;
      _isGuest = false;
      _status = AuthStatus.authenticated;
      _isLoading = false;

      LocalStoreService().saveUser(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user', jsonEncode(user.toJson()));

      SocketService().joinUser(user.id, user.username);
      syncFriendData();

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String username,
    String? firstName,
    String? lastName,
    required String email,
    required String password,
    String? campusOrCity,
    String? campus,
    String? majorOrBio,
  }) => register(
        name: name,
        username: username,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        campusOrCity: campusOrCity,
        campus: campus,
        majorOrBio: majorOrBio,
      );

  Future<void> updateProfile({
    required String name,
    required String campusOrCity,
    required String majorOrBio,
    String? avatarUrl,
  }) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        name: name,
        campusOrCity: campusOrCity,
        majorOrBio: majorOrBio,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      );

      try {
        await _authService.updateProfile(
          uid: _currentUser!.id,
          name: name,
          campusOrCity: campusOrCity,
          majorOrBio: majorOrBio,
          avatarUrl: avatarUrl,
        );
      } catch (_) {}

      LocalStoreService().saveUser(_currentUser!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user', jsonEncode(_currentUser!.toJson()));
      notifyListeners();
    }
  }

  Future<void> addPoints(int pts) async {
    if (_currentUser != null) {
      final newRep = _currentUser!.reputation + pts;
      _currentUser = _currentUser!.copyWith(reputation: newRep);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user', jsonEncode(_currentUser!.toJson()));
      notifyListeners();
    }
  }

  void continueAsGuest() {
    _currentUser = MockDataService.currentUser.copyWith(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest Explorer',
      username: 'guest',
      email: 'guest@neartalk.local',
    );
    _isAuthenticated = true;
    _isGuest = true;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    _isGuest = false;
    _status = AuthStatus.unauthenticated;
    try {
      await _authService.signOut();
    } catch (_) {}
    try {
      await ApiService().clearAuthToken();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user');
    notifyListeners();
  }

  // --- Friends & Friend Requests Methods for UI Compatibility ---

  String get _activeUsername => _currentUser?.username ?? 'user';

  List<User> getFriends() {
    if (_currentUser == null) return [];
    final friendUsernames = LocalStoreService().getFriendUsernames(_activeUsername);
    return friendUsernames.map((u) {
      final existing = _knownUsers.where((k) => k.username.toLowerCase() == u.toLowerCase());
      if (existing.isNotEmpty) return existing.first;
      return User(
        id: 'user_$u',
        name: u,
        username: u,
        email: '$u@neartalk.local',
        campusOrCity: 'Local',
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  bool areFriends(String username) {
    return LocalStoreService().areFriends(_activeUsername, username);
  }

  List<FriendRequest> getPendingIncomingRequests() {
    return LocalStoreService().getPendingIncomingRequests(_activeUsername);
  }

  List<FriendRequest> getPendingOutgoingRequests() {
    return LocalStoreService().getPendingOutgoingRequests(_activeUsername);
  }

  bool isPendingOutgoing(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    final outgoing = getPendingOutgoingRequests();
    return outgoing.any((r) => r.receiverUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending);
  }

  bool isPendingIncoming(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    final incoming = getPendingIncomingRequests();
    return incoming.any((r) => r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending);
  }

  FriendRequest? getIncomingRequestFrom(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    final incoming = getPendingIncomingRequests();
    try {
      return incoming.firstWhere((r) => r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending);
    } catch (_) {
      return null;
    }
  }

  void _setupSocketListeners() {
    _frReceivedSub?.cancel();
    _frAcceptedSub?.cancel();

    _frReceivedSub = SocketService().onFriendRequestReceived.listen((data) {
      try {
        final req = FriendRequest.fromJson(data);
        LocalStoreService().addFriendRequest(req);
        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] onFriendRequestReceived error: $e');
      }
    });

    _frAcceptedSub = SocketService().onFriendRequestAccepted.listen((data) {
      try {
        final reqId = data['requestId'] as String?;
        final sUser = data['senderUsername'] as String?;
        final rUser = data['receiverUsername'] as String?;
        if (reqId != null) {
          LocalStoreService().respondFriendRequest(reqId, 'accepted');
        }
        if (sUser != null && rUser != null) {
          LocalStoreService().addFriend(sUser, rUser);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] onFriendRequestAccepted error: $e');
      }
    });
  }

  Future<void> syncFriendData() async {
    if (_currentUser == null) return;
    try {
      final username = _currentUser!.username;
      final rawReqs = await ApiService().getFriendRequests(username);
      for (final r in rawReqs) {
        final req = FriendRequest.fromJson(r);
        LocalStoreService().addFriendRequest(req);
      }

      final friends = await ApiService().getFriends(username);
      for (final f in friends) {
        LocalStoreService().addFriend(username, f.username);
        if (!_knownUsers.any((u) => u.username.toLowerCase() == f.username.toLowerCase())) {
          _knownUsers.add(f);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] syncFriendData error: $e');
    }
  }

  Future<void> cancelFriendRequest(String targetUsername) async {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    LocalStoreService().cancelFriendRequest(_activeUsername, tUser);
    ApiService().cancelFriendRequest(_activeUsername, tUser);
    notifyListeners();
  }

  Future<bool> sendFriendRequest(String targetUsername) async {
    final senderName = _currentUser?.name ?? _currentUser?.username ?? 'User';
    final senderUname = _activeUsername;
    final currentUid = _currentUser?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final req = FriendRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUid,
      senderUsername: senderUname,
      senderName: senderName,
      senderAvatar: _currentUser?.avatarUrl,
      receiverId: 'target_$targetUsername',
      receiverUsername: targetUsername,
      receiverName: targetUsername,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    LocalStoreService().addFriendRequest(req);
    notifyListeners();

    // 1. Firestore Cloud Database write
    if (FriendshipService().isFirebaseInitialized && _currentUser != null) {
      try {
        final targetUser = findUserByUsername(targetUsername) ??
            User(
              id: 'target_$targetUsername',
              name: targetUsername,
              username: targetUsername,
              email: '$targetUsername@neartalk.local',
              campusOrCity: 'Campus',
              createdAt: DateTime.now(),
            );
        await FriendshipService().sendFriendRequest(_currentUser!, targetUser);
      } catch (e) {
        debugPrint('[AuthProvider] Firestore sendFriendRequest notice: $e');
      }
    }

    // 2. Also dispatch to API and WebSockets for local compatibility
    try {
      await ApiService().sendFriendRequest(
        senderId: currentUid,
        senderUsername: senderUname,
        senderName: senderName,
        receiverUsername: targetUsername,
        senderAvatar: _currentUser?.avatarUrl,
      );
      SocketService().sendFriendRequest(req.toJson());
    } catch (_) {}

    return true;
  }

  Future<void> respondFriendRequest(String requestId, String status, {String? senderUsername}) async {
    LocalStoreService().respondFriendRequest(requestId, status);
    notifyListeners();

    // 1. Firestore Cloud Database update
    if (FriendshipService().isFirebaseInitialized && _currentUser != null) {
      try {
        if (status == 'accepted') {
          final reqObj = LocalStoreService().getFriendRequests(_activeUsername).firstWhere(
            (r) => r.id == requestId,
            orElse: () => FriendRequest(
              id: requestId,
              senderId: senderUsername ?? 'sender',
              senderUsername: senderUsername ?? 'sender',
              senderName: senderUsername ?? 'sender',
              receiverId: _currentUser!.id,
              receiverUsername: _currentUser!.username,
              receiverName: _currentUser!.name,
              createdAt: DateTime.now(),
            ),
          );
          await FriendshipService().acceptFriendRequest(reqObj, _currentUser!);
        } else {
          await FriendshipService().declineFriendRequest(requestId);
        }
      } catch (e) {
        debugPrint('[AuthProvider] Firestore respondFriendRequest notice: $e');
      }
    }

    // 2. Also dispatch to API and WebSockets
    try {
      await ApiService().respondFriendRequest(
        requestId,
        status,
        senderUsername: senderUsername,
        receiverUsername: _activeUsername,
      );
      SocketService().respondFriendRequest(
        requestId: requestId,
        status: status,
        senderUsername: senderUsername ?? '',
        receiverUsername: _activeUsername,
      );
    } catch (_) {}
  }

  Future<void> unfriend(String targetUsername) async {
    if (_currentUser == null) return;
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    LocalStoreService().removeFriend(_currentUser!.username, tUser);
    ApiService().unfriend(_currentUser!.username, tUser);
    notifyListeners();
  }

  Future<void> removeFriend(String targetUsername) async {
    await unfriend(targetUsername);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _frReceivedSub?.cancel();
    _frAcceptedSub?.cancel();
    super.dispose();
  }
}
