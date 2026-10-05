import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  bool get hasValidFirebaseConfig {
    if (!isFirebaseInitialized) return false;
    try {
      final options = Firebase.app().options;
      return !options.apiKey.contains('Placeholder') && !options.apiKey.contains('Demo');
    } catch (_) {
      return false;
    }
  }
  fb.FirebaseAuth? get _auth => isFirebaseInitialized ? fb.FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore => isFirebaseInitialized ? FirebaseFirestore.instance : null;

  fb.User? get currentFirebaseUser => _auth?.currentUser;
  Stream<fb.User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();

  /// Check if a username is available (globally unique) in Firestore
  Future<bool> checkUsernameAvailable(String rawUsername) async {
    final clean = rawUsername.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;
    if (!isFirebaseInitialized) return true;

    try {
      final doc = await _firestore!.collection('usernames').doc(clean).get();
      return !doc.exists;
    } catch (e) {
      // If Firestore read fails (e.g. permissions before login), do not block username
      return true;
    }
  }

  /// Register a new user with Firebase Auth and initialize their Firestore profile
  Future<User> register({
    required String name,
    required String username,
    String? firstName,
    String? lastName,
    required String email,
    required String password,
    String? campusOrCity,
    String? majorOrBio,
  }) async {
    if (!isFirebaseInitialized) {
      throw Exception('Firebase is not initialized. Please connect your Firebase project.');
    }

    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    if (cleanUsername.length < 3) {
      throw Exception('Username must be at least 3 characters long.');
    }

    // 1. Verify username uniqueness
    try {
      final isAvailable = await checkUsernameAvailable(cleanUsername);
      if (!isAvailable) {
        throw Exception('Username @$cleanUsername is already taken. Please choose another.');
      }
    } catch (e) {
      if (e.toString().contains('already taken')) rethrow;
    }

    try {
      // 2. Create Firebase Auth user
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('Failed to create account. Please try again.');
      }

      try {
        await fbUser.updateDisplayName(name.trim());
      } catch (_) {}

      final parts = name.trim().split(' ');
      final resolvedFirst = firstName ?? (parts.isNotEmpty ? parts.first : 'User');
      final resolvedLast = lastName ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
      final campus = campusOrCity ?? 'DDU, Nadiad';

      final newUser = User(
        id: fbUser.uid,
        username: cleanUsername,
        name: name.trim(),
        firstName: resolvedFirst,
        lastName: resolvedLast,
        email: email.trim(),
        campusOrCity: campus,
        majorOrBio: majorOrBio ?? 'EchoGram Member',
        reputation: 50,
        joinedCommunityIds: const [],
        badges: const ['Newcomer'],
        isCollegeVerified: email.contains('ddu.ac.in') || email.contains('edu'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Atomically write users/{uid} and usernames/{cleanUsername}
      try {
        final batch = _firestore!.batch();
        final userDocRef = _firestore!.collection('users').doc(fbUser.uid);
        final usernameDocRef = _firestore!.collection('usernames').doc(cleanUsername);

        batch.set(userDocRef, {
          ...newUser.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch.set(usernameDocRef, {
          'uid': fbUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      } catch (firestoreErr) {
        // If Firestore rules are locked, still return the created user profile
        debugPrint('Firestore profile creation warning: $firestoreErr');
      }

      return newUser;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered. Please log in.');
        case 'invalid-email':
          throw Exception('The email address format is invalid.');
        case 'weak-password':
          throw Exception('The password is too weak. Please use at least 6 characters.');
        case 'operation-not-allowed':
          throw Exception(
            'Email/Password sign-in is disabled in your Firebase Console. '
            'Please go to Firebase Console > Authentication > Sign-in method and enable Email/Password.',
          );
        case 'configuration-not-found':
          throw Exception(
            'Firebase Authentication is not activated in your Firebase Console yet. '
            'Please open Firebase Console > Build > Authentication, click "Get Started", and enable Email/Password under Sign-in method.',
          );
        default:
          throw Exception(e.message ?? 'Registration failed (${e.code}).');
      }
    }
  }

  /// Sign in with either Email or @username
  Future<User> login(String usernameOrEmail, String password) async {
    if (!isFirebaseInitialized) {
      throw Exception('Firebase is not initialized. Please connect your Firebase project.');
    }

    final input = usernameOrEmail.trim();
    String resolvedEmail = input;

    // If input does not look like an email, lookup email by username
    if (!input.contains('@') || !input.contains('.')) {
      final cleanUsername = input.toLowerCase().replaceAll('@', '');
      try {
        final usernameDoc = await _firestore!.collection('usernames').doc(cleanUsername).get();
        if (usernameDoc.exists) {
          final uid = usernameDoc.data()?['uid'] as String?;
          if (uid != null) {
            final userDoc = await _firestore!.collection('users').doc(uid).get();
            final emailFromDoc = userDoc.data()?['email'] as String?;
            if (emailFromDoc != null && emailFromDoc.isNotEmpty) {
              resolvedEmail = emailFromDoc;
            }
          }
        }
      } catch (_) {}
    }

    try {
      // Sign in with Firebase Auth
      final credential = await _auth!.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('Authentication failed.');
      }

      // Fetch Firestore profile
      var profile = await getUserProfile(fbUser.uid);
      if (profile == null) {
        // Self-heal: create minimal profile doc if missing
        final uname = resolvedEmail.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        final dName = fbUser.displayName ?? uname;
        profile = User(
          id: fbUser.uid,
          username: uname.isEmpty ? 'user' : uname,
          name: dName,
          email: fbUser.email ?? resolvedEmail,
          campusOrCity: 'DDU, Nadiad',
          majorOrBio: 'EchoGram Member',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        try {
          await _firestore!.collection('users').doc(fbUser.uid).set(profile.toJson());
        } catch (_) {}
      }

      return profile;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          throw Exception('No account found with this email or username.');
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect password. Please try again.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'operation-not-allowed':
          throw Exception(
            'Email/Password sign-in is disabled in your Firebase Console. '
            'Please go to Firebase Console > Authentication > Sign-in method and enable Email/Password.',
          );
        case 'configuration-not-found':
          throw Exception(
            'Firebase Authentication is not activated in your Firebase Console yet. '
            'Please open Firebase Console > Build > Authentication, click "Get Started", and enable Email/Password under Sign-in method.',
          );
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later.');
        default:
          throw Exception(e.message ?? 'Authentication failed (${e.code}).');
      }
    }
  }

  /// Fetch user profile by UID
  Future<User?> getUserProfile(String uid) async {
    if (!isFirebaseInitialized) return null;
    try {
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return User.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream user profile for realtime updates
  Stream<User?> streamUserProfile(String uid) {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _firestore!.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return User.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Update user profile details
  Future<void> updateProfile({
    required String uid,
    String? name,
    String? campusOrCity,
    String? majorOrBio,
    String? avatarUrl,
  }) async {
    if (!isFirebaseInitialized) return;
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      final cleanName = name.trim();
      updates['name'] = cleanName;
      updates['displayName'] = cleanName;
      final parts = cleanName.split(' ');
      updates['firstName'] = parts.isNotEmpty ? parts.first : 'User';
      updates['lastName'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    if (campusOrCity != null) {
      final cleanLoc = campusOrCity.trim();
      updates['campusOrCity'] = cleanLoc;
      updates['city'] = cleanLoc;
    }
    if (majorOrBio != null) {
      final cleanBio = majorOrBio.trim();
      updates['majorOrBio'] = cleanBio;
      updates['bio'] = cleanBio;
    }
    if (avatarUrl != null) {
      updates['avatarUrl'] = avatarUrl;
      updates['photoUrl'] = avatarUrl;
    }

    try {
      await _firestore!.collection('users').doc(uid).set(updates, SetOptions(merge: true));
      if (name != null && _auth?.currentUser != null) {
        try {
          await _auth!.currentUser!.updateDisplayName(name.trim());
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AuthService] Firestore updateProfile notice: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (isFirebaseInitialized) {
      await _auth!.signOut();
    }
  }
}
