import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/region.dart';
import '../models/community.dart';
import '../models/question.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/notification_item.dart';
import '../models/friend_request.dart';

class MockDataService {
  static const _uuid = Uuid();
  static String generateId() => _uuid.v4();

  static User currentUser = const User(
    id: 'user-hardik',
    username: 'hardik_07',
    name: 'Hardik Bhochiya',
    firstName: 'Hardik',
    lastName: 'Bhochiya',
    email: 'hardik@gmail.com',
    campusOrCity: 'Nadiad',
    majorOrBio: 'Computer Engineering | Tech & Community Builder',
    reputation: 240,
    joinedCommunityIds: [],
    badges: ['Top Contributor', 'Community Builder'],
    isCollegeVerified: true,
  );

  static List<User> knownUsers = [
    currentUser,
  ];

  static List<Region> initialRegions = [
    const Region(
      id: 'region-ddu',
      name: 'DDU Nadiad',
      category: 'Campus',
      description: 'Dharmsinh Desai University (DDU) campus student circles.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🎓',
    ),
    const Region(
      id: 'region-nadiad',
      name: 'Nadiad',
      category: 'Campus & City',
      description: 'Nadiad student circles and campus peers.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '📍',
    ),
    const Region(
      id: 'region-ahmedabad',
      name: 'Ahmedabad',
      category: 'City',
      description: 'Ahmedabad startups, engineering students, and cultural clubs.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🏢',
    ),
    const Region(
      id: 'region-vadodara',
      name: 'Vadodara',
      category: 'City',
      description: 'Vadodara campus and tech student community.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🏛️',
    ),
    const Region(
      id: 'region-gandhinagar',
      name: 'Gandhinagar',
      category: 'City',
      description: 'Gandhinagar tech institutes and student circles.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🌿',
    ),
  ];

  static List<Community> initialCommunities = [];
  static List<Question> initialQuestions = [];
  static List<ChatRoom> initialChatRooms = [];
  static List<ChatMessage> initialMessages = [];
  static List<NotificationItem> initialNotifications = [];
  static List<FriendRequest> initialFriendRequests = [];
}
