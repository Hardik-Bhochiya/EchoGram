import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import '../models/friendship.dart';

enum RelationshipState {
  none,
  pendingOutgoing,
  pendingIncoming,
  friends,
  self,
}

class FriendshipService {
  static final FriendshipService _instance = FriendshipService._internal();
  factory FriendshipService() => _instance;
  FriendshipService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String getCanonicalFriendshipId(String username1, String username2) {
    final u1 = username1.trim().toLowerCase().replaceAll('@', '');
    final u2 = username2.trim().toLowerCase().replaceAll('@', '');
    final list = [u1, u2]..sort();
    return '${list[0]}_${list[1]}';
  }

  String _getSortedUidFriendshipId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Get relationship state between current user and target user
  Future<RelationshipState> getRelationshipState({
    required String currentUsername,
    required String currentUserId,
    required String otherUsername,
    required String otherUserId,
  }) async {
    final cUser = currentUsername.trim().toLowerCase().replaceAll('@', '');
    final oUser = otherUsername.trim().toLowerCase().replaceAll('@', '');

    if (cUser == oUser || currentUserId == otherUserId) return RelationshipState.self;
    if (!isFirebaseInitialized) return RelationshipState.none;

    try {
      // 1. Check canonical username-based friendship doc
      final canonicalId = getCanonicalFriendshipId(cUser, oUser);
      final doc1 = await _firestore.collection('friendships').doc(canonicalId).get();
      if (doc1.exists) {
        return RelationshipState.friends;
      }

      // 1b. Check UID-based friendship doc fallback
      if (currentUserId.isNotEmpty && otherUserId.isNotEmpty) {
        final uidId = _getSortedUidFriendshipId(currentUserId, otherUserId);
        final doc2 = await _firestore.collection('friendships').doc(uidId).get();
        if (doc2.exists) {
          return RelationshipState.friends;
        }
      }

      // 2. Check for pending outgoing request from current user to other user
      final outgoingQuery = await _firestore
          .collection('friendRequests')
          .where('senderUsername', isEqualTo: cUser)
          .get();

      final hasPendingOut = outgoingQuery.docs.any((d) {
        final data = d.data();
        final rUname = (data['receiverUsername'] ?? '').toString().toLowerCase().replaceAll('@', '');
        return rUname == oUser && data['status'] == 'pending';
      });

      if (hasPendingOut) {
        return RelationshipState.pendingOutgoing;
      }

      // 3. Check for pending incoming request from other user to current user
      final incomingQuery = await _firestore
          .collection('friendRequests')
          .where('receiverUsername', isEqualTo: cUser)
          .get();

      final hasPendingIn = incomingQuery.docs.any((d) {
        final data = d.data();
        final sUname = (data['senderUsername'] ?? '').toString().toLowerCase().replaceAll('@', '');
        return sUname == oUser && data['status'] == 'pending';
      });

      if (hasPendingIn) {
        return RelationshipState.pendingIncoming;
      }
    } catch (e) {
      debugPrint('[FriendshipService] getRelationshipState notice: $e');
    }

    return RelationshipState.none;
  }

  /// Send a friend request and dispatch event-driven notification in Firestore
  Future<String> sendFriendRequest(User sender, User receiver) async {
    if (!isFirebaseInitialized) {
      throw Exception('Firebase is not initialized.');
    }

    final sUser = sender.username.trim().toLowerCase().replaceAll('@', '');
    final rUser = receiver.username.trim().toLowerCase().replaceAll('@', '');

    if (sUser == rUser) {
      throw Exception('Cannot send friend request to yourself.');
    }

    // Check if already friends
    final canonicalId = getCanonicalFriendshipId(sUser, rUser);
    final fDoc = await _firestore.collection('friendships').doc(canonicalId).get();
    if (fDoc.exists) {
      throw Exception('You are already friends with @$rUser.');
    }

    // Deterministic request ID so duplicate clicks never create duplicate documents
    final reqDocId = '${sUser}_to_$rUser';
    final reqRef = _firestore.collection('friendRequests').doc(reqDocId);
    final notifRef = _firestore.collection('notifications').doc();

    final batch = _firestore.batch();

    // 1. Friend Request Document
    batch.set(reqRef, {
      'id': reqDocId,
      'senderId': sender.id,
      'senderUsername': sUser,
      'senderName': sender.name,
      'senderAvatar': sender.avatarUrl,
      'receiverId': receiver.id,
      'receiverUsername': rUser,
      'receiverName': receiver.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Notification for Receiver
    batch.set(notifRef, {
      'recipientId': receiver.id,
      'recipientUsername': rUser,
      'actorId': sender.id,
      'actorUsername': sUser,
      'type': 'friend_request',
      'entityId': reqDocId,
      'title': 'New Friend Request',
      'message': '${sender.name} (@$sUser) wants to connect with you.',
      'readAt': null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return reqDocId;
  }

  /// Accept an incoming friend request
  Future<void> acceptFriendRequest(FriendRequest request, User currentUser) async {
    if (!isFirebaseInitialized) return;

    final u1 = request.senderUsername.trim().toLowerCase().replaceAll('@', '');
    final u2 = request.receiverUsername.trim().toLowerCase().replaceAll('@', '');
    final canonicalFriendshipId = getCanonicalFriendshipId(u1, u2);

    final friendshipRef = _firestore.collection('friendships').doc(canonicalFriendshipId);
    final notifRef = _firestore.collection('notifications').doc();

    final batch = _firestore.batch();

    // 1. Update the original request doc by ID if it exists
    if (request.id.isNotEmpty) {
      final reqRef = _firestore.collection('friendRequests').doc(request.id);
      batch.set(reqRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 1b. Also update the deterministic doc ID `${u1}_to_${u2}`
    final deterministicReqRef = _firestore.collection('friendRequests').doc('${u1}_to_$u2');
    batch.set(deterministicReqRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Canonical Friendship Document
    batch.set(friendshipRef, {
      'id': canonicalFriendshipId,
      'usernames': [u1, u2],
      'userIds': [request.senderId, currentUser.id],
      'user1': u1,
      'user2': u2,
      'user1Name': request.senderName,
      'user2Name': currentUser.name,
      'user1Avatar': request.senderAvatar,
      'user2Avatar': currentUser.avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Notification for sender
    batch.set(notifRef, {
      'recipientId': request.senderId,
      'recipientUsername': u1,
      'actorId': currentUser.id,
      'actorUsername': currentUser.username,
      'type': 'friend_accept',
      'entityId': canonicalFriendshipId,
      'title': 'Friend Request Accepted! 🎉',
      'message': '${currentUser.name} (@${currentUser.username}) accepted your friend request. You can now chat!',
      'readAt': null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Decline an incoming friend request
  Future<void> declineFriendRequest(String requestId, {String? senderUsername, String? receiverUsername}) async {
    if (!isFirebaseInitialized) return;

    try {
      final batch = _firestore.batch();

      if (requestId.isNotEmpty) {
        final docRef = _firestore.collection('friendRequests').doc(requestId);
        batch.set(docRef, {
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (senderUsername != null && receiverUsername != null) {
        final sUser = senderUsername.trim().toLowerCase().replaceAll('@', '');
        final rUser = receiverUsername.trim().toLowerCase().replaceAll('@', '');
        final detRef = _firestore.collection('friendRequests').doc('${sUser}_to_$rUser');
        batch.set(detRef, {
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('[FriendshipService] declineFriendRequest notice: $e');
    }
  }

  /// Cancel an outgoing friend request
  Future<void> cancelFriendRequest(String senderUsername, String receiverUsername) async {
    if (!isFirebaseInitialized) return;
    final sUser = senderUsername.trim().toLowerCase().replaceAll('@', '');
    final rUser = receiverUsername.trim().toLowerCase().replaceAll('@', '');

    try {
      final docRef = _firestore.collection('friendRequests').doc('${sUser}_to_$rUser');
      await docRef.set({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FriendshipService] cancelFriendRequest notice: $e');
    }
  }

  /// Remove a friendship
  Future<void> removeFriend(String username1, String username2) async {
    if (!isFirebaseInitialized) return;
    final canonicalId = getCanonicalFriendshipId(username1, username2);
    try {
      await _firestore.collection('friendships').doc(canonicalId).delete();
    } catch (e) {
      debugPrint('[FriendshipService] removeFriend notice: $e');
    }
  }

  /// Stream pending incoming friend requests for user by username
  Stream<List<FriendRequest>> streamPendingIncomingRequests(String username) {
    if (!isFirebaseInitialized) return const Stream.empty();
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return const Stream.empty();

    return _firestore
        .collection('friendRequests')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
            .where((r) {
              final rUname = r.receiverUsername.trim().toLowerCase().replaceAll('@', '');
              return rUname == clean && r.isPending;
            })
            .toList());
  }

  /// Stream outgoing friend requests for user by username (includes status updates like declined/accepted)
  Stream<List<FriendRequest>> streamOutgoingRequests(String username) {
    if (!isFirebaseInitialized) return const Stream.empty();
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return const Stream.empty();

    return _firestore
        .collection('friendRequests')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
            .where((r) {
              final sUname = r.senderUsername.trim().toLowerCase().replaceAll('@', '');
              return sUname == clean;
            })
            .toList());
  }

  /// Stream all friendships for user by username
  Stream<List<Friendship>> streamFriendships(String username) {
    if (!isFirebaseInitialized) return const Stream.empty();
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return const Stream.empty();

    return _firestore
        .collection('friendships')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
            .where((f) {
              final u1 = f.user1.toLowerCase().replaceAll('@', '').trim();
              final u2 = f.user2.toLowerCase().replaceAll('@', '').trim();
              final unames = f.usernames.map((u) => u.toLowerCase().replaceAll('@', '').trim()).toSet();
              final docId = f.id.toLowerCase().replaceAll('@', '').trim();
              return u1 == clean || u2 == clean || unames.contains(clean) || docId.contains(clean);
            })
            .toList());
  }
}
