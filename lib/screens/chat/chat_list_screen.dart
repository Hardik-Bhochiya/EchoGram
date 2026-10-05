import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../search/search_screen.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatSheet(BuildContext context, AuthProvider auth, ChatProvider chatProvider, User currentUser) {
    final peers = auth.getFriends();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0F6FC),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF30363D), height: 1),
              Expanded(
                child: peers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 44, color: Color(0xFF30363D)),
                            const SizedBox(height: 12),
                            const Text(
                              'No contacts found',
                              style: TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Search and connect with campus peers first!',
                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                                );
                              },
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Find People'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF238636),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: peers.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF21262D), height: 1),
                        itemBuilder: (c, idx) {
                          final peer = peers[idx];
                          return ListTile(
                            onTap: () {
                              Navigator.pop(ctx);
                              final room = chatProvider.startPersonalChat(
                                peerUser: peer,
                                currentUser: currentUser,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(roomId: room.id),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF21262D),
                              child: Text(
                                (peer.avatarUrl != null && peer.avatarUrl!.isNotEmpty) ? peer.avatarUrl! : '👤',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            title: Text(
                              peer.handle,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 14.5),
                            ),
                            subtitle: Text(
                              peer.name,
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                            ),
                            trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF58A6FF), size: 20),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: Text(
            'Please sign in to view your messages',
            style: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
      );
    }

    chatProvider.setCurrentUser(currentUser);

    final cleanCurrent = currentUser.username.toLowerCase().replaceAll('@', '').trim();

    // 1. Gather all active rooms (both direct and group)
    final Map<String, _UnifiedChatItem> itemMap = {};

    for (final room in chatProvider.rooms) {
      final lastMsg = chatProvider.getLastMessage(room.id);
      final hasLastMsg = lastMsg != null && lastMsg.content.trim().isNotEmpty;
      final lastText = hasLastMsg ? lastMsg.content : room.lastMessage;
      final lastTime = hasLastMsg ? _formatTimestamp(lastMsg.timestamp) : room.formattedTime;
      final dt = hasLastMsg ? lastMsg.timestamp : room.lastMessageTime;

      String displayTitle = room.title;
      String displaySubtitle = room.subtitle ?? (room.isGroup ? 'Group Chat' : 'Direct Message');

      if (!room.isGroup) {
        String otherUser = ChatProvider.getOtherUsernameFromDmRoomId(room.id, cleanCurrent) ?? '';
        if (otherUser.isEmpty) {
          if (room.title.startsWith('@')) {
            otherUser = room.title;
          } else if (room.subtitle != null && room.subtitle!.startsWith('@')) {
            otherUser = room.subtitle!;
          } else {
            otherUser = room.title;
          }
        }

        otherUser = otherUser.replaceAll('@', '').replaceAll('(', '').replaceAll(')', '').trim();
        otherUser = otherUser.replaceAll(RegExp(r'\s+chat\b', caseSensitive: false), '').trim();

        // Logical workflow: Show direct chat if friends OR if messages were exchanged!
        final isFriend = otherUser.isNotEmpty && authProvider.areFriends(otherUser);
        final hasActiveConversation = hasLastMsg || room.lastMessage.trim().isNotEmpty;
        if (!isFriend && !hasActiveConversation) {
          continue;
        }

        displayTitle = otherUser.isNotEmpty ? '@$otherUser' : room.title;
      } else {
        displayTitle = room.title.trim();
        if (displayTitle.toLowerCase().endsWith(' chat')) {
          displayTitle = displayTitle.substring(0, displayTitle.length - 5).trim();
        }
      }

      itemMap[room.id] = _UnifiedChatItem(
        roomId: room.id,
        title: displayTitle,
        subtitle: displaySubtitle,
        avatarText: room.avatarEmoji ?? (room.isGroup ? '💬' : '👤'),
        isGroup: room.isGroup,
        unreadCount: room.unreadCount,
        lastMessageText: lastText,
        lastMessageTime: lastTime,
        sortTime: dt,
        isOnline: room.isOnline,
      );
    }

    // 2. Also ensure all accepted friends have an entry so they can be tapped immediately
    for (final f in authProvider.getFriends()) {
      final clean = f.username.toLowerCase().replaceAll('@', '').trim();
      if (clean.isNotEmpty && clean != cleanCurrent) {
        final roomId = ChatProvider.getDirectRoomId(currentUser.username, f.username);
        if (!itemMap.containsKey(roomId)) {
          itemMap[roomId] = _UnifiedChatItem(
            roomId: roomId,
            title: '@$clean',
            subtitle: f.name.isNotEmpty ? f.name : 'Connected Peer',
            avatarText: (f.avatarUrl != null && f.avatarUrl!.isNotEmpty) ? f.avatarUrl! : '👤',
            isGroup: false,
            unreadCount: 0,
            lastMessageText: 'Say hello to @$clean 👋',
            lastMessageTime: '',
            sortTime: DateTime.fromMillisecondsSinceEpoch(0),
            isOnline: true,
          );
        }
      }
    }

    final allItems = itemMap.values.toList()
      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));

    final query = _searchQuery.toLowerCase().trim();
    final filteredItems = allItems.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          item.lastMessageText.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              '@${currentUser.username}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFFF0F6FC),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF8B949E)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF58A6FF), size: 26),
            tooltip: 'New Message',
            onPressed: () => _showNewChatSheet(context, authProvider, chatProvider, currentUser),
          ),
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: Color(0xFF8B949E), size: 22),
            tooltip: 'Search People',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8B949E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Search conversations or messages...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF8B949E)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // 2. Chat Conversations List
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState(context, allItems.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: Color(0xFF21262D),
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isUnread = item.unreadCount > 0;

                      return ListTile(
                        onTap: () {
                          chatProvider.markRoomAsRead(item.roomId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(roomId: item.roomId),
                            ),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF21262D),
                              child: Text(
                                item.avatarText,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            if (!item.isGroup && item.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF238636),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0D1117), width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  color: const Color(0xFFF0F6FC),
                                ),
                              ),
                            ),
                            if (item.lastMessageTime.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                item.lastMessageTime,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isUnread ? const Color(0xFF58A6FF) : const Color(0xFF6E7681),
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                  color: isUnread ? const Color(0xFFF0F6FC) : const Color(0xFF8B949E),
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF58A6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        tooltip: 'New Chat',
        onPressed: () => _showNewChatSheet(context, authProvider, chatProvider, currentUser),
        child: const Icon(Icons.chat_bubble_rounded),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool noChatsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 34, color: Color(0xFF58A6FF)),
            ),
            const SizedBox(height: 18),
            Text(
              noChatsAtAll ? 'No conversations yet' : 'No chats found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 8),
            Text(
              noChatsAtAll
                  ? 'Start a direct chat with your friends or search for classmates to begin messaging!'
                  : 'No conversations match "$_searchQuery".',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('Find People to Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _UnifiedChatItem {
  final String roomId;
  final String title;
  final String subtitle;
  final String avatarText;
  final bool isGroup;
  final int unreadCount;
  final String lastMessageText;
  final String lastMessageTime;
  final DateTime sortTime;
  final bool isOnline;

  _UnifiedChatItem({
    required this.roomId,
    required this.title,
    required this.subtitle,
    required this.avatarText,
    required this.isGroup,
    required this.unreadCount,
    required this.lastMessageText,
    required this.lastMessageTime,
    required this.sortTime,
    this.isOnline = true,
  });
}
