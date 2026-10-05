import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationItem {
  final String id;
  final String recipientId;
  final String actorId;
  final String type; // 'friend_request', 'friend_accept', 'message', 'group_invite', 'question_reply', 'community'
  final String entityId;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final String iconEmoji;

  const NotificationItem({
    required this.id,
    this.recipientId = '',
    this.actorId = '',
    required this.type,
    this.entityId = '',
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
    this.isRead = false,
    this.iconEmoji = '🔔',
  });

  // Calculate dynamic humanized time ago on client
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(createdAt);
  }

  NotificationItem copyWith({
    String? id,
    String? recipientId,
    String? actorId,
    String? type,
    String? entityId,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isRead,
    String? iconEmoji,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      actorId: actorId ?? this.actorId,
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      iconEmoji: iconEmoji ?? this.iconEmoji,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientId': recipientId,
      'actorId': actorId,
      'type': type,
      'entityId': entityId,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'iconEmoji': iconEmoji,
    };
  }

  factory NotificationItem.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final type = data['type'] as String? ?? 'community';
    String emoji = '🔔';
    if (type == 'friend_request') emoji = '👋';
    if (type == 'friend_accept') emoji = '🤝';
    if (type == 'message') emoji = '💬';
    if (type == 'question_reply') emoji = '💡';

    return NotificationItem(
      id: docId,
      recipientId: data['recipientId'] as String? ?? '',
      actorId: data['actorId'] as String? ?? '',
      type: type,
      entityId: data['entityId'] as String? ?? '',
      title: data['title'] as String? ?? 'EchoGram Notification',
      message: data['message'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      readAt: data['readAt'] != null ? parseDate(data['readAt']) : null,
      isRead: data['isRead'] as bool? ?? (data['readAt'] != null),
      iconEmoji: data['iconEmoji'] as String? ?? emoji,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NotificationItem(
      id: json['id'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      type: json['type'] as String? ?? 'community',
      entityId: json['entityId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
      readAt: json['readAt'] != null ? parseDate(json['readAt']) : null,
      isRead: json['isRead'] as bool? ?? false,
      iconEmoji: json['iconEmoji'] as String? ?? '🔔',
    );
  }
}
