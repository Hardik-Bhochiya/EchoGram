import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community.dart';
import '../../models/user.dart';
import '../../models/question.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/user_service.dart';
import '../community/community_detail_screen.dart';
import '../question/question_detail_screen.dart';
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
  String _selectedFilter = 'All'; // 'All', 'Users', 'Communities', 'Questions'
  List<User> _remoteUsers = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _searchSession = 0;

  void _onSearchQueryChanged(String val, String? currentUserId) async {
    final sessionId = ++_searchSession;
    setState(() => _query = val);
    final clean = val.trim().replaceFirst(RegExp(r'^@'), '').trim();
    if (clean.isEmpty) {
      setState(() => _remoteUsers = []);
      return;
    }
    final results = await _userService.searchUsers(clean, currentUserId: currentUserId);
    if (mounted && sessionId == _searchSession) {
      setState(() => _remoteUsers = results);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final questionProvider = context.watch<QuestionProvider>();

    final user = auth.currentUser;
    final allCommunities = communityProvider.communities;
    final allQuestions = questionProvider.questions;
    final cleanQuery = _query.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

    List<User> matchedUsers = [];
    List<Community> matchedCommunities = [];
    List<Question> matchedQuestions = [];

    if (cleanQuery.isNotEmpty) {
      final Map<String, User> userMap = {};
      for (final ru in _remoteUsers) {
        if (user != null && ru.id == user.id) continue;
        userMap[ru.username.toLowerCase()] = ru;
      }
      for (final u in auth.knownUsers) {
        if (user != null && u.id == user.id) continue;
        if (u.username.toLowerCase().contains(cleanQuery) ||
            u.name.toLowerCase().contains(cleanQuery) ||
            u.campusOrCity.toLowerCase().contains(cleanQuery)) {
          userMap[u.username.toLowerCase()] = u;
        }
      }
      matchedUsers = userMap.values.toList();

      matchedCommunities = allCommunities.where((c) {
        return c.name.toLowerCase().contains(cleanQuery) ||
            c.category.toLowerCase().contains(cleanQuery) ||
            c.regionName.toLowerCase().contains(cleanQuery) ||
            c.description.toLowerCase().contains(cleanQuery);
      }).toList();

      matchedQuestions = allQuestions.where((q) {
        return q.title.toLowerCase().contains(cleanQuery) ||
            q.content.toLowerCase().contains(cleanQuery) ||
            q.communityName.toLowerCase().contains(cleanQuery);
      }).toList();
    }


    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
        title: const Text(
          'Search',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF0F6FC),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cleanQuery.isNotEmpty ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search classmates, communities, questions...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => _onSearchQueryChanged(val, user?.id),
                    ),
                  ),
                  if (cleanQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchQueryChanged('', user?.id);
                      },
                      child: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF8B949E)),
                    ),

                ],
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Users', 'Communities', 'Questions'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedFilter = filter),
                    backgroundColor: const Color(0xFF161B22),
                    selectedColor: const Color(0xFF21262D),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF8B949E),
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Color(0xFF21262D), height: 16),

          // Search Results
          Expanded(
            child: cleanQuery.isEmpty
                ? _buildEmptyState()
                : _buildResultsList(
                    matchedUsers: (_selectedFilter == 'All' || _selectedFilter == 'Users') ? matchedUsers : [],
                    matchedCommunities: (_selectedFilter == 'All' || _selectedFilter == 'Communities') ? matchedCommunities : [],
                    matchedQuestions: (_selectedFilter == 'All' || _selectedFilter == 'Questions') ? matchedQuestions : [],
                    auth: auth,
                    currentUser: user,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Icon(Icons.search_rounded, size: 36, color: Color(0xFF58A6FF)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search NearTalk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find friends by @username, explore campus groups, or search questions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF8B949E), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList({
    required List<User> matchedUsers,
    required List<Community> matchedCommunities,
    required List<Question> matchedQuestions,
    required AuthProvider auth,
    required User? currentUser,
  }) {
    if (matchedUsers.isEmpty && matchedCommunities.isEmpty && matchedQuestions.isEmpty) {
      return const Center(
        child: Text('No results found. Try another query.', style: TextStyle(color: Color(0xFF8B949E))),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Users
        if (matchedUsers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'PEOPLE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
            ),
          ),
          ...matchedUsers.map((u) {
            final isFriend = auth.areFriends(u.username);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF21262D),
                          child: Text(u.avatarUrl ?? '🎓', style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 13.5),
                              ),
                              Text(
                                '${u.handle} • ${u.campusOrCity}',
                                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        if (isFriend)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF21262D),
                              foregroundColor: const Color(0xFF58A6FF),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            child: const Text('Message', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF238636),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            child: const Text('Connect', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Communities
        if (matchedCommunities.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'COMMUNITIES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
            ),
          ),
          ...matchedCommunities.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(c.iconEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 13.5),
                        ),
                        Text(
                          '${c.regionName} • ${c.memberCount} members',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (c.isJoined) {
                        final chatProvider = context.read<ChatProvider>();
                        final room = chatProvider.getOrCreateCommunityRoom(c.id, c.name, c.iconEmoji);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatConversationScreen(roomId: room.id)),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: c.id)),
                        );
                      }
                    },
                    child: Text(c.isJoined ? 'Chat' : 'View', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Questions
        if (matchedQuestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'QUESTIONS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
            ),
          ),
          ...matchedQuestions.map((q) {
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QuestionDetailScreen(questionId: q.id)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC), fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${q.communityName} • ${q.upvotes} upvotes • ${q.replies.length} replies',
                      style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
