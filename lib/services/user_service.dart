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
  Future<List<User>> searchUsers(String query, {String? currentUserId}) async {
    final clean = query.trim().replaceFirst(RegExp(r'^@'), '').trim();
    if (clean.isEmpty) return [];

    final Map<String, User> combined = {};

    // 1. Instant match from Local Registered Users
    final localResults = LocalStoreService().searchUsers(clean, excludeUserId: currentUserId);
    for (final u in localResults) {
      combined[u.username.toLowerCase()] = u;
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
          if (u.id != currentUserId) {
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
          if (u.id != currentUserId && u.username.toLowerCase() != (currentUserId?.toLowerCase() ?? '')) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      }
    } catch (_) {}

    return combined.values.toList();
  }

  /// Get suggested classmates / peers prioritizing Cloud Firestore
  Future<List<User>> getSuggestedUsers({String? currentUserId, int limit = 10}) async {
    final Map<String, User> combined = {};

    // 1. Local registered users
    final localUsers = LocalStoreService().getRegisteredUsers();
    for (final u in localUsers) {
      if (u.id != currentUserId) {
        combined[u.username.toLowerCase()] = u;
      }
    }

    // 2. Primary: Cloud Firestore users
    if (isFirebaseInitialized) {
      try {
        final snap = await _firestore
            .collection('users')
            .limit(limit + 10)
            .get();

        for (final doc in snap.docs) {
          final u = User.fromFirestore(doc.data(), doc.id);
          if (u.id != currentUserId) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: MongoDB backend users
    try {
      if (ApiService().isServerReachable) {
        final apiResults = await ApiService().searchPeers('');
        for (final u in apiResults) {
          if (u.id != currentUserId) {
            combined[u.username.toLowerCase()] = u;
            LocalStoreService().saveUser(u);
          }
        }
      }
    } catch (_) {}

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
}
