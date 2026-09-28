import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../services/local_store_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
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
            Icon(Icons.logout_rounded, color: Color(0xFFF85149), size: 22),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of NearTalk?',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, User user) {
    final nameCtrl = TextEditingController(text: user.name);
    final locationCtrl = TextEditingController(text: user.campusOrCity);
    final bioCtrl = TextEditingController(text: user.majorOrBio ?? '');
    String selectedAvatar = user.avatarUrl ?? '👤';
    final availableAvatars = ['👤', '🎓', '💻', '🚀', '⚡', '📚', '🎨', '🌟'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
              ),
              const SizedBox(height: 14),

              // Avatar selection
              const Text(
                'Profile Photo / Avatar',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableAvatars.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final av = availableAvatars[index];
                    final isSel = selectedAvatar == av;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedAvatar = av),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF21262D) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(av, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Color(0xFFF0F6FC)),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(color: Color(0xFFF0F6FC)),
                decoration: InputDecoration(
                  labelText: 'College / Location',
                  hintText: 'e.g. DDU, Nadiad or Mumbai',
                  hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLines: 2,
                style: const TextStyle(color: Color(0xFFF0F6FC)),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Brief about yourself',
                  hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final newName = nameCtrl.text.trim();
                  final newLoc = locationCtrl.text.trim();
                  final newBio = bioCtrl.text.trim();

                  // If location does not exist in registry, automatically add it
                  if (newLoc.isNotEmpty) {
                    LocalStoreService().addLocation(newLoc);
                  }

                  context.read<AuthProvider>().updateProfile(
                    name: newName.isNotEmpty ? newName : user.name,
                    campusOrCity: newLoc.isNotEmpty ? newLoc : user.campusOrCity,
                    majorOrBio: newBio,
                    avatarUrl: selectedAvatar,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: Color(0xFF238636),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final communityProvider = context.watch<CommunityProvider>();
    final joinedCommunitiesCount = communityProvider.joinedCommunities.length;
    final friendsCount = auth.getFriends().length;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 54, color: Color(0xFF8B949E)),
              const SizedBox(height: 14),
              const Text('Guest Mode Active', style: TextStyle(fontSize: 18, color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Sign in to access your personal profile & friends.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Sign In / Register'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF0F6FC)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF85149), size: 20),
            tooltip: 'Sign Out',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Profile Photo
            Center(
              child: Container(
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
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Name
            Text(
              user.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 4),

            // 3. @username
            Text(
              user.handle,
              style: const TextStyle(fontSize: 14, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),

            // 4. Bio
            if (user.majorOrBio != null && user.majorOrBio!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  user.majorOrBio!,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFFC9D1D9), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),

            // 5. College / Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF8B949E)),
                const SizedBox(width: 5),
                Text(
                  user.campusOrCity.isNotEmpty ? user.campusOrCity : 'DDU, Nadiad',
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 6. [Edit Profile] Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _showEditProfileSheet(context, user),
                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFFF0F6FC)),
                label: const Text('Edit Profile', style: TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF30363D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFF161B22),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Divider(color: Color(0xFF30363D)),
            const SizedBox(height: 18),

            // 7. Summary counters: Friends & Communities
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$friendsCount',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Friends',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8B949E), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$joinedCommunitiesCount',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Communities',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8B949E), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 8. Sign Out button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _confirmSignOut(context, auth),
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA3633),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
