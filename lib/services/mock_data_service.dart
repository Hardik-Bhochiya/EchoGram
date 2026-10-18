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
    id: '',
    username: '',
    name: '',
    email: '',
    campusOrCity: '',
  );

  static List<User> knownUsers = [];

  static List<Region> initialRegions = [
    const Region(
      id: 'region-general',
      name: 'General Chat',
      category: 'General',
      description: 'Open discussion and hangout channel for everyone.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '💬',
    ),
    const Region(
      id: 'region-tech',
      name: 'Tech & Coding',
      category: 'Tech',
      description: 'Discuss coding, tech news, projects, and ideas.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '💻',
    ),
    const Region(
      id: 'region-design',
      name: 'Design & Creative',
      category: 'Creative',
      description: 'UI/UX, art, illustrations, and design inspiration.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🎨',
    ),
    const Region(
      id: 'region-gaming',
      name: 'Gaming & Fun',
      category: 'Gaming',
      description: 'PC, console, mobile games, and casual banter.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🎮',
    ),
    const Region(
      id: 'region-music',
      name: 'Music & Vibes',
      category: 'Entertainment',
      description: 'Share tracks, playlists, movies, and podcasts.',
      activeCommunitiesCount: 0,
      activeMembersCount: 0,
      iconEmoji: '🎧',
    ),
  ];

  static List<Community> initialCommunities = [];
  static List<Question> initialQuestions = [];
  static List<ChatRoom> initialChatRooms = [];
  static List<ChatMessage> initialMessages = [];
  static List<NotificationItem> initialNotifications = [];
  static List<FriendRequest> initialFriendRequests = [];
}
