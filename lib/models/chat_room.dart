class ChatRoom {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarEmoji;
  final String? communityId;
  final bool isGroup;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<String> participantIds;

  const ChatRoom({
    required this.id,
    required this.title,
    this.subtitle,
    this.avatarEmoji,
    this.communityId,
    this.isGroup = false,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.participantIds = const [],
  });

  String get name => title;
  bool get isCommunity => communityId != null || isGroup;
  int get memberCount => participantIds.length;
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(lastMessageTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, "0")}';
    return '${lastMessageTime.day}/${lastMessageTime.month}';
  }

  ChatRoom copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? avatarEmoji,
    String? communityId,
    bool? isGroup,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    List<String>? participantIds,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      communityId: communityId ?? this.communityId,
      isGroup: isGroup ?? this.isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      participantIds: participantIds ?? this.participantIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'avatarEmoji': avatarEmoji,
      'communityId': communityId,
      'isGroup': isGroup,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'participantIds': participantIds,
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      avatarEmoji: json['avatarEmoji'] as String?,
      communityId: json['communityId'] as String?,
      isGroup: json['isGroup'] as bool? ?? false,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageTime: DateTime.tryParse(json['lastMessageTime'] ?? '') ?? DateTime.now(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? false,
      participantIds: List<String>.from(json['participantIds'] ?? []),
    );
  }
}
