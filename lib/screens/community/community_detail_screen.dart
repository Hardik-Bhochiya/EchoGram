import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community.dart';
import '../../providers/community_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_conversation_screen.dart';

class CommunityDetailScreen extends StatelessWidget {
  final Community? community;
  final String? communityId;

  const CommunityDetailScreen({
    super.key,
    this.community,
    this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final targetId = community?.id ?? communityId ?? '';
    final liveCommunity = communityProvider.getCommunityById(targetId) ?? community;

    if (liveCommunity == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Community'),
        ),
        body: const Center(
          child: Text('Community not found', style: TextStyle(color: Color(0xFF8B949E))),
        ),
      );
    }

    final isJoined = liveCommunity.isJoined;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: Text(
          liveCommunity.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFFF0F6FC)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              alignment: Alignment.center,
              child: Text(liveCommunity.iconEmoji, style: const TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              liveCommunity.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Location Spot
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF8B949E)),
                const SizedBox(width: 4),
                Text(
                  liveCommunity.locationSpot,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Member Count (NO online indicator)
            Text(
              '${liveCommunity.memberCount} members',
              style: const TextStyle(fontSize: 13, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),

            // Description Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ABOUT COMMUNITY',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    liveCommunity.description,
                    style: const TextStyle(fontSize: 14, color: Color(0xFFC9D1D9), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (!isJoined)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    communityProvider.toggleJoinCommunity(liveCommunity.id);
                    final chatProvider = context.read<ChatProvider>();
                    chatProvider.getOrCreateCommunityRoom(
                      liveCommunity.id,
                      liveCommunity.name,
                      liveCommunity.iconEmoji,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Joined ${liveCommunity.name}! 🎉'),
                        backgroundColor: const Color(0xFF238636),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('Join Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else ...[
              // Already joined: Enter Chat & Joined state
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final chatProvider = context.read<ChatProvider>();
                    final room = chatProvider.getOrCreateCommunityRoom(
                      liveCommunity.id,
                      liveCommunity.name,
                      liveCommunity.iconEmoji,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationScreen(roomId: room.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text('Enter Community Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: () {
                    communityProvider.toggleJoinCommunity(liveCommunity.id);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Leave Community', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
