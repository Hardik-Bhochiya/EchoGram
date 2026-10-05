import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'local_store_service.dart';
import 'api_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Unified search prioritizing Cloud Firestore with local cache
  Future<List<User>> searchUsers(String query, {String? currentUserId, String? currentUsername}) async {
    final clean = query.trim().replaceFirst(RegExp(r'^@'), '').trim();
    if (clean.isEmpty) return [];

    final cleanCurrentUname = (currentUsername ?? '').trim().toLowerCase().replaceAll('@', '');
    bool isSelf(User u) {
      if (currentUserId != null && currentUserId.isNotEmpty && u.id == currentUserId) return true;
      final uUname = u.username.trim().toLowerCase().replaceAll('@', '');
      if (cleanCurrentUname.isNotEmpty && uUname == cleanCurrentUname) return true;
      if (cleanCurrentUname.isNotEmpty && u.id == 'user_$cleanCurrentUname') return true;
      return false;
    }

    final Map<String, User> combined = {};

    // 1. Instant match from Local Registered Users
    final localResults = LocalStoreService().searchUsers(clean, excludeUserId: currentUserId);
    for (final u in localResults) {
      if (!isSelf(u)) combined[u.username.toLowerCase()] = u;
    }

    // 2. Primary: Query Cloud Firestore
    if (isFirebaseInitialized) {
      try {
        final cleanLower = clean.toLowerCase();
        final usernameSnap = await _firestore
            .collection('users')
            .where('normalizedUsername', isGreaterThanOrEqualTo: cleanLower)
            .where('normalizedUsername', isLessThanOrEqualTo: '$cleanLower\uf8ff')
            .limit(20)
            .get();

        for (final doc in usernameSnap.docs) {
          final u = User.fromFirestore(doc.data(), doc.id);
          if (!isSelf(u)) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Query MongoDB / Node.js Backend API if available
    try {
      if (ApiService().isServerReachable) {
        final apiResults = await ApiService().searchPeers(clean);
        for (final u in apiResults) {
          if (!isSelf(u)) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      }
    } catch (_) {}

    return combined.values.toList();
  }

  /// Get all registered users prioritizing Cloud Firestore and MongoDB backend, strictly excluding self
  Future<List<User>> getSuggestedUsers({String? currentUserId, String? currentUsername, int limit = 200}) async {
    final Map<String, User> combined = {};
    final cleanCurrentUname = (currentUsername ?? '').trim().toLowerCase().replaceAll('@', '');

    bool isSelf(User u) {
      if (currentUserId != null && currentUserId.isNotEmpty && u.id.trim().toLowerCase() == currentUserId.trim().toLowerCase()) return true;
      final uUname = u.username.trim().toLowerCase().replaceAll('@', '');
      if (cleanCurrentUname.isNotEmpty && uUname == cleanCurrentUname) return true;
      if (cleanCurrentUname.isNotEmpty && u.id == 'user_$cleanCurrentUname') return true;
      return false;
    }

    // 1. Local registered users
    final localUsers = LocalStoreService().getRegisteredUsers();
    for (final u in localUsers) {
      if (!isSelf(u)) {
        combined[u.username.toLowerCase()] = u;
      }
    }

    // 2. Query MongoDB backend users directly
    try {
      if (ApiService().isServerReachable) {
        final apiResults = await ApiService().searchPeers('');
        for (final u in apiResults) {
          if (!isSelf(u)) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      }
    } catch (_) {}

    // 3. Cloud Firestore users
    if (isFirebaseInitialized) {
      try {
        final snap = await _firestore
            .collection('users')
            .limit(limit)
            .get();

        for (final doc in snap.docs) {
          final u = User.fromFirestore(doc.data(), doc.id);
          if (!isSelf(u)) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      } catch (_) {}
    }

    return combined.values.take(limit).toList();
  }

  /// Get single user profile by UID
  Future<User?> getUserById(String uid) async {
    final localUsers = LocalStoreService().getRegisteredUsers();
    for (final u in localUsers) {
      if (u.id == uid || u.username.toLowerCase() == uid.toLowerCase()) {
        return u;
      }
    }

    if (!isFirebaseInitialized) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return User.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get multiple users by UID list
  Future<List<User>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final results = <User>[];
    for (final uid in uids) {
      final u = await getUserById(uid);
      if (u != null) results.add(u);
    }
    return results;
  }

  /// Find single user profile by username across local store and Firestore
  Future<User?> findUserByUsername(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return null;

    // 1. Check local store
    for (final u in LocalStoreService().getRegisteredUsers()) {
      if (u.username.toLowerCase() == clean) return u;
    }

    if (!isFirebaseInitialized) return null;

    try {
      // 2. Query usernames collection for UID
      final unameDoc = await _firestore.collection('usernames').doc(clean).get();
      if (unameDoc.exists && unameDoc.data() != null) {
        final uid = unameDoc.data()!['uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            final u = User.fromFirestore(userDoc.data()!, userDoc.id);
            LocalStoreService().saveUser(u);
            return u;
          }
        }
      }

      // 3. Fallback: Query users collection where username == clean
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final u = User.fromFirestore(query.docs.first.data(), query.docs.first.id);
        LocalStoreService().saveUser(u);
        return u;
      }
    } catch (_) {}

    return null;
  }
}
