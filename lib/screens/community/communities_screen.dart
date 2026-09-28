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
    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';

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
              final deleted = context.read<CommunityProvider>().deleteCommunity(community.id, currentUserId);
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
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFFE3B341), size: 22),
            SizedBox(width: 8),
            Text(
              'Leave Community?',
              style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to leave "${community.name}"? You will stop seeing its updates in My Communities.',
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
    final communityProvider = context.read<CommunityProvider>();
    final regions = communityProvider.regions;
    String selectedRegionName = communityProvider.selectedRegion?.name ?? (regions.isNotEmpty ? regions.first.name : 'Nadiad');

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final customLocationController = TextEditingController();
    final locationSpotController = TextEditingController();
    final rule1Controller = TextEditingController();
    final rule2Controller = TextEditingController();
    final rule3Controller = TextEditingController();
    final rule4Controller = TextEditingController();

    String selectedCategory = 'Tech & Dev';
    String selectedEmoji = '💻';
    bool isCustomLocation = false;
    final emojis = ['💻', '📚', '🚀', '📸', '🏏', '🎓', '🎭', '🌊', '🏛️', '⚽'];

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
                        const Text(
                          'Create New Community',
                          style: TextStyle(
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
                    const SizedBox(height: 14),

                    // City / Location Selection Dropdown & Custom Option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'City / Location / College',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isCustomLocation = !isCustomLocation;
                            });
                          },
                          child: Text(
                            isCustomLocation ? 'Select from list' : '+ Add New Location',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!isCustomLocation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: regions.any((r) => r.name == selectedRegionName)
                                ? selectedRegionName
                                : (regions.isNotEmpty ? regions.first.name : null),
                            dropdownColor: const Color(0xFF21262D),
                            style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 13.5),
                            isExpanded: true,
                            items: [
                              ...regions.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r.name,
                                  child: Row(
                                    children: [
                                      Text(r.iconEmoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }),
                              const DropdownMenuItem<String>(
                                value: '__ADD_NEW__',
                                child: Row(
                                  children: [
                                    Icon(Icons.add_location_alt_rounded, color: Color(0xFF238636), size: 16),
                                    SizedBox(width: 8),
                                    Text('+ Add New Location / College...', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF238636))),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == '__ADD_NEW__') {
                                setModalState(() => isCustomLocation = true);
                              } else if (val != null) {
                                setModalState(() {
                                  selectedRegionName = val;
                                  locationSpotController.text = '$val Hub';
                                });
                              }
                            },
                          ),
                        ),
                      )
                    else
                      CustomTextField(
                        controller: customLocationController,
                        labelText: 'Location / College Name',
                        hintText: 'e.g. Pune, DDU Nadiad, IIT Bombay',
                        prefixIcon: Icons.add_location_alt_rounded,
                      ),
                    const SizedBox(height: 14),

                    // Emoji selector
                    const Text(
                      'Choose Icon',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
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

                    CustomTextField(
                      controller: nameController,
                      labelText: 'Community Name',
                      hintText: 'e.g. Pune Coders, DDU Robotics Club',
                    ),
                    const SizedBox(height: 12),

                    CustomTextField(
                      controller: locationSpotController,
                      labelText: 'Location Spot / Landmark',
                      hintText: 'e.g. Campus Hub, Main Auditorium',
                      prefixIcon: Icons.place_rounded,
                    ),
                    const SizedBox(height: 12),

                    CustomTextField(
                      controller: descController,
                      labelText: 'Description',
                      hintText: 'What is this community about?',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 14),

                    // Community Rules section
                    const Text(
                      'Community Rules',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(controller: rule1Controller, labelText: 'Rule 1', hintText: 'e.g. Respect all members'),
                    const SizedBox(height: 6),
                    CustomTextField(controller: rule2Controller, labelText: 'Rule 2', hintText: 'e.g. No spam or promotions'),
                    const SizedBox(height: 6),
                    CustomTextField(controller: rule3Controller, labelText: 'Rule 3', hintText: 'e.g. No abusive language'),
                    const SizedBox(height: 6),
                    CustomTextField(controller: rule4Controller, labelText: 'Rule 4', hintText: 'e.g. Stay on topic'),
                    const SizedBox(height: 20),

                    PrimaryButton(
                      text: 'Create Community',
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          final currentUserId = ctx.read<AuthProvider>().currentUser?.id ?? '';
                          final effectiveLocation = (isCustomLocation && customLocationController.text.trim().isNotEmpty)
                              ? customLocationController.text.trim()
                              : selectedRegionName;

                          final spot = locationSpotController.text.trim().isNotEmpty
                              ? locationSpotController.text.trim()
                              : '$effectiveLocation Spot';

                          final rules = [
                            rule1Controller.text.trim(),
                            rule2Controller.text.trim(),
                            rule3Controller.text.trim(),
                            rule4Controller.text.trim(),
                          ].where((r) => r.isNotEmpty).toList();

                          final created = ctx.read<CommunityProvider>().createCommunity(
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            category: selectedCategory,
                            iconEmoji: selectedEmoji,
                            bannerColorHex: 0xFF58A6FF,
                            regionName: effectiveLocation,
                            locationSpot: spot,
                            creatorId: currentUserId,
                            rules: rules.isNotEmpty ? rules : null,
                          );
                          ctx.read<ChatProvider>().getOrCreateCommunityRoom(
                            created.id,
                            created.name,
                            created.iconEmoji,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Created "${nameController.text.trim()}" in $effectiveLocation! 🎉'),
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

    final joinedCommunities = communityProvider.joinedCommunities;

    // Filter all communities across the app without forcing a single city
    final exploreCommunities = communityProvider.communities.where((c) {
      final matchesCategory = communityProvider.selectedCategory == 'All' || c.category == communityProvider.selectedCategory;
      final query = communityProvider.searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.locationSpot.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        titleSpacing: widget.isTab ? 16 : 0,
        title: const Text(
          'Communities',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFFF0F6FC),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF58A6FF)),
            tooltip: 'Create Community',
            onPressed: _showCreateCommunityDialog,
          ),
          const SizedBox(width: 8),
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
                      const Icon(Icons.explore_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Explore (${exploreCommunities.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('My Groups (${joinedCommunities.length})'),
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

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => communityProvider.setSearchQuery(val),
              style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Search communities, topics, spots...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF8B949E)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
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

          // 4. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: EXPLORE COMMUNITIES
                exploreCommunities.isEmpty
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
                                  child: Text('💬', style: TextStyle(fontSize: 26)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Communities Found',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Be the first to create a community!',
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
                        itemCount: exploreCommunities.length,
                        itemBuilder: (context, index) {
                          final community = exploreCommunities[index];
                          final isCreator = community.creatorId == currentUserId;
                          return CommunityCard(
                            community: community,
                            onDelete: isCreator ? () => _confirmDeleteCommunity(community) : null,
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
                              }
                            },
                          );
                        },
                      ),

                // Tab 2: MY COMMUNITIES (JOINED WITH LEAVE OPTION)
                joinedCommunities.isEmpty
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
                                'No Joined Communities Yet',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Switch to the Explore tab and tap Join to join city communities!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF8B949E)),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () => _tabController.animateTo(0),
                                icon: const Icon(Icons.explore_rounded, size: 18),
                                label: const Text('Explore Communities'),
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
                        itemCount: joinedCommunities.length,
                        itemBuilder: (context, index) {
                          final community = joinedCommunities[index];
                          final isCreator = community.creatorId == currentUserId;
                          return CommunityCard(
                            community: community,
                            onDelete: isCreator ? () => _confirmDeleteCommunity(community) : null,
                            onTap: () {
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
                            onJoinToggle: () {
                              _confirmLeaveCommunity(community);
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCommunityDialog,
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create Community', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
