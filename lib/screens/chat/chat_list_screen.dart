import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final rooms = chatProvider.rooms;

    final filteredRooms = rooms.where((r) {
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
                            'Personal chat is unlocked when you and a peer become accepted friends.',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PeopleScreen()),
                              );
                            },
                            icon: const Icon(Icons.person_search_rounded, size: 18),
                            label: const Text('Find Friends in People'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF238636),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
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
