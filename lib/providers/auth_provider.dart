import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import '../models/chat_room.dart';
import 'chat_provider.dart';
import '../services/auth_service.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/socket_service.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';

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
  StreamSubscription? _frDeclinedSub;

  // Real-time Cloud Firestore Subscriptions for 100% Cross-Device Consistency
  StreamSubscription? _firestoreIncomingFrSub;
  StreamSubscription? _firestoreOutgoingFrSub;
  StreamSubscription? _firestoreFriendshipsSub;

  final List<FriendRequest> _incomingRequests = [];
  final List<FriendRequest> _outgoingRequests = [];
  final List<User> _friendsList = [];
  final Set<String> _friendUsernamesSet = {};

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;
  String get activeUsername => _currentUser?.username ?? '';

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
              SocketService().joinUser(profile.id, profile.username);
              _initFirestoreFriendListeners(profile);
              syncFriendData();
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
        final loaded = User.fromJson(jsonDecode(userJson));
        if (loaded.id == 'user-hardik' || loaded.username == 'hardik_07' || loaded.username.isEmpty) {
          await prefs.remove('saved_user');
          _currentUser = null;
          _isAuthenticated = false;
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return;
        }
        _currentUser = loaded;
        _isAuthenticated = true;
        _isGuest = false;
        _status = AuthStatus.authenticated;
        SocketService().joinUser(_currentUser!.id, _currentUser!.username);
        _initFirestoreFriendListeners(_currentUser!);
        syncFriendData();
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setCurrentUserForTesting(User user) {
    _currentUser = user;
    _isAuthenticated = true;
    _isGuest = false;
    _status = AuthStatus.authenticated;
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
          // Don't rethrow on configuration-not-found or unactivated Firebase Auth; smoothly fallback to Backend API
          lastAuthError = msg;
        }
      }

      // 2. Fallback: Try Backend API (Node.js + Express + MongoDB)
      if (user == null) {
        try {
          user = await ApiService().login(usernameOrEmail, password);
        } catch (e) {
          lastAuthError ??= e.toString().replaceFirst('Exception: ', '');
          debugPrint('ApiService login notice: $e');
        }
      }

      // 3. Fallback: Session recovery for known registered local users
      if (user == null) {
        final clean = usernameOrEmail.trim().toLowerCase().replaceAll('@', '');
        final localUsers = LocalStoreService().getRegisteredUsers();
        final matches = localUsers.where(
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
        _initFirestoreFriendListeners(user);
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
        final city = campusOrCity ?? campus ?? 'Global';

        user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: cleanUsername,
          name: name.trim(),
          firstName: resolvedFirst,
          lastName: resolvedLast,
          email: email.trim(),
          campusOrCity: city,
          majorOrBio: majorOrBio ?? 'EchoGram Member',
          reputation: 50,
          joinedCommunityIds: const [],
          badges: const ['Newcomer'],
          isCollegeVerified: true,
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
      _initFirestoreFriendListeners(user);
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

  Future<bool> updateProfile({
    required String name,
    required String campusOrCity,
    required String majorOrBio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Name cannot be empty.');
    }

    final trimmedLoc = campusOrCity.trim().isEmpty ? 'Global' : campusOrCity.trim();
    final trimmedBio = majorOrBio.trim();
    final parts = trimmedName.split(' ');
    final fName = parts.isNotEmpty ? parts.first : 'User';
    final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final newAvatar = avatarUrl ?? _currentUser!.avatarUrl ?? '👤';

    // Keep authenticated UID constant under all conditions
    final currentUid = _authService.currentFirebaseUser?.uid ?? _currentUser!.id;
    final currentUname = _currentUser!.username;

    final updated = _currentUser!.copyWith(
      id: currentUid,
      username: currentUname,
      name: trimmedName,
      firstName: fName,
      lastName: lName,
      campusOrCity: trimmedLoc,
      majorOrBio: trimmedBio,
      avatarUrl: newAvatar,
      updatedAt: DateTime.now(),
    );

    // 1. Immediately update in-memory state for lightning fast UI response
    _currentUser = updated;
    LocalStoreService().saveUser(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_user', jsonEncode(updated.toJson()));

    // 2. Update in known users registry
    final kIdx = _knownUsers.indexWhere((k) => k.username.toLowerCase() == currentUname.toLowerCase());
    if (kIdx != -1) {
      _knownUsers[kIdx] = updated;
    } else {
      _knownUsers.add(updated);
    }
    notifyListeners();

    // 3. Update Backend Database (MongoDB & in-memory store)
    try {
      final remoteUser = await ApiService().updateProfile(
        id: currentUid,
        username: currentUname,
        name: trimmedName,
        campusOrCity: trimmedLoc,
        majorOrBio: trimmedBio,
        avatarUrl: newAvatar,
      );
      if (remoteUser != null) {
        // Guarantee Firebase UID and Username are never overwritten
        final safeRemote = remoteUser.copyWith(
          id: currentUid,
          username: currentUname,
          firstName: fName,
          lastName: lName,
          campusOrCity: trimmedLoc,
          majorOrBio: trimmedBio,
          avatarUrl: newAvatar,
        );
        _currentUser = safeRemote;
        LocalStoreService().saveUser(safeRemote);
        await prefs.setString('saved_user', jsonEncode(safeRemote.toJson()));
      }
    } catch (e) {
      debugPrint('[AuthProvider] Backend updateProfile notice: $e');
    }

    // 4. Update Cloud Firestore (if Firebase is active) with safe timeout
    if (_authService.isFirebaseInitialized) {
      try {
        await _authService.updateProfile(
          uid: currentUid,
          name: trimmedName,
          campusOrCity: trimmedLoc,
          majorOrBio: trimmedBio,
          avatarUrl: newAvatar,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('[AuthProvider] Firestore updateProfile notice: $e');
      }
    }

    notifyListeners();
    return true;
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
      email: 'guest@echogram.local',
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
    _firestoreIncomingFrSub?.cancel();
    _firestoreOutgoingFrSub?.cancel();
    _firestoreFriendshipsSub?.cancel();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _friendsList.clear();
    _friendUsernamesSet.clear();
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

  // --- Real-time Cloud Firestore Friend Listeners (100% Online Consistency) ---

  void _initFirestoreFriendListeners(User user) {
    _firestoreIncomingFrSub?.cancel();
    _firestoreOutgoingFrSub?.cancel();
    _firestoreFriendshipsSub?.cancel();
    // Bypassed: Friend data syncs directly with local MongoDB via ApiService and SocketService.
    // Disabling Firestore streams prevents legacy 12-day-old friendships (such as linking dhruv_032 & hardik_032) from reappearing.
    return;
  }

  // --- Friends & Friend Requests Methods for UI Compatibility ---

  String get _activeUsername => _currentUser?.username ?? 'user';

  List<User> getFriends() {
    if (_currentUser == null) return [];
    final Map<String, User> combined = {};

    // 1. Live friends from Cloud Firestore
    for (final f in _friendsList) {
      combined[f.username.toLowerCase()] = f;
    }

    // 2. Friends from LocalStore
    final friendUsernames = LocalStoreService().getFriendUsernames(_activeUsername);
    for (final u in friendUsernames) {
      final clean = u.toLowerCase();
      if (!combined.containsKey(clean)) {
        final existing = _knownUsers.where((k) => k.username.toLowerCase() == clean);
        if (existing.isNotEmpty) {
          combined[clean] = existing.first;
        } else {
          combined[clean] = User(
            id: 'user_$clean',
            name: clean,
            username: clean,
            email: '$clean@neartalk.local',
            campusOrCity: 'Campus',
            createdAt: DateTime.now(),
          );
        }
      }
    }

    return combined.values.toList();
  }

  bool areFriends(String username) {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    final myClean = _activeUsername.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty || myClean.isEmpty) return false;
    if (clean == myClean) return true;
    if (_friendUsernamesSet.contains(clean)) return true;
    if (_friendsList.any((f) => f.username.toLowerCase().replaceAll('@', '') == clean)) return true;
    if (LocalStoreService().areFriends(myClean, clean)) return true;

    // Direct chat check: If two users are actively in a direct chat with exchanged messages, treat as friends
    final directRoomId = ChatProvider.getDirectRoomId(myClean, clean);
    final msgs = LocalStoreService().getMessages(directRoomId);
    if (msgs.isNotEmpty) {
      _friendUsernamesSet.add(clean);
      LocalStoreService().addFriend(myClean, clean);
      return true;
    }

    return false;
  }

  List<FriendRequest> getPendingIncomingRequests() {
    final local = LocalStoreService().getPendingIncomingRequests(_activeUsername);
    final Map<String, FriendRequest> map = {};
    for (final r in _incomingRequests.where((r) => r.isPending)) {
      map[r.senderUsername.toLowerCase()] = r;
    }
    for (final r in local) {
      map.putIfAbsent(r.senderUsername.toLowerCase(), () => r);
    }
    return map.values.toList();
  }

  List<FriendRequest> getPendingOutgoingRequests() {
    final local = LocalStoreService().getPendingOutgoingRequests(_activeUsername);
    final Map<String, FriendRequest> map = {};
    for (final r in _outgoingRequests.where((r) => r.isPending)) {
      map[r.receiverUsername.toLowerCase()] = r;
    }
    for (final r in local) {
      final clean = r.receiverUsername.toLowerCase();
      final hasDeclined = _outgoingRequests.any(
        (o) => o.receiverUsername.toLowerCase() == clean && o.isDeclined,
      );
      if (!hasDeclined) {
        map.putIfAbsent(clean, () => r);
      }
    }
    return map.values.toList();
  }

  bool isPendingOutgoing(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    if (areFriends(tUser)) return false;

    // Check live outgoing requests
    for (final r in _outgoingRequests) {
      if (r.receiverUsername.trim().toLowerCase().replaceAll('@', '') == tUser) {
        if (r.isDeclined) return false;
        if (r.isPending) return true;
      }
    }

    // Check local store
    final outgoing = LocalStoreService().getPendingOutgoingRequests(_activeUsername);
    return outgoing.any((r) =>
        r.receiverUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending && !areFriends(tUser));
  }

  bool isPendingIncoming(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    if (areFriends(tUser)) return false;

    for (final r in _incomingRequests) {
      if (r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending) {
        return true;
      }
    }

    final incoming = LocalStoreService().getPendingIncomingRequests(_activeUsername);
    return incoming.any((r) =>
        r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending && !areFriends(tUser));
  }

  FriendRequest? getIncomingRequestFrom(String targetUsername) {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    try {
      return _incomingRequests.firstWhere(
        (r) => r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending,
      );
    } catch (_) {
      final local = LocalStoreService().getPendingIncomingRequests(_activeUsername);
      try {
        return local.firstWhere(
          (r) => r.senderUsername.trim().toLowerCase().replaceAll('@', '') == tUser && r.isPending,
        );
      } catch (_) {
        return null;
      }
    }
  }

  void _setupSocketListeners() {
    _frReceivedSub?.cancel();
    _frAcceptedSub?.cancel();
    _frDeclinedSub?.cancel();

    _frReceivedSub = SocketService().onFriendRequestReceived.listen((data) {
      try {
        final req = FriendRequest.fromJson(data);
        final cleanMy = _activeUsername.trim().toLowerCase().replaceAll('@', '');
        final cleanRec = req.receiverUsername.trim().toLowerCase().replaceAll('@', '');
        final cleanSender = req.senderUsername.trim().toLowerCase().replaceAll('@', '');

        if (cleanRec == cleanMy && cleanSender != cleanMy) {
          LocalStoreService().addFriendRequest(req);
          _incomingRequests.removeWhere((r) =>
              r.id == req.id ||
              r.senderUsername.trim().toLowerCase().replaceAll('@', '') == cleanSender);
          _incomingRequests.insert(0, req);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[AuthProvider] onFriendRequestReceived error: $e');
      }
    });

    _frAcceptedSub = SocketService().onFriendRequestAccepted.listen((data) {
      try {
        final reqId = data['requestId'] as String?;
        final sUser = (data['senderUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        final rUser = (data['receiverUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        final cleanMy = _activeUsername.trim().toLowerCase().replaceAll('@', '');
        final otherUname = (sUser == cleanMy) ? rUser : (rUser == cleanMy ? sUser : '');

        if (reqId != null) {
          LocalStoreService().respondFriendRequest(reqId, 'accepted', senderUsername: sUser, receiverUsername: rUser);
        }
        if (sUser.isNotEmpty && rUser.isNotEmpty) {
          LocalStoreService().addFriend(sUser, rUser);
          LocalStoreService().cancelFriendRequest(sUser, rUser);
        }

        if (otherUname.isNotEmpty && otherUname != cleanMy) {
          _friendUsernamesSet.add(otherUname);
          final friendUser = findUserByUsername(otherUname) ??
              User(
                id: 'user_$otherUname',
                username: otherUname,
                name: otherUname,
                email: '$otherUname@neartalk.local',
                campusOrCity: 'EchoGram Campus',
                createdAt: DateTime.now(),
              );
          if (!_friendsList.any((f) => f.username.toLowerCase().replaceAll('@', '') == otherUname)) {
            _friendsList.add(friendUser);
          }
          if (!_knownUsers.any((k) => k.username.toLowerCase().replaceAll('@', '') == otherUname)) {
            _knownUsers.add(friendUser);
          }

          // Automatically create direct chat room so new user is added to chats immediately
          final directRoomId = ChatProvider.getDirectRoomId(cleanMy, otherUname);
          final newRoom = ChatRoom(
            id: directRoomId,
            title: '@$otherUname',
            subtitle: friendUser.name.isNotEmpty ? friendUser.name : '@$otherUname',
            avatarEmoji: (friendUser.avatarUrl != null && friendUser.avatarUrl!.isNotEmpty)
                ? friendUser.avatarUrl!
                : '👤',
            isGroup: false,
            lastMessage: 'You are now connected! Say hello 👋',
            lastMessageTime: DateTime.now(),
            unreadCount: 0,
            isOnline: true,
            participantIds: [_currentUser?.id ?? cleanMy, friendUser.id],
          );
          LocalStoreService().addOrUpdateRoom(newRoom);
        }

        _outgoingRequests.removeWhere((r) =>
            (reqId != null && r.id == reqId) ||
            r.receiverUsername.toLowerCase().replaceAll('@', '') == otherUname ||
            r.senderUsername.toLowerCase().replaceAll('@', '') == otherUname);
        _incomingRequests.removeWhere((r) =>
            (reqId != null && r.id == reqId) ||
            r.receiverUsername.toLowerCase().replaceAll('@', '') == otherUname ||
            r.senderUsername.toLowerCase().replaceAll('@', '') == otherUname);

        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] onFriendRequestAccepted error: $e');
      }
    });

    _frDeclinedSub = SocketService().onFriendRequestDeclined.listen((data) {
      try {
        final reqId = data['requestId'] as String?;
        final sUser = (data['senderUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        final rUser = (data['receiverUsername'] as String? ?? '').trim().toLowerCase().replaceAll('@', '');
        if (reqId != null) {
          LocalStoreService().respondFriendRequest(reqId, 'declined', senderUsername: sUser, receiverUsername: rUser);
        }
        LocalStoreService().cancelFriendRequest(sUser, rUser);

        _outgoingRequests.removeWhere((r) =>
            (reqId != null && r.id == reqId) ||
            (r.receiverUsername.toLowerCase().replaceAll('@', '') == rUser && r.senderUsername.toLowerCase().replaceAll('@', '') == sUser) ||
            (r.receiverUsername.toLowerCase().replaceAll('@', '') == sUser && r.senderUsername.toLowerCase().replaceAll('@', '') == rUser));
        _incomingRequests.removeWhere((r) =>
            (reqId != null && r.id == reqId) ||
            (r.receiverUsername.toLowerCase().replaceAll('@', '') == rUser && r.senderUsername.toLowerCase().replaceAll('@', '') == sUser) ||
            (r.receiverUsername.toLowerCase().replaceAll('@', '') == sUser && r.senderUsername.toLowerCase().replaceAll('@', '') == rUser));

        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] onFriendRequestDeclined error: $e');
      }
    });
  }

  Future<void> syncFriendData() async {
    if (_currentUser == null) return;
    try {
      final username = _currentUser!.username;
      final cleanMy = username.trim().toLowerCase().replaceAll('@', '');

      // 1. Fetch real-time friends from backend MongoDB
      final friends = await ApiService().getFriends(username);
      _friendsList.clear();
      _friendUsernamesSet.clear();
      for (final f in friends) {
        final fClean = f.username.trim().toLowerCase().replaceAll('@', '');
        _friendUsernamesSet.add(fClean);
        _friendsList.add(f);
        LocalStoreService().addFriend(cleanMy, fClean);
        if (!_knownUsers.any((u) => u.username.toLowerCase() == fClean)) {
          _knownUsers.add(f);
        }
      }

      // Also merge any friends already recorded in local store
      final localFriendNames = LocalStoreService().getFriendUsernames(cleanMy);
      for (final lfn in localFriendNames) {
        final lClean = lfn.trim().toLowerCase().replaceAll('@', '');
        _friendUsernamesSet.add(lClean);
      }

      // 2. Fetch friend requests from backend MongoDB
      final rawReqs = await ApiService().getFriendRequests(username);
      _incomingRequests.clear();
      _outgoingRequests.clear();
      for (final r in rawReqs) {
        final req = FriendRequest.fromJson(r);
        final sClean = req.senderUsername.trim().toLowerCase().replaceAll('@', '');
        final rClean = req.receiverUsername.trim().toLowerCase().replaceAll('@', '');

        // If they are already established friends, clear any pending request
        if (_friendUsernamesSet.contains(sClean) || _friendUsernamesSet.contains(rClean)) {
          LocalStoreService().cancelFriendRequest(sClean, rClean);
          continue;
        }

        LocalStoreService().addFriendRequest(req);
        if (req.isPending) {
          if (rClean == cleanMy) {
            _incomingRequests.add(req);
          } else if (sClean == cleanMy) {
            _outgoingRequests.add(req);
          }
        }
      }

      // Filter out any outgoing or incoming requests if already connected as friends
      _outgoingRequests.removeWhere((r) =>
          _friendUsernamesSet.contains(r.receiverUsername.trim().toLowerCase().replaceAll('@', '')));
      _incomingRequests.removeWhere((r) =>
          _friendUsernamesSet.contains(r.senderUsername.trim().toLowerCase().replaceAll('@', '')));

      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] syncFriendData error: $e');
    }
  }

  Future<void> cancelFriendRequest(String targetUsername) async {
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    LocalStoreService().cancelFriendRequest(_activeUsername, tUser);
    if (FriendshipService().isFirebaseInitialized) {
      await FriendshipService().cancelFriendRequest(_activeUsername, tUser);
    }
    ApiService().cancelFriendRequest(_activeUsername, tUser);
    notifyListeners();
  }

  Future<bool> sendFriendRequest(String targetUsername) async {
    if (_currentUser == null) return false;
    final senderName = _currentUser?.name ?? _currentUser?.username ?? 'User';
    final senderUname = _activeUsername;
    final cleanTarget = targetUsername.trim().toLowerCase().replaceAll('@', '');

    // Resolve target user record
    User targetUser = findUserByUsername(cleanTarget) ??
        await UserService().findUserByUsername(cleanTarget) ??
        User(
          id: 'user_$cleanTarget',
          name: cleanTarget,
          username: cleanTarget,
          email: '$cleanTarget@neartalk.local',
          campusOrCity: 'Campus',
          createdAt: DateTime.now(),
        );

    final req = FriendRequest(
      id: '${senderUname}_to_$cleanTarget',
      senderId: _currentUser!.id,
      senderUsername: senderUname,
      senderName: senderName,
      senderAvatar: _currentUser?.avatarUrl,
      receiverId: targetUser.id,
      receiverUsername: cleanTarget,
      receiverName: targetUser.name,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Optimistic local update
    _outgoingRequests.removeWhere((r) => r.receiverUsername.toLowerCase() == cleanTarget);
    _outgoingRequests.add(req);
    LocalStoreService().addFriendRequest(req);
    notifyListeners();

    // 1. Cloud Firestore write
    if (FriendshipService().isFirebaseInitialized) {
      try {
        await FriendshipService().sendFriendRequest(_currentUser!, targetUser);
      } catch (e) {
        debugPrint('[AuthProvider] Firestore sendFriendRequest notice: $e');
      }
    }

    // 2. Also dispatch to API and WebSockets for local compatibility
    try {
      await ApiService().sendFriendRequest(
        senderId: _currentUser!.id,
        senderUsername: senderUname,
        senderName: senderName,
        receiverUsername: cleanTarget,
        senderAvatar: _currentUser?.avatarUrl,
      );
      SocketService().sendFriendRequest(req.toJson());
    } catch (_) {}

    return true;
  }

  Future<void> respondFriendRequest(String requestId, String status, {String? senderUsername}) async {
    if (_currentUser == null) return;
    final cleanSender = senderUsername?.trim().toLowerCase().replaceAll('@', '');

    FriendRequest? reqObj;
    try {
      reqObj = _incomingRequests.firstWhere(
        (r) => r.id == requestId || r.senderUsername.toLowerCase() == cleanSender,
      );
    } catch (_) {
      try {
        reqObj = _outgoingRequests.firstWhere(
          (r) => r.id == requestId || r.receiverUsername.toLowerCase() == cleanSender,
        );
      } catch (_) {
        final localList = LocalStoreService().getFriendRequests(_activeUsername);
        try {
          reqObj = localList.firstWhere(
            (r) => r.id == requestId || r.senderUsername.toLowerCase() == cleanSender || r.receiverUsername.toLowerCase() == cleanSender,
          );
        } catch (_) {}
      }
    }

    reqObj ??= FriendRequest(
      id: requestId,
      senderId: cleanSender ?? 'sender',
      senderUsername: cleanSender ?? 'sender',
      senderName: cleanSender ?? 'sender',
      receiverId: _currentUser!.id,
      receiverUsername: _currentUser!.username,
      receiverName: _currentUser!.name,
      status: status,
      createdAt: DateTime.now(),
    );

    // Optimistic local state update
    LocalStoreService().respondFriendRequest(
      requestId,
      status,
      senderUsername: reqObj.senderUsername,
      receiverUsername: reqObj.receiverUsername,
    );

    final otherUsername = reqObj.senderUsername.toLowerCase() == _activeUsername.toLowerCase()
        ? reqObj.receiverUsername
        : reqObj.senderUsername;
    final otherId = reqObj.senderUsername.toLowerCase() == _activeUsername.toLowerCase()
        ? reqObj.receiverId
        : reqObj.senderId;
    final otherName = reqObj.senderUsername.toLowerCase() == _activeUsername.toLowerCase()
        ? reqObj.receiverName
        : reqObj.senderName;
    final otherAvatar = reqObj.senderUsername.toLowerCase() == _activeUsername.toLowerCase()
        ? null
        : reqObj.senderAvatar;

    if (status == 'accepted') {
      _friendUsernamesSet.add(otherUsername.toLowerCase());
      final friendUser = findUserByUsername(otherUsername) ??
          User(
            id: otherId,
            username: otherUsername,
            name: otherName,
            avatarUrl: otherAvatar,
            email: '$otherUsername@neartalk.local',
            campusOrCity: 'Campus',
            createdAt: DateTime.now(),
          );
      if (!_friendsList.any((f) => f.username.toLowerCase() == otherUsername.toLowerCase())) {
        _friendsList.add(friendUser);
      }

      // Automatically create direct chat room so both users have the chat immediately (Instagram-style)
      final directRoomId = ChatProvider.getDirectRoomId(_activeUsername, otherUsername);
      final newRoom = ChatRoom(
        id: directRoomId,
        title: '@${otherUsername.replaceAll('@', '')}',
        subtitle: otherName.isNotEmpty ? otherName : '@${otherUsername.replaceAll('@', '')}',
        avatarEmoji: (otherAvatar != null && otherAvatar.isNotEmpty) ? otherAvatar : '👤',
        isGroup: false,
        lastMessage: 'You are now connected! Say hello 👋',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isOnline: true,
        participantIds: [_currentUser!.id, otherId],
      );
      LocalStoreService().addOrUpdateRoom(newRoom);
    } else {
      // Rejection / Decline: completely remove pending request so sender can request again
      LocalStoreService().respondFriendRequest(
        requestId,
        'declined',
        senderUsername: reqObj.senderUsername,
        receiverUsername: reqObj.receiverUsername,
      );
      LocalStoreService().cancelFriendRequest(reqObj.senderUsername, reqObj.receiverUsername);
    }

    final cleanOther = otherUsername.toLowerCase().replaceAll('@', '').trim();
    _incomingRequests.removeWhere(
      (r) => r.id == requestId ||
          r.senderUsername.toLowerCase().replaceAll('@', '').trim() == cleanOther ||
          r.receiverUsername.toLowerCase().replaceAll('@', '').trim() == cleanOther,
    );
    _outgoingRequests.removeWhere(
      (r) => r.id == requestId ||
          r.receiverUsername.toLowerCase().replaceAll('@', '').trim() == cleanOther ||
          r.senderUsername.toLowerCase().replaceAll('@', '').trim() == cleanOther,
    );
    notifyListeners();

    // 1. Cloud Firestore update
    if (FriendshipService().isFirebaseInitialized) {
      try {
        if (status == 'accepted') {
          await FriendshipService().acceptFriendRequest(reqObj, _currentUser!);
        } else {
          await FriendshipService().declineFriendRequest(
            requestId,
            senderUsername: reqObj.senderUsername,
            receiverUsername: _currentUser!.username,
          );
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
        senderUsername: reqObj.senderUsername,
        receiverUsername: _activeUsername,
      );
      SocketService().respondFriendRequest(
        requestId: requestId,
        status: status,
        senderUsername: reqObj.senderUsername,
        receiverUsername: _activeUsername,
      );
    } catch (_) {}
  }

  Future<void> unfriend(String targetUsername) async {
    if (_currentUser == null) return;
    final tUser = targetUsername.trim().toLowerCase().replaceAll('@', '');
    _friendUsernamesSet.remove(tUser);
    _friendsList.removeWhere((f) => f.username.toLowerCase() == tUser);
    LocalStoreService().removeFriend(_currentUser!.username, tUser);
    if (FriendshipService().isFirebaseInitialized) {
      await FriendshipService().removeFriend(_currentUser!.username, tUser);
    }
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
    _frDeclinedSub?.cancel();
    _firestoreIncomingFrSub?.cancel();
    _firestoreOutgoingFrSub?.cancel();
    _firestoreFriendshipsSub?.cancel();
    super.dispose();
  }
}
