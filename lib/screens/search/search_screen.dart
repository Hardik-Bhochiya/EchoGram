import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/user_service.dart';
import '../profile/user_profile_screen.dart';
import '../chat/chat_conversation_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final UserService _userService = UserService();
  String _query = '';
  List<User> _remoteUsers = [];
  List<User> _suggestedUsers = [];
  bool _isLoading = false;
  int _searchSession = 0;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers() async {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;
    final currentUsername = auth.currentUser?.username;
    try {
      final list = await _userService.getSuggestedUsers(
        currentUserId: currentUserId,
        currentUsername: currentUsername,
      );
      if (mounted) {
        setState(() => _suggestedUsers = list);
      }
    } catch (_) {}
  }

  void _onSearchQueryChanged(String val, String? currentUserId, String? currentUsername) async {
    final sessionId = ++_searchSession;
    setState(() {
      _query = val;
      _isLoading = val.trim().isNotEmpty;
    });

    final clean = val.trim().replaceFirst(RegExp(r'^@'), '').trim();
    if (clean.isEmpty) {
      setState(() {
        _remoteUsers = [];
        _isLoading = false;
      });
      return;
    }

    final results = await _userService.searchUsers(
      clean,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
    );
    if (mounted && sessionId == _searchSession) {
      setState(() {
        _remoteUsers = results;
        _isLoading = false;
      });
    }
  }

  bool _isSelf(User u, User? currentUser) {
    if (currentUser == null) return false;
    final myUid = currentUser.id.trim().toLowerCase();
    final myUname = currentUser.username.trim().toLowerCase().replaceAll('@', '');
    final uId = u.id.trim().toLowerCase();
    final uUname = u.username.trim().toLowerCase().replaceAll('@', '');

    return (myUid.isNotEmpty && uId.isNotEmpty && myUid == uId) ||
        (myUname.isNotEmpty && uUname.isNotEmpty && myUname == uUname) ||
        (myUname.isNotEmpty && uId == 'user_$myUname');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;
    final cleanQuery = _query.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

    final Map<String, User> userMap = {};
    if (cleanQuery.isNotEmpty) {
      for (final ru in _remoteUsers) {
        if (_isSelf(ru, currentUser)) continue;
        userMap[ru.username.toLowerCase()] = ru;
      }
      for (final u in auth.knownUsers) {
        if (_isSelf(u, currentUser)) continue;
        if (u.username.toLowerCase().contains(cleanQuery) ||
            u.name.toLowerCase().contains(cleanQuery) ||
            u.campusOrCity.toLowerCase().contains(cleanQuery)) {
          userMap[u.username.toLowerCase()] = u;
        }
      }
    }

    final matchedUsers = userMap.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
        title: const Text(
          'Find People',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF0F6FC),
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cleanQuery.isNotEmpty ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 21, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14.5),
                      decoration: const InputDecoration(
                        hintText: 'Search people by name or @username...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => _onSearchQueryChanged(val, currentUser?.id, currentUser?.username),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
                    )
                  else if (cleanQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchQueryChanged('', currentUser?.id, currentUser?.username);
                      },
                      child: const Icon(Icons.cancel_rounded, size: 19, color: Color(0xFF8B949E)),
                    ),
                ],
              ),
            ),
          ),

          const Divider(color: Color(0xFF21262D), height: 1),

          // 2. Body List
          Expanded(
            child: cleanQuery.isEmpty
                ? _buildDiscoveryView(auth, currentUser)
                : _buildSearchResultsView(matchedUsers, auth, currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryView(AuthProvider auth, User? currentUser) {
    // Combine suggested remote users with local known users, strictly excluding self
    final Map<String, User> discoverMap = {};
    for (final u in _suggestedUsers) {
      if (_isSelf(u, currentUser)) continue;
      discoverMap[u.username.toLowerCase()] = u;
    }
    for (final u in auth.knownUsers) {
      if (_isSelf(u, currentUser)) continue;
      discoverMap[u.username.toLowerCase()] = u;
    }

    final discoverList = discoverMap.values.toList();

    if (discoverList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF58A6FF)),
              ),
              const SizedBox(height: 18),
              const Text(
                'No other users registered yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
              ),
              const SizedBox(height: 6),
              const Text(
                'New users who register will appear here automatically so you can see their profile and send requests!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8B949E), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF58A6FF)),
            const SizedBox(width: 6),
            const Text(
              'ALL USERS IN DATABASE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
            ),
            const Spacer(),
            Text(
              '${discoverList.length} users',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6E7681)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...discoverList.map((u) => _buildUserCard(u, auth, currentUser)),
      ],
    );
  }

  Widget _buildSearchResultsView(List<User> users, AuthProvider auth, User? currentUser) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, size: 44, color: Color(0xFF30363D)),
              const SizedBox(height: 14),
              const Text(
                'No people found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
              ),
              const SizedBox(height: 6),
              Text(
                'No user matched "$_query". Check the spelling or try searching another name.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'SEARCH RESULTS (${users.length})',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
          ),
        ),
        ...users.map((u) => _buildUserCard(u, auth, currentUser)),
      ],
    );
  }

  Widget _buildUserCard(User u, AuthProvider auth, User? currentUser) {
    final isFriend = auth.areFriends(u.username);
    final isOutgoing = auth.isPendingOutgoing(u.username);
    final isIncoming = auth.isPendingIncoming(u.username);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with Verification Indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF21262D),
                      child: Text(
                        (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) ? u.avatarUrl! : '👤',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    if (u.isCollegeVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF238636),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name & Handle (Show ID / @username prominently)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${u.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF0F6FC),
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${u.name.isNotEmpty ? u.name : "Member"} • ${u.campusOrCity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                      if (u.majorOrBio != null && u.majorOrBio!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          u.majorOrBio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action Buttons: (See) and (Request)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // (See) Profile Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF58A6FF),
                        side: const BorderSide(color: Color(0xFF30363D)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      child: const Text('See', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // Direct Message Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF21262D),
                        foregroundColor: const Color(0xFF58A6FF),
                        side: const BorderSide(color: Color(0xFF30363D)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (currentUser == null) return;
                        final chatProvider = context.read<ChatProvider>();
                        final room = chatProvider.startPersonalChat(peerUser: u, currentUser: currentUser);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatConversationScreen(roomId: room.id)),
                        );
                      },
                      child: const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // (Friend Request / Status) Button
                    if (isFriend)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF238636)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Color(0xFF238636)),
                            SizedBox(width: 4),
                            Text('Friends', style: TextStyle(fontSize: 11.5, color: Color(0xFF238636), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (isOutgoing)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B949E),
                          side: const BorderSide(color: Color(0xFF30363D)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: null,
                        child: const Text('Requested', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    else if (isIncoming)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              final incoming = auth.getIncomingRequestFrom(u.username);
                              if (incoming != null) {
                                await auth.respondFriendRequest(
                                  incoming.id,
                                  'accepted',
                                  senderUsername: incoming.senderUsername,
                                );
                              }
                              if (mounted) setState(() {});
                            },
                            child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDA3633),
                              side: const BorderSide(color: Color(0xFFDA3633)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final incoming = auth.getIncomingRequestFrom(u.username);
                              if (incoming != null) {
                                await auth.respondFriendRequest(
                                  incoming.id,
                                  'declined',
                                  senderUsername: incoming.senderUsername,
                                );
                              }
                              if (mounted) setState(() {});
                            },
                            child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    else
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
                          final success = await auth.sendFriendRequest(u.username);
                          if (mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Friend request sent to @${u.username}! 🤝'),
                                backgroundColor: const Color(0xFF238636),
                              ),
                            );
                            setState(() {});
                          }
                        },
                        child: const Text('Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
