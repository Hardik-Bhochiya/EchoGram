import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final List<String> userIds;
  final DateTime createdAt;
  final String? dmConversationId;

  const Friendship({
    required this.id,
    required this.userIds,
    required this.createdAt,
    this.dmConversationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userIds': userIds,
      'createdAt': createdAt.toIso8601String(),
      'dmConversationId': dmConversationId,
    };
  }

  factory Friendship.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Friendship(
      id: docId,
      userIds: List<String>.from(data['userIds'] ?? []),
      createdAt: parseDate(data['createdAt']),
      dmConversationId: data['dmConversationId'] as String?,
    );
  }
}
