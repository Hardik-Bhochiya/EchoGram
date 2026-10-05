import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/community_provider.dart';
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
      _scrollToBottom(immediate: true);
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
    // Prevent sending blank / empty messages
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
    setState(() {}); // refresh send button disabled state
    _scrollToBottom();
  }

  void _scrollToBottom({bool immediate = false}) {
    Future.delayed(Duration(milliseconds: immediate ? 50 : 120), () {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _showRulesDialog(BuildContext context, String groupName, List<String> rules) {
    final effectiveRules = rules.isNotEmpty
        ? rules
        : [
            'Treat all members with respect and courtesy.',
            'No harassment, hate speech, or offensive content.',
            'No promotional spam, affiliate links, or repetitive messages.',
            'Keep conversations genuine, helpful, and on topic.',
            'Respect the privacy and safety of fellow peers.',
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Icon(Icons.rule_rounded, color: Color(0xFF58A6FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rules & Regulations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF0F6FC),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF8B949E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF30363D), height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: effectiveRules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF21262D),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF58A6FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              effectiveRules[index],
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFC9D1D9),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('I Understand & Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final chatProvider = context.watch<ChatProvider>();
    final communityProvider = context.watch<CommunityProvider>();

    final room = chatProvider.rooms.firstWhere(
      (r) => r.id == widget.roomId,
      orElse: () => chatProvider.rooms.isNotEmpty
          ? chatProvider.rooms.first
          : chatProvider.getOrCreateCommunityRoom(widget.roomId, 'Chat', '💬'),
    );

    final commId = room.communityId ??
        (widget.roomId.startsWith('room-') ? widget.roomId.replaceFirst('room-', '') : widget.roomId);

    final community = (commId.isNotEmpty ? communityProvider.getCommunityById(commId) : null) ??
        communityProvider.communities
            .where((c) => c.name.toLowerCase() == room.title.replaceAll(' Chat', '').toLowerCase().trim())
            .firstOrNull;

    final memberCount = community != null
        ? community.memberCount
        : (room.participantIds.isNotEmpty ? room.participantIds.length : room.memberCount);

    final allMessages = chatProvider.getMessages(widget.roomId, currentUserId: currentUserId);
    final rawMessages = allMessages.where((m) => !m.deletedForUserIds.contains(currentUserId)).toList();

    // Absolute guaranteed deduplication in UI:
    final List<ChatMessage> messages = [];
    for (final m in rawMessages) {
      final sContent = m.content.trim();
      final hasDup = messages.any((u) =>
          u.id == m.id ||
          (u.senderId == m.senderId &&
              u.content.trim() == sContent &&
              u.timestamp.difference(m.timestamp).abs().inSeconds < 5));
      if (!hasDup) {
        messages.add(m);
      }
    }

    final isMessageEmpty = _messageController.text.trim().isEmpty;

    String displayTitle = room.title;
    if (!room.isGroup) {
      final cleanCurrent = (auth.currentUser?.username ?? '').toLowerCase().replaceAll('@', '').trim();
      if (room.id.startsWith('dm-')) {
        final parts = room.id.substring(3).split('_');
        if (parts.length == 2) {
          final p1 = parts[0].toLowerCase().trim();
          final p2 = parts[1].toLowerCase().trim();
          final other = p1 == cleanCurrent ? p2 : (p2 == cleanCurrent ? p1 : (p1.isNotEmpty ? p1 : p2));
          if (other.isNotEmpty) {
            displayTitle = '@$other';
          }
        }
      } else if (room.subtitle != null && room.subtitle!.startsWith('@')) {
        displayTitle = room.subtitle!;
      } else if (room.title.startsWith('@')) {
        displayTitle = room.title;
      } else {
        displayTitle = '@${room.title.toLowerCase().replaceAll(' ', '')}';
      }
    }

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
                    displayTitle,
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
                      '$memberCount joined',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                    )
                  else
                    Text(
                      room.isOnline ? 'Online • Direct Chat' : 'Direct Chat',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // On the top right side: Rules and Regulations button for the group
          if (room.isGroup)
            IconButton(
              icon: const Icon(Icons.rule_rounded, color: Color(0xFF58A6FF), size: 23),
              tooltip: 'Group Rules & Regulations',
              onPressed: () {
                _showRulesDialog(context, room.title, community?.rules ?? []);
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Messages List: Live Chat in chronological order
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
                        onLike: () {
                          chatProvider.toggleLikeMessage(widget.roomId, msg.id, currentUserId);
                        },
                        onDislike: () {
                          chatProvider.toggleDislikeMessage(widget.roomId, msg.id, currentUserId);
                        },
                        onDelete: (forEveryone) {
                          chatProvider.deleteMessage(widget.roomId, msg.id, forEveryone: forEveryone, userId: currentUserId);
                        },
                      );
                    },
                  ),
          ),

          // Bottom Chat Bar: only chat box and send option (blank messages prevented)
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
                      onChanged: (_) => setState(() {}),
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
                    decoration: BoxDecoration(
                      color: isMessageEmpty ? const Color(0xFF21262D) : const Color(0xFF238636),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: isMessageEmpty ? const Color(0xFF8B949E) : Colors.white,
                        size: 18,
                      ),
                      onPressed: isMessageEmpty ? null : _sendMessage,
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
