import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'people/people_screen.dart';
import 'chat/chat_list_screen.dart';
import 'community/communities_screen.dart';
import 'profile/profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PeopleScreen(),
    ChatListScreen(),
    CommunitiesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF58A6FF); // GitHub Blue
    const inactiveColor = Color(0xFF8B949E); // GitHub Muted Gray

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
              // 2. People
              Expanded(
                child: _buildNavItem(
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: 'People',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 3. Chats (Personal + Groups)
              Expanded(
                child: _buildNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
              // 4. Communities
              Expanded(
                child: _buildNavItem(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups_rounded,
                  label: 'Communities',
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? (selectedIcon ?? icon) : icon,
              size: 21,
              color: isSelected ? activeColor : inactiveColor,
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
