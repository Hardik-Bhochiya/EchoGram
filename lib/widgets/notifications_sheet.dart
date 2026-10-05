import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_request.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat/chat_conversation_screen.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final Set<String> _processingIds = {};

  Future<void> _handleAccept(FriendRequest req) async {
    setState(() => _processingIds.add(req.id));
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;

    try {
      await auth.respondFriendRequest(
        req.id,
        'accepted',
        senderUsername: req.senderUsername,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF238636),
            content: Text('You and @${req.senderUsername} are now friends! 🎉'),
            action: SnackBarAction(
              label: 'Chat',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatConversationScreen(
                      roomId: ChatProvider.getDirectRoomId(currentUser?.username ?? 'user', req.senderUsername),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(req.id));
      }
    }
  }

  Future<void> _handleReject(FriendRequest req) async {
    setState(() => _processingIds.add(req.id));
    final auth = context.read<AuthProvider>();

    try {
      await auth.respondFriendRequest(
        req.id,
        'declined',
        senderUsername: req.senderUsername,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF21262D),
            content: Text('Rejected friend request from @${req.senderUsername}.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(req.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();
    final incomingRequests = auth.getPendingIncomingRequests();
    final systemNotifications = notifProvider.notifications;
    final totalUnread = incomingRequests.length + notifProvider.unreadCount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0F6FC),
                      ),
                    ),
                    if (totalUnread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF58A6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalUnread new',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (systemNotifications.isNotEmpty)
                  TextButton(
                    onPressed: () => notifProvider.markAllAsRead(),
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(color: Color(0xFF58A6FF), fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF30363D)),

          // Body
          Expanded(
            child: (incomingRequests.isEmpty && systemNotifications.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF8B949E), size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Notifications Right Now',
                          style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Friend requests & community alerts will appear here.',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Section 1: Friend Requests
                      if (incomingRequests.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_add_rounded, size: 16, color: Color(0xFF58A6FF)),
                                const SizedBox(width: 6),
                                Text(
                                  'Friend Requests (${incomingRequests.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B949E),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (incomingRequests.isNotEmpty)
                              InkWell(
                                onTap: () async {
                                  for (final req in List.from(incomingRequests)) {
                                    await _handleAccept(req);
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF21262D),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF238636)),
                                  ),
                                  child: const Text(
                                    'Accept All',
                                    style: TextStyle(
                                      color: Color(0xFF238636),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...incomingRequests.map((req) {
                          final isBusy = _processingIds.contains(req.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1117),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF30363D)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF21262D),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF58A6FF)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        req.senderAvatar ?? '👤',
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${req.senderName} sent you a friend request',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFFF0F6FC),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${req.senderUsername}',
                                            style: const TextStyle(
                                              color: Color(0xFF58A6FF),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isBusy ? null : () => _handleAccept(req),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF238636),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: isBusy
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check, size: 16),
                                                  SizedBox(width: 6),
                                                  Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isBusy ? null : () => _handleReject(req),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFF85149),
                                          side: const BorderSide(color: Color(0xFFF85149)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.close, size: 16),
                                            SizedBox(width: 6),
                                            Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // Section 2: General Notifications
                      if (systemNotifications.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF8B949E)),
                            SizedBox(width: 6),
                            Text(
                              'Activity & Updates',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B949E),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...systemNotifications.map((n) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: !n.isRead ? const Color(0xFF1F242C) : const Color(0xFF0D1117),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !n.isRead ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                                width: !n.isRead ? 1.2 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                notifProvider.markAsRead(n.id);
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF21262D),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(n.iconEmoji, style: const TextStyle(fontSize: 18)),
                              ),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: !n.isRead ? FontWeight.bold : FontWeight.w600,
                                  color: const Color(0xFFF0F6FC),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    n.message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8B949E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.timeAgo,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6E7681)),
                                  ),
                                ],
                              ),
                              trailing: !n.isRead
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF58A6FF),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
