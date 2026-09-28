import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/community_provider.dart';
import '../community/communities_screen.dart';
import '../people/people_screen.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final commProvider = context.read<CommunityProvider>();
      final chatProvider = context.read<ChatProvider>();
      for (final c in commProvider.joinedCommunities) {
        chatProvider.getOrCreateCommunityRoom(c.id, c.name, c.iconEmoji);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getPeerUsername(ChatRoom room, String currentUsername) {
    final cleanCurrent = currentUsername.trim().toLowerCase().replaceAll('@', '');
    if (room.id.startsWith('dm-')) {
      final parts = room.id.substring(3).split('_');
      if (parts.length == 2) {
        final p1 = parts[0].toLowerCase();
        final p2 = parts[1].toLowerCase();
        if (p1 == cleanCurrent) return p2;
        if (p2 == cleanCurrent) return p1;
      }
    }
    if (room.subtitle != null && room.subtitle!.startsWith('@')) {
      return room.subtitle!.substring(1).trim().toLowerCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    final joinedComms = communityProvider.joinedCommunities;
    final joinedCommIds = joinedComms.map((c) => c.id).toSet();

    // Only include:
    // 1. Joined community chats
    // 2. Personal chats where the peer is an accepted friend
    final eligibleRooms = chatProvider.rooms.where((r) {
      if (r.isGroup || r.communityId != null) {
        return joinedCommIds.contains(r.communityId) ||
            joinedComms.any((c) => r.id == 'room-${c.id}');
      } else {
        if (currentUser == null) return false;
        final peerUsername = _getPeerUsername(r, currentUser.username);
        if (peerUsername == null || peerUsername.isEmpty) return false;
        return authProvider.areFriends(peerUsername);
      }
    }).toList();

    final filteredRooms = eligibleRooms.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF0F6FC)),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
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
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8B949E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Search chats...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF8B949E)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // Chats List or Empty State
          Expanded(
            child: filteredRooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF30363D)),
                          const SizedBox(height: 12),
                          const Text(
                            'No chats yet',
                            style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Chats appear here for communities you have joined and friends you have added.',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
                                  );
                                },
                                icon: const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF58A6FF)),
                                label: const Text('Communities', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF30363D)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PeopleScreen()),
                                  );
                                },
                                icon: const Icon(Icons.person_search_rounded, size: 16),
                                label: const Text('Find Friends', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF238636),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )

                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filteredRooms.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF21262D), height: 1),
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(roomId: room.id),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF21262D),
                          child: Text(
                            (room.avatarEmoji != null && room.avatarEmoji!.isNotEmpty)
                                ? room.avatarEmoji!
                                : (room.isGroup ? '💬' : '👤'),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF0F6FC),
                          ),
                        ),
                        subtitle: Text(
                          room.lastMessage.isNotEmpty ? room.lastMessage : 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              room.formattedTime,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                            ),
                            if (room.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF238636),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${room.unreadCount}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
    );
  }
}
