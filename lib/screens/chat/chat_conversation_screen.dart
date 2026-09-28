import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_bubble.dart';

class ChatConversationScreen extends StatefulWidget {
  final String roomId;
  const ChatConversationScreen({super.key, required this.roomId});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      chatProvider.joinRoom(widget.roomId, auth.currentUser?.name ?? 'User');
      chatProvider.markRoomAsRead(widget.roomId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendMessage(
      roomId: widget.roomId,
      content: text,
      currentUser: user,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? 'user-hardik';
    final chatProvider = context.watch<ChatProvider>();

    final room = chatProvider.rooms.firstWhere(
      (r) => r.id == widget.roomId,
      orElse: () => chatProvider.rooms.isNotEmpty
          ? chatProvider.rooms.first
          : chatProvider.getOrCreateCommunityRoom(widget.roomId, 'Chat', '💬'),
    );

    final allMessages = chatProvider.getMessages(widget.roomId, currentUserId: currentUserId);
    final messages = allMessages.where((m) => !m.deletedForUserIds.contains(currentUserId)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF0F6FC)),
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF21262D),
              child: Text(
                (room.avatarEmoji != null && room.avatarEmoji!.isNotEmpty)
                    ? room.avatarEmoji!
                    : (room.isGroup ? '💬' : '👤'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF0F6FC),
                    ),
                  ),
                  if (room.isGroup)
                    Text(
                      '${room.memberCount > 0 ? room.memberCount : 1} members',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 10),
                        Text(
                          'Say hello to ${room.title}!',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13.5),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return ChatBubble(
                        message: msg,
                        currentUserId: currentUserId,
                        showSenderName: room.isGroup,
                        onDelete: (forEveryone) {
                          chatProvider.deleteMessage(widget.roomId, msg.id, forEveryone: forEveryone, userId: currentUserId);
                        },
                      );
                    },
                  ),
          ),

          // Simple Text Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF238636),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
