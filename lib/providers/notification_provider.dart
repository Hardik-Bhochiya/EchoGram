import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_item.dart';

class NotificationProvider extends ChangeNotifier {
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => isFirebaseInitialized ? FirebaseFirestore.instance : null;

  List<NotificationItem> _notifications = [];
  StreamSubscription? _notifSub;
  String? _currentUserId;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _notifications = [];
  }

  void initForUser(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _notifSub?.cancel();
    if (!isFirebaseInitialized) return;

    _notifSub = _firestore!
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notifications = list;
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    if (!isFirebaseInitialized || _currentUserId == null) return;
    try {
      final unreadDocs = await _firestore!
          .collection('notifications')
          .where('recipientId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore!.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();

      if (!isFirebaseInitialized) return;
      try {
        await _firestore!.collection('notifications').doc(id).update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? entityId,
    String recipientId = '',
    String actorId = '',
    String iconEmoji = '🔔',
  }) async {
    final id = isFirebaseInitialized
        ? _firestore!.collection('notifications').doc().id
        : 'notif_${DateTime.now().millisecondsSinceEpoch}';

    final notif = NotificationItem(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      entityId: entityId ?? '',
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isRead: false,
      iconEmoji: iconEmoji,
    );

    _notifications.insert(0, notif);
    notifyListeners();

    if (!isFirebaseInitialized) return;
    try {
      await _firestore!.collection('notifications').doc(id).set({
        ...notif.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }
}
