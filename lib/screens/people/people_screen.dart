import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/friend_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/friendship_service.dart';
import '../profile/user_profile_screen.dart';

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

  void _onSearchChanged(String query) async {
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
    if (!mounted) return;
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: const Text(
          'People & Campus Peers',
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
                        hintText: 'Search @username or classmate name...',
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
                ? _buildSearchResultsView()
                : _buildSuggestedPeersView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
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
        return _buildUserTile(_searchResults[index]);
      },
    );
  }

  Widget _buildSuggestedPeersView() {
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
              'Discover Classmates & Peers',
              style: TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search by @username above to connect with fellow students!',
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
            'SUGGESTED CAMPUS PEERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
              letterSpacing: 0.6,
            ),
          ),
        ),
        ..._suggestedUsers.map((u) => _buildUserTile(u)),
      ],
    );
  }

  Widget _buildUserTile(User user) {
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
                    user.campusOrCity,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
