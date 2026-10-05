import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/friend_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/friendship_service.dart';
import '../profile/user_profile_screen.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_conversation_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final UserService _userService = UserService();
  final FriendshipService _friendshipService = FriendshipService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSearching = false;
  List<User> _searchResults = [];
  List<User> _suggestedUsers = [];
  bool _isLoadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final users = await _userService.getSuggestedUsers(currentUserId: currentUserId, limit: 12);
    if (!mounted) return;
    setState(() {
      _suggestedUsers = users;
      _isLoadingSuggestions = false;
    });
  }

  int _searchSession = 0;

  void _onSearchChanged(String query) async {
    final sessionId = ++_searchSession;
    setState(() {
      _searchQuery = query;
      _isSearching = query.trim().isNotEmpty;
    });

    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final results = await _userService.searchUsers(query, currentUserId: currentUserId);
    if (!mounted || sessionId != _searchSession) return;
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: const Text(
          'People & Contacts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF0F6FC)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B949E)),
            onPressed: () {
              setState(() => _isLoadingSuggestions = true);
              _loadSuggestions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search @username or name...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8B949E)),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
            ),
          ),

          // 2. Incoming Requests Banner (if any)
          if (currentUser != null)
            StreamBuilder<List<FriendRequest>>(
              stream: _friendshipService.streamPendingIncomingRequests(currentUser.id),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? [];
                if (pending.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF60A5FA), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${pending.length} pending friend ${pending.length == 1 ? "request" : "requests"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF0F6FC)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showRequestsSheet(context, pending, currentUser),
                        child: const Text('View All', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),

          // 3. User List / Search Results
          Expanded(
            child: _isSearching
                ? _buildSearchResultsView(auth, currentUser)
                : _buildSuggestedPeersView(auth, currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView(AuthProvider auth, User? currentUser) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_rounded, size: 48, color: Color(0xFF30363D)),
            const SizedBox(height: 12),
            Text(
              'No users found matching "$_searchQuery"',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try searching by exact @username or real name.',
              style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF21262D), height: 1),
      itemBuilder: (context, index) {
        return _buildUserTile(_searchResults[index], auth, currentUser);
      },
    );
  }

  Widget _buildSuggestedPeersView(AuthProvider auth, User? currentUser) {
    if (_isLoadingSuggestions) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF30363D)),
            const SizedBox(height: 12),
            const Text(
              'Discover People',
              style: TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search by @username above to connect with friends!',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            'SUGGESTED CONTACTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
              letterSpacing: 0.6,
            ),
          ),
        ),
        ..._suggestedUsers.map((u) => _buildUserTile(u, auth, currentUser)),
      ],
    );
  }

  Widget _buildUserTile(User user, AuthProvider auth, User? currentUser) {
    final isFriend = auth.areFriends(user.username);
    final isOutgoing = auth.isPendingOutgoing(user.username);
    final isIncoming = auth.isPendingIncoming(user.username);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              alignment: Alignment.center,
              child: Text(
                user.avatarUrl ?? '👤',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF0F6FC),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isCollegeVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF238636)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.handle,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF58A6FF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (user.majorOrBio != null && user.majorOrBio!.isNotEmpty)
                        ? user.majorOrBio!
                        : (user.campusOrCity.isNotEmpty ? user.campusOrCity : 'EchoGram User'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action Buttons
            if (isFriend) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (currentUser == null) return;
                  final chatProvider = context.read<ChatProvider>();
                  final room = chatProvider.startPersonalChat(peerUser: user, currentUser: currentUser);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatConversationScreen(roomId: room.id)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 13),
                label: const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ] else if (isOutgoing) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD29922),
                  side: const BorderSide(color: Color(0xFFD29922)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await auth.cancelFriendRequest(user.username);
                },
                icon: const Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFFD29922)),
                label: const Text('Requested', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ] else if (isIncoming) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final incoming = auth.getIncomingRequestFrom(user.username);
                  if (incoming != null) {
                    await auth.respondFriendRequest(incoming.id, 'accepted', senderUsername: incoming.senderUsername);
                  }
                },
                child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDA3633),
                  side: const BorderSide(color: Color(0xFFDA3633)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final incoming = auth.getIncomingRequestFrom(user.username);
                  if (incoming != null) {
                    await auth.respondFriendRequest(incoming.id, 'declined', senderUsername: incoming.senderUsername);
                  }
                },
                child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final success = await auth.sendFriendRequest(user.username);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Friend request sent to @${user.username}! 🤝'),
                        backgroundColor: const Color(0xFF238636),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.person_add_rounded, size: 14),
                label: const Text('Add Friend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF484F58), size: 20),
          ],
        ),
      ),
    );
  }

  void _showRequestsSheet(BuildContext context, List<FriendRequest> requests, User currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF30363D))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Friend Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final req = requests[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      children: [
                        Text(req.senderAvatar ?? '👤', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC))),
                              Text('@${req.senderUsername}', style: const TextStyle(fontSize: 12, color: Color(0xFF58A6FF))),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _friendshipService.acceptFriendRequest(req, currentUser);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF238636),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Accept', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8B949E)),
                          onPressed: () async {
                            await _friendshipService.declineFriendRequest(req.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
