import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import '../models/reply.dart';
import '../models/user.dart';
import '../services/mock_data_service.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';

class QuestionProvider extends ChangeNotifier {
  List<Question> _questions = [];
  String _selectedTag = 'All';
  String _searchQuery = '';
  String _sortFilter = 'Recent';
  bool _isLoading = false;
  StreamSubscription? _firestoreSub;

  List<Question> get questions => _questions;
  String get selectedTag => _selectedTag;
  String get searchQuery => _searchQuery;
  String get sortFilter => _sortFilter;
  bool get isLoading => _isLoading;

  static const List<String> _anonymousAnimalAliases = [
    'Anonymous',
    'Anonymous Owl 🦉',
    'Curious Badger 🦡',
    'Silent Koala 🐨',
    'Campus Fox 🦊',
    'Swift Falcon 🦅',
  ];

  QuestionProvider() {
    _loadQuestions();
  }

  void _initFirestoreListener() {
    if (Firebase.apps.isEmpty) return;
    try {
      _firestoreSub?.cancel();
      _firestoreSub = FirebaseFirestore.instance
          .collection('questions')
          .snapshots()
          .listen((snap) {
        if (snap.docs.isEmpty) return;
        final firestoreList = <Question>[];
        for (final doc in snap.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            final q = Question.fromJson(data);
            firestoreList.add(q);
            LocalStoreService().updateQuestion(q);
          } catch (_) {}
        }
        if (firestoreList.isNotEmpty) {
          _questions = firestoreList;
          notifyListeners();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _loadQuestions() async {
    _isLoading = true;
    // 1. Immediately load local persisted questions (zero delay, fully offline capable)
    _questions = LocalStoreService().getQuestions();
    if (_questions.isEmpty) {
      _questions = List.from(MockDataService.initialQuestions);
    }
    _isLoading = false;
    notifyListeners();

    // 2. Real-time Cloud Firestore sync
    _initFirestoreListener();

    // 3. Optional local background fallback
    try {
      if (ApiService().isServerReachable) {
        final remoteQuestions = await ApiService().getQuestions();
        if (remoteQuestions.isNotEmpty) {
          _questions = remoteQuestions;
          for (final q in remoteQuestions) {
            LocalStoreService().updateQuestion(q);
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void selectTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  void setSortFilter(String filter) {
    _sortFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Question> getQuestionsForCommunity(String communityId) {
    return _questions.where((q) => q.communityId == communityId).toList();
  }

  List<Question> get filteredQuestions {
    var list = _questions.where((q) {
      final matchesTag = _selectedTag == 'All' || q.tags.contains(_selectedTag);
      final matchesSearch = _searchQuery.isEmpty ||
          q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q.communityName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesTag && matchesSearch;
    }).toList();

    if (_sortFilter == 'Most Helpful') {
      list.sort((a, b) => b.upvotes.compareTo(a.upvotes));
    } else if (_sortFilter == 'Unanswered') {
      list = list.where((q) => q.replyCount == 0).toList();
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  List<Question> get mainQuestions => _questions.where((q) => !q.isAnonymous).toList();
  List<Question> get anonymousQuestions => _questions.where((q) => q.isAnonymous).toList();

  List<Question> get trendingQuestions {
    final list = List<Question>.from(_questions);
    list.sort((a, b) => (b.upvotes + b.replyCount * 2).compareTo(a.upvotes + a.replyCount * 2));
    return list;
  }

  List<Question> getUserQuestions(String userId) {
    return _questions.where((q) => q.authorId == userId).toList();
  }

  List<Question> get bookmarkedQuestions {
    return _questions.where((q) => q.isBookmarked).toList();
  }

  Question? getQuestionById(String id) {
    try {
      return _questions.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  void toggleBookmark(String questionId) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      _questions[index] = q.copyWith(isBookmarked: !q.isBookmarked);
      LocalStoreService().toggleBookmark(questionId);
      notifyListeners();
    }
  }

  Future<void> askQuestion({
    required String title,
    required String content,
    required String communityId,
    required String communityName,
    required String regionId,
    required String regionName,
    required User user,
    required bool isAnonymous,
    required List<String> tags,
  }) async {
    final pseudonym = isAnonymous
        ? _anonymousAnimalAliases[Random().nextInt(_anonymousAnimalAliases.length)]
        : null;

    final newQuestion = Question(
      id: MockDataService.generateId(),
      title: title,
      content: content,
      communityId: communityId,
      communityName: communityName,
      regionId: regionId,
      regionName: regionName,
      authorId: user.id,
      authorName: isAnonymous ? 'Anonymous' : user.name,
      authorAvatar: isAnonymous ? null : user.avatarUrl,
      isAnonymous: isAnonymous,
      anonymousPseudonym: pseudonym,
      tags: tags,
      upvotes: 1,
      views: 1,
      createdAt: DateTime.now(),
      replies: [],
      isUpvotedByMe: true,
      isBookmarked: false,
    );

    // Save locally for guaranteed mobile permanence
    _questions.insert(0, newQuestion);
    LocalStoreService().addQuestion(newQuestion);
    notifyListeners();

    // 1. Direct Cloud Firestore write
    if (Firebase.apps.isNotEmpty) {
      try {
        FirebaseFirestore.instance
            .collection('questions')
            .doc(newQuestion.id)
            .set(newQuestion.toJson());
      } catch (_) {}
    }

    // 2. Background sync fallback
    try {
      await ApiService().createQuestion(
        title: title,
        content: content,
        communityId: communityId,
        communityName: communityName,
        regionId: regionId,
        regionName: regionName,
        user: user,
        isAnonymous: isAnonymous,
        tags: tags,
      );
    } catch (_) {}
  }

  void toggleUpvoteQuestion(String questionId) {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      final newUpvoted = !q.isUpvotedByMe;
      final newCount = newUpvoted ? q.upvotes + 1 : q.upvotes - 1;
      _questions[index] = q.copyWith(
        isUpvotedByMe: newUpvoted,
        upvotes: newCount < 0 ? 0 : newCount,
      );
      LocalStoreService().toggleUpvote(questionId);
      notifyListeners();

      // Cloud Firestore update
      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseFirestore.instance
              .collection('questions')
              .doc(questionId)
              .update({
            'upvotes': FieldValue.increment(newUpvoted ? 1 : -1),
          });
        } catch (_) {}
      }

      ApiService().toggleUpvote(questionId);
    }
  }

  Future<void> addReply({
    required String questionId,
    required String content,
    required User user,
    required bool isAnonymous,
  }) async {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      final q = _questions[index];
      final pseudonym = isAnonymous ? 'Anonymous' : null;

      final newReply = Reply(
        id: MockDataService.generateId(),
        questionId: questionId,
        content: content,
        authorId: user.id,
        authorName: isAnonymous ? 'Anonymous' : user.name,
        authorAvatar: isAnonymous ? null : user.avatarUrl,
        isAnonymous: isAnonymous,
        anonymousPseudonym: pseudonym,
        upvotes: 0,
        createdAt: DateTime.now(),
      );

      final updatedReplies = List<Reply>.from(q.replies)..add(newReply);
      _questions[index] = q.copyWith(replies: updatedReplies);
      LocalStoreService().addReply(questionId, newReply);
      notifyListeners();

      // Cloud Firestore update
      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseFirestore.instance
              .collection('questions')
              .doc(questionId)
              .update({
            'replies': FieldValue.arrayUnion([newReply.toJson()]),
          });
        } catch (_) {}
      }

      ApiService().addReply(
        questionId: questionId,
        content: content,
        user: user,
        isAnonymous: isAnonymous,
      );
    }
  }

  void toggleUpvoteReply(String questionId, String replyId) {
    final qIndex = _questions.indexWhere((q) => q.id == questionId);
    if (qIndex != -1) {
      final q = _questions[qIndex];
      final rIndex = q.replies.indexWhere((r) => r.id == replyId);
      if (rIndex != -1) {
        final r = q.replies[rIndex];
        final newUpvoted = !r.isUpvotedByMe;
        final newCount = newUpvoted ? r.upvotes + 1 : r.upvotes - 1;
        final updatedReply = r.copyWith(
          isUpvotedByMe: newUpvoted,
          upvotes: newCount < 0 ? 0 : newCount,
        );
        final updatedReplies = List<Reply>.from(q.replies)..[rIndex] = updatedReply;
        _questions[qIndex] = q.copyWith(replies: updatedReplies);
        LocalStoreService().updateQuestion(_questions[qIndex]);
        notifyListeners();

        // Cloud Firestore update
        if (Firebase.apps.isNotEmpty) {
          try {
            FirebaseFirestore.instance
                .collection('questions')
                .doc(questionId)
                .update({
              'replies': updatedReplies.map((x) => x.toJson()).toList(),
            });
          } catch (_) {}
        }
      }
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}
