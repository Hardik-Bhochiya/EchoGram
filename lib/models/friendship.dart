import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final List<String> userIds;
  final List<String> usernames;
  final String user1;
  final String user2;
  final String? user1Name;
  final String? user2Name;
  final String? user1Avatar;
  final String? user2Avatar;
  final DateTime createdAt;
  final String? dmConversationId;

  const Friendship({
    required this.id,
    required this.userIds,
    this.usernames = const [],
    this.user1 = '',
    this.user2 = '',
    this.user1Name,
    this.user2Name,
    this.user1Avatar,
    this.user2Avatar,
    required this.createdAt,
    this.dmConversationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userIds': userIds,
      'usernames': usernames,
      'user1': user1,
      'user2': user2,
      'user1Name': user1Name,
      'user2Name': user2Name,
      'user1Avatar': user1Avatar,
      'user2Avatar': user2Avatar,
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

    final rawUsernames = data['usernames'];
    List<String> parsedUsernames = [];
    if (rawUsernames is List) {
      parsedUsernames = rawUsernames.map((e) => e.toString().toLowerCase()).toList();
    }

    final rawIds = data['userIds'];
    List<String> parsedIds = [];
    if (rawIds is List) {
      parsedIds = rawIds.map((e) => e.toString()).toList();
    }

    return Friendship(
      id: docId,
      userIds: parsedIds,
      usernames: parsedUsernames,
      user1: (data['user1'] ?? (parsedUsernames.isNotEmpty ? parsedUsernames.first : '')).toString().toLowerCase(),
      user2: (data['user2'] ?? (parsedUsernames.length > 1 ? parsedUsernames[1] : '')).toString().toLowerCase(),
      user1Name: data['user1Name'] as String?,
      user2Name: data['user2Name'] as String?,
      user1Avatar: data['user1Avatar'] as String?,
      user2Avatar: data['user2Avatar'] as String?,
      createdAt: parseDate(data['createdAt']),
      dmConversationId: data['dmConversationId'] as String?,
    );
  }
}
