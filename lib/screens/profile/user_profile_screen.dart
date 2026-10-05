import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/friendship_service.dart';
import '../chat/chat_conversation_screen.dart';


class UserProfileScreen extends StatefulWidget {
  final User user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  bool _isActionInProgress = false;

  RelationshipState _getRelationship(AuthProvider auth) {
    final currentUser = auth.currentUser;
    if (currentUser == null) return RelationshipState.none;

    final myClean = currentUser.username.toLowerCase().replaceAll('@', '').trim();
    final targetClean = widget.user.username.toLowerCase().replaceAll('@', '').trim();

    if (currentUser.id == widget.user.id || myClean == targetClean) {
      return RelationshipState.self;
    }

    if (auth.areFriends(targetClean)) {
      return RelationshipState.friends;
    }

    if (auth.isPendingOutgoing(targetClean)) {
      return RelationshipState.pendingOutgoing;
    }

    if (auth.isPendingIncoming(targetClean)) {
      return RelationshipState.pendingIncoming;
    }

    return RelationshipState.none;
  }

  Future<void> _handleSendRequest() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isActionInProgress = true);
    try {
      // 1. Multi-tier friend request through AuthProvider
      await auth.sendFriendRequest(widget.user.username);

      // 2. Also register in Firebase Firestore if initialized
      if (_friendshipService.isFirebaseInitialized) {
        try {
          await _friendshipService.sendFriendRequest(currentUser, widget.user);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF238636),
            content: Text('Friend request sent to @${widget.user.username}! 🚀'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF85149),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _handleCancelRequest() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isActionInProgress = true);
    try {
      await auth.cancelFriendRequest(widget.user.username);
      if (_friendshipService.isFirebaseInitialized) {
        try {
          await _friendshipService.cancelFriendRequest(currentUser.id, widget.user.id);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request cancelled.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleAcceptRequest() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isActionInProgress = true);
    try {
      final incoming = auth.getIncomingRequestFrom(widget.user.username);
      if (incoming != null) {
        await auth.respondFriendRequest(
          incoming.id,
          'accepted',
          senderUsername: incoming.senderUsername,
        );
      }

      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF238636),
            content: Text('You and @${widget.user.username} are now friends! 🤝'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleDeclineRequest() async {
    final auth = context.read<AuthProvider>();
    setState(() => _isActionInProgress = true);
    try {
      final incoming = auth.getIncomingRequestFrom(widget.user.username);
      if (incoming != null) {
        await auth.respondFriendRequest(
          incoming.id,
          'declined',
          senderUsername: incoming.senderUsername,
        );
      }
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _openDirectChat() {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    final chatProvider = context.read<ChatProvider>();
    final room = chatProvider.startPersonalChat(peerUser: widget.user, currentUser: currentUser);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          roomId: room.id,
        ),
      ),
    );
  }

  Future<void> _handleUnfriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text('Unfriend User', style: TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to unfriend @${widget.user.username}?', style: const TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();

    setState(() => _isActionInProgress = true);
    try {
      await auth.unfriend(widget.user.username);
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF21262D),
            content: Text('Unfriended @${widget.user.username}.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSelf = auth.currentUser != null &&
        (auth.currentUser!.id == widget.user.id ||
            auth.currentUser!.username.toLowerCase().replaceAll('@', '') ==
                widget.user.username.toLowerCase().replaceAll('@', ''));
    final user = isSelf ? auth.currentUser! : widget.user;
    final relState = _getRelationship(auth);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: Text(
          '@${user.username}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFFF0F6FC)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF8B949E)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Avatar + Name + Campus Header
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF21262D),
                      border: Border.all(color: const Color(0xFF58A6FF), width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.avatarUrl ?? '👤',
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                  if (user.isCollegeVerified)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF238636),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text(
              user.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 4),
            Text(
              user.handle,
              style: const TextStyle(fontSize: 14, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8B949E)),
                const SizedBox(width: 4),
                Text(
                  user.campusOrCity,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Relationship State Action Button
            _buildRelationshipActionButton(relState),
            const SizedBox(height: 24),

            // Bio / About Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ABOUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B949E),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.majorOrBio ?? 'No bio shared yet.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFFC9D1D9), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Clean Necessary Profile Details
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'LOCATION',
                    val: user.campusOrCity.isNotEmpty ? user.campusOrCity : 'DDU, Nadiad',
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFF58A6FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    title: 'STATUS',
                    val: user.isCollegeVerified ? 'Verified Student' : 'Community Member',
                    icon: user.isCollegeVerified ? Icons.verified_rounded : Icons.person_outline_rounded,
                    iconColor: user.isCollegeVerified ? const Color(0xFF238636) : const Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipActionButton(RelationshipState relState) {
    if (_isActionInProgress) {
      return Container(
        height: 44,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
        ),
      );
    }

    switch (relState) {
      case RelationshipState.self:
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.person_rounded, size: 17, color: Color(0xFF58A6FF)),
            label: const Text('This is your profile (Edit in Profile tab)',
                style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF30363D)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF161B22),
            ),
          ),
        );

      case RelationshipState.friends:
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _openDirectChat,
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _handleUnfriend,
                  icon: const Icon(Icons.person_remove_rounded, size: 17, color: Color(0xFFF85149)),
                  label: const Text('Unfriend', style: TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDA3633), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        );


      case RelationshipState.pendingOutgoing:
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _handleCancelRequest,
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFF85149)),
            label: const Text('Cancel Request', style: TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF85149)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case RelationshipState.pendingIncoming:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleAcceptRequest,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleDeclineRequest,
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFF85149)),
                label: const Text('Reject', style: TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDA3633)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );

      case RelationshipState.none:
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _handleSendRequest,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58A6FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String val,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
