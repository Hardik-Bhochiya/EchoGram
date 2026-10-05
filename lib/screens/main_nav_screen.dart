import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/home_screen.dart';
import 'community/communities_screen.dart';
import 'search/search_screen.dart';
import 'chat/chat_list_screen.dart';
import 'profile/profile_screen.dart';
import '../providers/chat_provider.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CommunitiesScreen(),
    SearchScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF58A6FF); // GitHub Blue
    const inactiveColor = Color(0xFF8B949E); // GitHub Muted Gray

    final chatProvider = context.watch<ChatProvider>();
    final totalUnreadChat = chatProvider.rooms.fold<int>(0, (sum, r) => sum + r.unreadCount);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          border: Border(
            top: BorderSide(
              color: Color(0xFF30363D),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Home
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 2. Groups
              Expanded(
                child: _buildNavItem(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups_rounded,
                  label: 'Groups',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 3. Search
              Expanded(
                child: _buildNavItem(
                  icon: Icons.search_rounded,
                  selectedIcon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 4. Chats (with message unread indicator)
              Expanded(
                child: _buildNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  badgeCount: totalUnreadChat,
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 5. Profile
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    IconData? selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color inactiveColor,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? (selectedIcon ?? icon) : icon,
                  size: 21,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF85149),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
