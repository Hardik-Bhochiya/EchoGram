import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echogram/providers/community_provider.dart';
import 'package:echogram/providers/question_provider.dart';
import 'package:echogram/providers/chat_provider.dart';
import 'package:echogram/providers/auth_provider.dart';
import 'package:echogram/providers/notification_provider.dart';
import 'package:echogram/models/user.dart';
import 'package:echogram/services/mock_data_service.dart';
import 'package:echogram/services/socket_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SocketService.disabledForTests = true;
  });

  group('EchoGram Providers & Business Logic Tests', () {
    test('CommunityProvider creates community with location spot and creator delete option', () {
      final provider = CommunityProvider();
      final initialCount = provider.allCommunities.length;

      // Create a community with location spot
      final comm = provider.createCommunity(
        name: 'Mumbai Sports Club',
        description: 'Sports and fitness activities in Mumbai',
        regionId: 'region-mumbai',
        regionName: 'Mumbai',
        category: 'Sports',
        iconEmoji: '⚽',
        bannerColorHex: 0xFF238636,
        locationSpot: 'Mumbai Grounds',
        creatorId: MockDataService.currentUser.id,
      );

      expect(provider.allCommunities.length, initialCount + 1);
      expect(comm.locationSpot, 'Mumbai Grounds');
      expect(comm.creatorId, MockDataService.currentUser.id);

      // Creator deletes community (WhatsApp-style delete)
      final deleted = provider.deleteCommunity(comm.id, MockDataService.currentUser.id);
      expect(deleted, isTrue);
      expect(provider.allCommunities.length, initialCount);
    });

    test('QuestionProvider adds anonymous question, upvotes and bookmarks', () {
      final qProvider = QuestionProvider();
      final initialCount = qProvider.questions.length;

      qProvider.askQuestion(
        title: 'What are the best tips for daily messaging productivity?',
        content: 'Looking for recommended habits to keep communication organized.',
        communityId: 'c-general',
        communityName: 'General Discussion',
        regionId: 'general',
        regionName: 'General',
        user: MockDataService.currentUser,
        isAnonymous: true,
        tags: ['Productivity', 'General'],
      );

      expect(qProvider.questions.length, initialCount + 1);
      final newQ = qProvider.questions.first;
      expect(newQ.isAnonymous, isTrue);
      expect(newQ.upvotes, 1);

      // Toggle upvote
      qProvider.toggleUpvoteQuestion(newQ.id);
      expect(qProvider.getQuestionById(newQ.id)!.upvotes, 0);

      // Toggle bookmark
      qProvider.toggleBookmark(newQ.id);
      expect(qProvider.getQuestionById(newQ.id)!.isBookmarked, isTrue);
    });

    test('ChatProvider starts personal chat, edits message, and toggles like/dislike', () {
      final chatProvider = ChatProvider();
      const me = User(
        id: 'user-hardik',
        username: 'hardik_07',
        name: 'Hardik Bhochiya',
        email: 'hardik@gmail.com',
        campusOrCity: 'Mumbai',
      );
      const peer = User(
        id: 'user-rahul',
        username: 'rahul123',
        name: 'Rahul Patel',
        email: 'rahul@gmail.com',
        campusOrCity: 'Dwarka',
      );

      // 1. Start Personal Chat by Username
      final room = chatProvider.startPersonalChat(
        peerUser: peer,
        currentUser: me,
      );
      expect(room.id, 'dm-hardik_07_rahul123');

      // 2. Send Message with seen indicator
      chatProvider.sendMessage(
        roomId: room.id,
        content: 'Hey Rahul, let us meet in Mumbai.',
        currentUser: me,
      );

      final msgs = chatProvider.getMessages(room.id);
      expect(msgs.length, 1);
      final msg = msgs.first;
      expect(msg.status, 'sent');

      // 3. Edit Message
      chatProvider.editMessage(room.id, msg.id, 'Hey Rahul, let us meet in Mumbai at 4 PM.');
      final editedMsg = chatProvider.getMessages(room.id).first;
      expect(editedMsg.content, 'Hey Rahul, let us meet in Mumbai at 4 PM.');
      expect(editedMsg.isEdited, isTrue);

      // 4. Like / Dislike reactions
      chatProvider.toggleLikeMessage(room.id, msg.id, 'user-rahul');
      expect(chatProvider.getMessages(room.id).first.likes, contains('user-rahul'));

      chatProvider.toggleDislikeMessage(room.id, msg.id, 'user-rahul');
      expect(chatProvider.getMessages(room.id).first.likes, isNot(contains('user-rahul')));
      expect(chatProvider.getMessages(room.id).first.dislikes, contains('user-rahul'));

      // 5. Delete Message for everyone
      chatProvider.deleteMessage(room.id, msg.id, forEveryone: true);
      expect(chatProvider.getMessages(room.id).first.isDeleted, isTrue);
    });

    test('NotificationProvider marks notifications as read', () {
      final notifProvider = NotificationProvider();
      expect(notifProvider.unreadCount, 0);

      notifProvider.addNotification(
        title: 'Welcome',
        message: 'Welcome to EchoGram!',
        type: 'general',
      );
      expect(notifProvider.unreadCount, 1);

      notifProvider.markAllAsRead();
      expect(notifProvider.unreadCount, 0);
    });

    test('AuthProvider friend request lifecycle: send, pending status, and accept friendship', () async {
      final auth = AuthProvider();
      auth.setCurrentUserForTesting(const User(
        id: 'user-hardik',
        username: 'hardik_07',
        name: 'Hardik Bhochiya',
        email: 'hardik@gmail.com',
        campusOrCity: 'Mumbai',
      ));

      // Send friend request to devshah
      final sent = await auth.sendFriendRequest('devshah');
      expect(sent, isTrue);

      final outgoing = auth.getPendingOutgoingRequests();
      expect(outgoing.any((r) => r.receiverUsername == 'devshah'), isTrue);

      // Accept request
      final req = outgoing.firstWhere((r) => r.receiverUsername == 'devshah');
      await auth.respondFriendRequest(req.id, 'accepted');

      expect(auth.areFriends('devshah'), isTrue);
    });
  });
}
