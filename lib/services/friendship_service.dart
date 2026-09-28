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

  String _getSortedFriendshipId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Get relationship state between current user and target user
  Future<RelationshipState> getRelationshipState(String currentUserId, String otherUserId) async {
    if (currentUserId == otherUserId) return RelationshipState.self;
    if (!isFirebaseInitialized) return RelationshipState.none;

    try {
      // 1. Check if already friends
      final friendshipId = _getSortedFriendshipId(currentUserId, otherUserId);
      final friendshipDoc = await _firestore.collection('friendships').doc(friendshipId).get();
      if (friendshipDoc.exists) {
        return RelationshipState.friends;
      }

      // 2. Check for pending outgoing request
      final outgoingQuery = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: otherUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (outgoingQuery.docs.isNotEmpty) {
        return RelationshipState.pendingOutgoing;
      }

      // 3. Check for pending incoming request
      final incomingQuery = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (incomingQuery.docs.isNotEmpty) {
        return RelationshipState.pendingIncoming;
      }
    } catch (_) {}

    return RelationshipState.none;
  }

  /// Send a friend request and dispatch notification
  Future<String> sendFriendRequest(User sender, User receiver) async {
    if (!isFirebaseInitialized) {
      throw Exception('Firebase is not initialized.');
    }

    final existingState = await getRelationshipState(sender.id, receiver.id);
    if (existingState == RelationshipState.friends) {
      throw Exception('You are already friends with @${receiver.username}.');
    }
    if (existingState == RelationshipState.pendingOutgoing) {
      throw Exception('Friend request already sent.');
    }

    final reqRef = _firestore.collection('friendRequests').doc();
    final notifRef = _firestore.collection('notifications').doc();

    final batch = _firestore.batch();

    // 1. Friend Request Document
    batch.set(reqRef, {
      'id': reqRef.id,
      'senderId': sender.id,
      'senderUsername': sender.username,
      'senderName': sender.name,
      'senderAvatar': sender.avatarUrl,
      'receiverId': receiver.id,
      'receiverUsername': receiver.username,
      'receiverName': receiver.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Event-Driven Notification for Receiver
    batch.set(notifRef, {
      'recipientId': receiver.id,
      'actorId': sender.id,
      'type': 'friend_request',
      'entityId': reqRef.id,
      'title': 'New Friend Request',
      'message': '${sender.name} (@${sender.username}) wants to connect with you.',
      'readAt': null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return reqRef.id;
  }

  /// Cancel an outgoing friend request
  Future<void> cancelFriendRequest(String currentUserId, String otherUserId) async {
    if (!isFirebaseInitialized) return;
    final query = await _firestore
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Accept an incoming friend request
  Future<void> acceptFriendRequest(FriendRequest request, User currentUser) async {
    if (!isFirebaseInitialized) return;
    final friendshipId = _getSortedFriendshipId(request.senderId, request.receiverId);
    final friendshipRef = _firestore.collection('friendships').doc(friendshipId);
    final reqRef = _firestore.collection('friendRequests').doc(request.id);
    final notifRef = _firestore.collection('notifications').doc();

    final batch = _firestore.batch();

    // 1. Update Request status to accepted
    batch.update(reqRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create canonical Friendship record
    batch.set(friendshipRef, {
      'id': friendshipId,
      'userIds': [request.senderId, request.receiverId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Dispatch Notification to sender
    batch.set(notifRef, {
      'recipientId': request.senderId,
      'actorId': currentUser.id,
      'type': 'friend_accept',
      'entityId': friendshipId,
      'title': 'Friend Request Accepted! 🎉',
      'message': '${currentUser.name} (@${currentUser.username}) accepted your friend request. You can now chat!',
      'readAt': null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Decline an incoming friend request
  Future<void> declineFriendRequest(String requestId) async {
    if (!isFirebaseInitialized) return;
    await _firestore.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a friendship
  Future<void> removeFriend(String currentUserId, String otherUserId) async {
    if (!isFirebaseInitialized) return;
    final friendshipId = _getSortedFriendshipId(currentUserId, otherUserId);
    await _firestore.collection('friendships').doc(friendshipId).delete();
  }

  /// Stream pending incoming friend requests for current user
  Stream<List<FriendRequest>> streamPendingIncomingRequests(String currentUserId) {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _firestore
        .collection('friendRequests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Stream pending outgoing friend requests for current user
  Stream<List<FriendRequest>> streamPendingOutgoingRequests(String currentUserId) {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _firestore
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Stream friendships for current user
  Stream<List<Friendship>> streamFriendships(String currentUserId) {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _firestore
        .collection('friendships')
        .where('userIds', arrayContains: currentUserId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}
