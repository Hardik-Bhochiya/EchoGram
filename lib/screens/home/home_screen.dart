import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notifications_sheet.dart';
import '../people/people_screen.dart';
import '../community/communities_screen.dart';
import '../community/community_detail_screen.dart';
import '../chat/chat_conversation_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final user = auth.currentUser;

    final joinedCommunities = communityProvider.joinedCommunities;
    final allCommunities = communityProvider.communities;
    final displayCommunities = joinedCommunities.isNotEmpty ? joinedCommunities : allCommunities.take(3).toList();
    final recentChats = chatProvider.rooms.where((r) => !r.isCommunity).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF58A6FF)),
              ),
              alignment: Alignment.center,
              child: const Text('💬', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            const Text(
              'NearTalk',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF0F6FC)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFFF0F6FC), size: 24),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFF0F6FC), size: 24),
                onPressed: () => NotificationsSheet.show(context),
              ),
              Builder(
                builder: (context) {
                  final pendingReqs = auth.getPendingIncomingRequests().length;
                  final totalBadge = notifProvider.unreadCount + pendingReqs;
                  if (totalBadge <= 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF85149),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      alignment: Alignment.center,
                      child: Text(
                        '$totalBadge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Header
            Text(
              'Hello, ${user != null ? (user.firstName ?? user.name.split(" ").first) : "Friend"} 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF0F6FC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.campusOrCity.isNotEmpty == true ? user!.campusOrCity : 'Connect with campus peers & community chat',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
            ),
            const SizedBox(height: 22),

            // Card 1: People
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_outline_rounded, color: Color(0xFF58A6FF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'People',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF0F6FC)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Find and connect with classmates & peers',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF8B949E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PeopleScreen()),
                        );
                      },
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search People', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Communities
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Communities',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                        );
                      },
                      icon: const Icon(Icons.add, size: 15, color: Color(0xFF238636)),
                      label: const Text('Create', style: TextStyle(color: Color(0xFF238636), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                        );
                      },
                      child: const Text('Explore All', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (displayCommunities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.groups_outlined, size: 38, color: Color(0xFF8B949E)),
                    const SizedBox(height: 8),
                    const Text('No communities yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC))),
                    const SizedBox(height: 4),
                    const Text('Create the first space for your college or city!', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Community'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF58A6FF),
                        side: const BorderSide(color: Color(0xFF30363D)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...displayCommunities.map((c) => _buildCommunityTile(context, c)),

            const SizedBox(height: 24),

            // Section 3: Recent Chats (Friends only)
            const Text(
              'Recent Chats',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 10),

            if (recentChats.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Color(0xFF8B949E)),
                    const SizedBox(height: 8),
                    const Text('No direct chats yet', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC))),
                    const SizedBox(height: 4),
                    const Text('Add friends in People to start 1-on-1 private messaging.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentChats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final room = recentChats[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationScreen(roomId: room.id),
                          ),
                        );
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF21262D),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        alignment: Alignment.center,
                        child: Text(room.avatarEmoji ?? '💬', style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(
                        room.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 14.5),
                      ),
                      subtitle: Text(
                        room.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                      ),
                      trailing: Text(
                        room.formattedTime,
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityTile(BuildContext context, Community community) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: InkWell(
        onTap: () {
          if (community.isJoined) {
            final chatProvider = context.read<ChatProvider>();
            final room = chatProvider.getOrCreateCommunityRoom(
              community.id,
              community.name,
              community.iconEmoji,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationScreen(roomId: room.id),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(community: community),
              ),
            );
          }
        },
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              alignment: Alignment.center,
              child: Text(community.iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8B949E)),
                      const SizedBox(width: 3),
                      Text(
                        community.locationSpot,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${community.memberCount} members',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B949E)),
          ],
        ),
      ),
    );
  }
}
