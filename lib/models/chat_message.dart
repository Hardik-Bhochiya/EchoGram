enum MessageType { text, image, system }

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime timestamp;
  final bool isMine;
  final bool isAnonymous;
  final MessageType type;
  final String status; // 'sent', 'delivered', 'seen'
  final List<String> likes; // userIds who liked
  final List<String> dislikes; // userIds who disliked
  final bool isEdited;
  final bool isDeleted; // Deleted for everyone
  final List<String> deletedForUserIds; // Deleted for specific users

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.timestamp,
    required this.isMine,
    this.isAnonymous = false,
    this.type = MessageType.text,
    this.status = 'seen',
    this.likes = const [],
    this.dislikes = const [],
    this.isEdited = false,
    this.isDeleted = false,
    this.deletedForUserIds = const [],
  });

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    bool? isMine,
    bool? isAnonymous,
    MessageType? type,
    String? status,
    List<String>? likes,
    List<String>? dislikes,
    bool? isEdited,
    bool? isDeleted,
    List<String>? deletedForUserIds,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isMine: isMine ?? this.isMine,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      type: type ?? this.type,
      status: status ?? this.status,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isMine': isMine,
      'isAnonymous': isAnonymous,
      'type': type.name,
      'status': status,
      'likes': likes,
      'dislikes': dislikes,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'deletedForUserIds': deletedForUserIds,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sId = json['senderId'] as String;
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderId: sId,
      senderName: json['senderName'] as String? ?? 'User',
      senderAvatar: json['senderAvatar'] as String?,
      content: json['content'] as String? ?? '',
      timestamp: (DateTime.tryParse(json['timestamp']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now()).toLocal(),
      isMine: currentUserId != null ? (sId == currentUserId) : (json['isMine'] as bool? ?? false),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      status: json['status'] as String? ?? 'seen',
      likes: List<String>.from(json['likes'] ?? []),
      dislikes: List<String>.from(json['dislikes'] ?? []),
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedForUserIds: List<String>.from(json['deletedForUserIds'] ?? []),
    );
  }
}
