import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_message.dart';
import 'local_store_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  static bool disabledForTests = false;
  String? _registeredUserId;
  String? _registeredUsername;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _editController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();
  final _likeController = StreamController<Map<String, dynamic>>.broadcast();
  final _dislikeController = StreamController<Map<String, dynamic>>.broadcast();
  final _seenController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendRequestReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendRequestAcceptedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get onMessageReceived => _messageController.stream;
  Stream<Map<String, dynamic>> get onTypingStatus => _typingController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _editController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deleteController.stream;
  Stream<Map<String, dynamic>> get onMessageLiked => _likeController.stream;
  Stream<Map<String, dynamic>> get onMessageDisliked => _dislikeController.stream;
  Stream<Map<String, dynamic>> get onMessageSeen => _seenController.stream;
  Stream<Map<String, dynamic>> get onFriendRequestReceived => _friendRequestReceivedController.stream;
  Stream<Map<String, dynamic>> get onFriendRequestAccepted => _friendRequestAcceptedController.stream;

  bool get isConnected => _isConnected;

  String get socketUrl {
    final customUrl = LocalStoreService().customBackendUrl;
    if (customUrl != null && customUrl.isNotEmpty) {
      final base = customUrl.endsWith('/api')
          ? customUrl.substring(0, customUrl.length - 4)
          : customUrl;
      return '$base/chat';
    }

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:5000/chat';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5000/chat'
        : 'http://localhost:5000/chat';
  }

  void connect() {
    if (disabledForTests || (_socket != null && _isConnected)) return;

    try {
      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1500)
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        _isConnected = true;
        debugPrint('[SocketService] Connected to NearTalk WebSocket server at $socketUrl');
        if (_registeredUserId != null || _registeredUsername != null) {
          _socket?.emit('join_user', {
            'userId': _registeredUserId ?? '',
            'username': _registeredUsername ?? '',
          });
          debugPrint('[SocketService] Auto-joined user channel for $_registeredUsername on connect');
        }
      });

      _socket?.onDisconnect((_) {
        _isConnected = false;
        debugPrint('[SocketService] Disconnected from WebSocket server');
      });

      _socket?.onConnectError((err) {
        _isConnected = false;
        debugPrint('[SocketService] WebSocket connection error: $err');
      });

      _socket?.on('receive_message', (data) {
        if (data != null && data is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(data);
          _messageController.add(msg);
        }
      });

      _socket?.on('user_typing', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _typingController.add(data);
        }
      });

      _socket?.on('message_edited', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _editController.add(data);
        }
      });

      _socket?.on('message_deleted', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _deleteController.add(data);
        }
      });

      _socket?.on('message_liked', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _likeController.add(data);
        }
      });

      _socket?.on('message_disliked', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _dislikeController.add(data);
        }
      });

      _socket?.on('message_seen', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _seenController.add(data);
        }
      });

      _socket?.on('friend_request_received', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _friendRequestReceivedController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket?.on('friend_request_accepted', (data) {
        if (data != null && data is Map<String, dynamic>) {
          _friendRequestAcceptedController.add(Map<String, dynamic>.from(data));
        }
      });
    } catch (e) {
      debugPrint('[SocketService] Socket connection failed: $e');
    }
  }

  void joinUser(String userId, String username) {
    _registeredUserId = userId;
    _registeredUsername = username;
    if (disabledForTests) return;
    if (!_isConnected) {
      connect();
      return;
    }
    _socket?.emit('join_user', {'userId': userId, 'username': username});
    debugPrint('[SocketService] Emitted join_user for $username ($userId)');
  }

  void joinRoom(String roomId, String userName) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('join_room', {'roomId': roomId, 'userName': userName});
  }

  void leaveRoom(String roomId, String userName) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('leave_room', {'roomId': roomId, 'userName': userName});
  }

  void sendMessage({
    String? id,
    required String roomId,
    required String content,
    required String senderId,
    required String senderName,
    String? senderUsername,
    required bool isAnonymous,
    String? timestamp,
  }) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('send_message', {
      if (id != null) 'id': id,
      'roomId': roomId,
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      if (senderUsername != null) 'senderUsername': senderUsername,
      'isAnonymous': isAnonymous,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  void editMessage(String roomId, String messageId, String newContent) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('edit_message', {
      'roomId': roomId,
      'messageId': messageId,
      'newContent': newContent,
    });
  }

  void deleteMessage(String roomId, String messageId, bool forEveryone) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('delete_message', {
      'roomId': roomId,
      'messageId': messageId,
      'forEveryone': forEveryone,
    });
  }

  void likeMessage(String roomId, String messageId, String userId) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('like_message', {
      'roomId': roomId,
      'messageId': messageId,
      'userId': userId,
    });
  }

  void dislikeMessage(String roomId, String messageId, String userId) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('dislike_message', {
      'roomId': roomId,
      'messageId': messageId,
      'userId': userId,
    });
  }

  void markSeen(String roomId, String messageId) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('mark_seen', {
      'roomId': roomId,
      'messageId': messageId,
    });
  }

  void startTyping(String roomId, String userName) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('typing_start', {'roomId': roomId, 'userName': userName});
  }

  void stopTyping(String roomId, String userName) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('typing_stop', {'roomId': roomId, 'userName': userName});
  }

  void sendFriendRequest(Map<String, dynamic> requestData) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('send_friend_request', requestData);
  }

  void respondFriendRequest({
    required String requestId,
    required String status,
    required String senderUsername,
    required String receiverUsername,
  }) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('respond_friend_request', {
      'requestId': requestId,
      'status': status,
      'senderUsername': senderUsername,
      'receiverUsername': receiverUsername,
    });
  }

  void cancelFriendRequest({
    required String requestId,
    required String senderUsername,
    required String receiverUsername,
  }) {
    if (disabledForTests || !_isConnected) return;
    _socket?.emit('cancel_friend_request', {
      'requestId': requestId,
      'senderUsername': senderUsername,
      'receiverUsername': receiverUsername,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
