import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/community_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'community_detail_screen.dart';
import '../chat/chat_conversation_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  final bool isTab;
  const CommunitiesScreen({super.key, this.isTab = true});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  final List<String> _categories = [
    'All',
    'Tech & Dev',
    'Students',
    'Sports',
    'Startups',
    'Cultural',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';
      context.read<CommunityProvider>().refreshCommunities(userIdentifier: currentUserId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDeleteCommunity(Community community) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final currentUsername = auth.currentUser?.username ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDA3633), size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Community?',
              style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${community.name}"? This action is permanent and will remove the group for everyone.',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = context.read<CommunityProvider>().deleteCommunity(
                community.id,
                currentUserId,
                currentUsername: currentUsername,
              );
              if (deleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${community.name}" community'),
                    backgroundColor: const Color(0xFFDA3633),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveCommunity(Community community) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded, color: Color(0xFFE3B341), size: 22),
            const SizedBox(width: 8),
            Text(
              'Leave ${community.isGroupType ? 'Group' : 'Community'}?',
              style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to leave "${community.name}"?',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CommunityProvider>().toggleJoinCommunity(community.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You left "${community.name}".'),
                  backgroundColor: const Color(0xFF30363D),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              foregroundColor: const Color(0xFFF85149),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showCreateCommunityDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController(text: 'DDU Nadiad, Gujarat');
    final descController = TextEditingController();
    final rulesController = TextEditingController(
      text: '1. Treat all members with respect and courtesy.\n2. No abusive language, harassment, or hate speech.\n3. No commercial spam or unauthorized promotions.\n4. Keep discussions genuine and relevant.',
    );

    bool isGroup = _tabController.index == 0;
    String selectedCategory = 'Tech & Dev';
    String selectedEmoji = isGroup ? '👥' : '🏛️';
    final emojis = ['👥', '💻', '📚', '🚀', '📸', '🏏', '🎓', '🎭', '🏛️', '⚽'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF161B22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isGroup ? 'Create New Group' : 'Create New Community',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF0F6FC),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Type Toggle: Group or Community
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() {
                                isGroup = true;
                                selectedEmoji = '👥';
                              }),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isGroup ? const Color(0xFF21262D) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: isGroup ? const Color(0xFF58A6FF) : Colors.transparent,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.groups_rounded, size: 16, color: isGroup ? const Color(0xFF58A6FF) : const Color(0xFF8B949E)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Group',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isGroup ? const Color(0xFFF0F6FC) : const Color(0xFF8B949E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() {
                                isGroup = false;
                                selectedEmoji = '🏛️';
                              }),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isGroup ? const Color(0xFF21262D) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: !isGroup ? const Color(0xFF58A6FF) : Colors.transparent,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.apartment_rounded, size: 16, color: !isGroup ? const Color(0xFF58A6FF) : const Color(0xFF8B949E)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Community',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: !isGroup ? const Color(0xFFF0F6FC) : const Color(0xFF8B949E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Choose Icon
                    Text(
                      '${isGroup ? 'Group' : 'Community'} Icon',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: emojis.map((e) {
                        final isSel = selectedEmoji == e;
                        return InkWell(
                          onTap: () => setModalState(() => selectedEmoji = e),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF21262D) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                              ),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 2. Name (Text box)
                    CustomTextField(
                      controller: nameController,
                      labelText: '${isGroup ? 'Group' : 'Community'} Name',
                      hintText: isGroup ? 'e.g. Pune Coders, Robotics Club' : 'e.g. DDU Students Community, Ahmedabad Tech',
                    ),
                    const SizedBox(height: 12),

                    // 3. Location (Direct Text box)
                    CustomTextField(
                      controller: locationController,
                      labelText: 'Location',
                      hintText: 'Enter location (e.g. DDU Nadiad, Ahmedabad, Library)',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),

                    // 4. Rules & Regulations (Direct Text box)
                    CustomTextField(
                      controller: rulesController,
                      labelText: 'Rules & Regulations',
                      hintText: 'Enter rules and regulations (one per line)...',
                      maxLines: 4,
                      prefixIcon: Icons.rule_rounded,
                    ),
                    const SizedBox(height: 12),

                    // 5. Description (Optional)
                    CustomTextField(
                      controller: descController,
                      labelText: 'Description (Optional)',
                      hintText: isGroup ? 'What is this group about?' : 'What is this community about?',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // 6. Category
                    const Text(
                      'Category',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: const Color(0xFF21262D),
                      style: const TextStyle(color: Color(0xFFF0F6FC)),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: _categories
                          .where((c) => c != 'All')
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    PrimaryButton(
                      text: isGroup ? 'Create Group' : 'Create Community',
                      onPressed: () {
                        final gName = nameController.text.trim();
                        final gLoc = locationController.text.trim().isNotEmpty
                            ? locationController.text.trim()
                            : 'General';

                        if (gName.isNotEmpty) {
                          final currentUserId = ctx.read<AuthProvider>().currentUser?.id ?? '';

                          final rawRules = rulesController.text.trim();
                          final rulesList = rawRules.isNotEmpty
                              ? rawRules
                                  .split('\n')
                                  .map((r) => r.trim())
                                  .where((r) => r.isNotEmpty)
                                  .toList()
                              : [
                                  'Respect all group members.',
                                  'No spam or promotions.',
                                  'Keep discussions constructive and safe.',
                                ];

                          final created = ctx.read<CommunityProvider>().createCommunity(
                            name: gName,
                            description: descController.text.trim().isNotEmpty
                                ? descController.text.trim()
                                : '$gName ${isGroup ? 'group' : 'community'} discussions and peer updates',
                            category: isGroup ? selectedCategory : 'Community',
                            iconEmoji: selectedEmoji,
                            bannerColorHex: 0xFF58A6FF,
                            regionName: gLoc,
                            locationSpot: gLoc,
                            creatorId: currentUserId,
                            isGroupType: isGroup,
                            rules: rulesList,
                          );

                          ctx.read<ChatProvider>().getOrCreateCommunityRoom(
                            created.id,
                            created.name,
                            created.iconEmoji,
                          );

                          Navigator.pop(ctx);
                          _tabController.animateTo(isGroup ? 0 : 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Created ${isGroup ? 'group' : 'community'} "$gName" in $gLoc! 🎉'),
                              backgroundColor: const Color(0xFF238636),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';

    final allCommunities = communityProvider.communities.where((c) {
      final matchesCategory = communityProvider.selectedCategory == 'All' || c.category == communityProvider.selectedCategory;
      final query = communityProvider.searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.locationSpot.toLowerCase().contains(query) ||
          c.regionName.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    final groupsList = allCommunities.where((c) => c.isGroupType).toList();
    final communitiesList = allCommunities.where((c) => !c.isGroupType).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        titleSpacing: widget.isTab ? 16 : 0,
        title: const Text(
          'Groups & Communities',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFFF0F6FC),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showCreateCommunityDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF58A6FF)),
              ),
              labelColor: const Color(0xFFF0F6FC),
              unselectedLabelColor: const Color(0xFF8B949E),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Groups (${groupsList.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Communities (${communitiesList.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [

          // 2. Search Field by Name or Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: communityProvider.searchQuery.isNotEmpty ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
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
                      onChanged: (val) => communityProvider.setSearchQuery(val),
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or location...',
                        hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (communityProvider.searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        communityProvider.setSearchQuery('');
                      },
                      child: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF8B949E)),
                    ),
                ],
              ),
            ),
          ),

          // 3. Category horizontal chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = communityProvider.selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: const Color(0xFF21262D),
                  backgroundColor: const Color(0xFF161B22),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFFF0F6FC) : const Color(0xFF8B949E),
                  ),
                  onSelected: (_) => communityProvider.selectCategory(cat),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // 4. Tab Views: Tab 0 = Groups, Tab 1 = Communities
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 0: GROUPS
                groupsList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: const Center(
                                  child: Text('👥', style: TextStyle(fontSize: 26)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Groups Found',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create a group to start discussions with friends!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF8B949E)),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _showCreateCommunityDialog,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text('Create Group'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF238636),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: groupsList.length,
                        itemBuilder: (context, index) {
                          final community = groupsList[index];
                          final cleanCreator = community.creatorId.toLowerCase().replaceAll('@', '').trim();
                          final cleanUid = currentUserId.toLowerCase().replaceAll('@', '').trim();
                          final cleanUname = (auth.currentUser?.username ?? '').toLowerCase().replaceAll('@', '').trim();
                          final isCreator = cleanCreator.isNotEmpty &&
                              cleanUid.isNotEmpty &&
                              (cleanCreator == cleanUid || (cleanUname.isNotEmpty && cleanCreator == cleanUname));
                          return CommunityCard(
                            community: community,
                            onDelete: isCreator ? () => _confirmDeleteCommunity(community) : null,
                            onChatTap: () {
                              final chatProvider = context.read<ChatProvider>();
                              final room = chatProvider.getOrCreateCommunityRoom(
                                community.id,
                                community.name,
                                community.iconEmoji,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(roomId: room.id),
                                ),
                              );
                            },
                            onTap: () {
                              if (community.isJoined) {
                                final chatProvider = context.read<ChatProvider>();
                                final room = chatProvider.getOrCreateCommunityRoom(
                                  community.id,
                                  community.name,
                                  community.iconEmoji,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(roomId: room.id),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(communityId: community.id),
                                  ),
                                );
                              }
                            },
                            onJoinToggle: () {
                              if (community.isJoined) {
                                _confirmLeaveCommunity(community);
                              } else {
                                communityProvider.toggleJoinCommunity(community.id, userIdentifier: currentUserId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Joined "${community.name}"! 🎉'),
                                    backgroundColor: const Color(0xFF238636),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),

                // TAB 1: COMMUNITIES
                communitiesList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: const Center(
                                  child: Text('🏛️', style: TextStyle(fontSize: 26)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Communities Found',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create a public community for your city, campus or topic!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF8B949E)),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _showCreateCommunityDialog,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text('Create Community'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF238636),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: communitiesList.length,
                        itemBuilder: (context, index) {
                          final community = communitiesList[index];
                          final cleanCreator = community.creatorId.toLowerCase().replaceAll('@', '').trim();
                          final cleanUid = currentUserId.toLowerCase().replaceAll('@', '').trim();
                          final cleanUname = (auth.currentUser?.username ?? '').toLowerCase().replaceAll('@', '').trim();
                          final isCreator = cleanCreator.isNotEmpty &&
                              cleanUid.isNotEmpty &&
                              (cleanCreator == cleanUid || (cleanUname.isNotEmpty && cleanCreator == cleanUname));
                          return CommunityCard(
                            community: community,
                            onDelete: isCreator ? () => _confirmDeleteCommunity(community) : null,
                            onChatTap: () {
                              final chatProvider = context.read<ChatProvider>();
                              final room = chatProvider.getOrCreateCommunityRoom(
                                community.id,
                                community.name,
                                community.iconEmoji,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(roomId: room.id),
                                ),
                              );
                            },
                            onTap: () {
                              if (community.isJoined) {
                                final chatProvider = context.read<ChatProvider>();
                                final room = chatProvider.getOrCreateCommunityRoom(
                                  community.id,
                                  community.name,
                                  community.iconEmoji,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(roomId: room.id),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(communityId: community.id),
                                  ),
                                );
                              }
                            },
                            onJoinToggle: () {
                              if (community.isJoined) {
                                _confirmLeaveCommunity(community);
                              } else {
                                communityProvider.toggleJoinCommunity(community.id, userIdentifier: currentUserId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Joined "${community.name}"! 🎉'),
                                    backgroundColor: const Color(0xFF238636),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
