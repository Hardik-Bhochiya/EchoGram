import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notifications_sheet.dart';
import '../community/communities_screen.dart';
import '../community/community_detail_screen.dart';
import '../chat/chat_conversation_screen.dart';
import '../chat/chat_list_screen.dart';
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
    final rawDisplay = joinedCommunities.isNotEmpty ? joinedCommunities : allCommunities.take(3);
    final Map<String, Community> uniqueMap = {};
    for (final c in rawDisplay) {
      uniqueMap[c.id] = c;
    }
    final displayCommunities = uniqueMap.values.toList();
    final recentChats = chatProvider.rooms;
    final totalUnreadChats = chatProvider.totalUnread;
    final pendingRequests = auth.getPendingIncomingRequests().length;
    final totalAlerts = notifProvider.unreadCount + pendingRequests;

    final displayName = user != null
        ? (user.firstName ?? user.name.split(' ').first)
        : 'Dhruv';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF58A6FF), Color(0xFF1F6FEB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'EchoGram',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Color(0xFFF0F6FC),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFFF0F6FC), size: 23),
            tooltip: 'Search People',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          // Notifications Bell Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFF0F6FC), size: 23),
                tooltip: 'Notifications',
                onPressed: () => NotificationsSheet.show(context),
              ),
              if (totalAlerts > 0)
                Positioned(
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
                      totalAlerts > 99 ? '99+' : '$totalAlerts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Direct Messages Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF0F6FC), size: 21),
                tooltip: 'Messages',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
              if (totalUnreadChats > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58A6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    alignment: Alignment.center,
                    child: Text(
                      totalUnreadChats > 99 ? '99+' : '$totalUnreadChats',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Welcome Card with Glass & Gradient Effect
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF161B22), Color(0xFF1F2430)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF30363D), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF58A6FF), Color(0xFF238636)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D1117),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                ? user.avatarUrl!
                                : '👤',
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Hello, $displayName 👋',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF0F6FC),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF58A6FF)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    (user?.majorOrBio != null && user!.majorOrBio!.isNotEmpty)
                                        ? user.majorOrBio!
                                        : 'Online • Daily Chat',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF238636).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF238636).withValues(alpha: 0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Color(0xFF3FB950), size: 7),
                            SizedBox(width: 5),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Color(0xFF3FB950),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Interactive Quick Stats Dashboard (4 Glassmorphic Tiles)
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.chat_bubble_rounded,
                    iconColor: const Color(0xFF58A6FF),
                    label: 'Chats',
                    value: '${recentChats.length}',
                    badge: totalUnreadChats > 0 ? '$totalUnreadChats new' : null,
                    badgeColor: const Color(0xFF58A6FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatListScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF238636),
                    label: 'My Groups',
                    value: '${joinedCommunities.length}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.person_search_rounded,
                    iconColor: const Color(0xFFA371F7),
                    label: 'Find Peers',
                    value: 'Search',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.notifications_active_rounded,
                    iconColor: const Color(0xFFF0883E),
                    label: 'Alerts',
                    value: '$totalAlerts',
                    badge: totalAlerts > 0 ? 'Pending' : null,
                    badgeColor: const Color(0xFFF85149),
                    onTap: () => NotificationsSheet.show(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Quick Action Buttons Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_search_rounded, size: 17),
                      label: const Text('Find People', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                        );
                      },
                      icon: const Icon(Icons.group_add_rounded, size: 17, color: Color(0xFF58A6FF)),
                      label: const Text('Join Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF58A6FF))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF30363D)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Communities / Groups Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Groups',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Text(
                        '${displayCommunities.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                    );
                  },
                  child: const Text(
                    'Explore All →',
                    style: TextStyle(color: Color(0xFF58A6FF), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
                    const Icon(Icons.groups_outlined, size: 36, color: Color(0xFF8B949E)),
                    const SizedBox(height: 8),
                    const Text(
                      'No groups yet',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 14.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Join or create a community to start group chatting!',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunitiesScreen(isTab: false)),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Explore Groups'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...displayCommunities.map((c) => _buildCommunityTile(context, c)),

            const SizedBox(height: 24),

            // 5. Recent Chats Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Recent Chats',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                    ),
                    if (totalUnreadChats > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF58A6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalUnreadChats unread',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    );
                  },
                  child: const Text(
                    'View All →',
                    style: TextStyle(color: Color(0xFF58A6FF), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                    const Text('No recent conversations', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC))),
                    const SizedBox(height: 4),
                    const Text('Find classmates and start 1-on-1 chatting!', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                      },
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Start Chatting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentChats.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final room = recentChats[index];
                  final isUnread = room.unreadCount > 0;
                  final cleanCurrent = (user?.username ?? '').toLowerCase().replaceAll('@', '').trim();
                  String displayTitle = room.name;
                  if (!room.isGroup) {
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
                      displayTitle = '@${room.name.toLowerCase().replaceAll(' ', '')}';
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: isUnread ? const Color(0xFF1F2430) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnread ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                        width: isUnread ? 1.2 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        chatProvider.markRoomAsRead(room.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationScreen(roomId: room.id),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF21262D),
                              border: Border.all(color: const Color(0xFF30363D)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              room.avatarEmoji ?? (room.isGroup ? '💬' : '👤'),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          if (!room.isGroup && room.isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF238636),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0D1117), width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        displayTitle,
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          color: const Color(0xFFF0F6FC),
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        room.lastMessage.isNotEmpty ? room.lastMessage : 'Tap to chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? const Color(0xFFF0F6FC) : const Color(0xFF8B949E),
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            room.formattedTime,
                            style: TextStyle(
                              color: isUnread ? const Color(0xFF58A6FF) : const Color(0xFF8B949E),
                              fontSize: 11,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF58A6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${room.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B949E), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          value,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: badgeColor ?? const Color(0xFF58A6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityTile(BuildContext context, Community community) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
              width: 44,
              height: 44,
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
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8B949E)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          community.locationSpot,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${community.memberCount} members',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: community.isJoined ? const Color(0xFF21262D) : const Color(0xFF238636),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: community.isJoined ? const Color(0xFF30363D) : const Color(0xFF238636),
                ),
              ),
              child: Text(
                community.isJoined ? 'Chat' : 'Join',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: community.isJoined ? const Color(0xFF58A6FF) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
