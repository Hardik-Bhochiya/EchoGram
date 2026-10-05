import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/region.dart';
import '../models/community.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';

class CommunityProvider extends ChangeNotifier {
  List<Region> _regions = [];
  List<Community> _communities = [];
  Region? _selectedRegion;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  Timer? _syncTimer;
  StreamSubscription? _firestoreSub;
  String? _activeUserIdentifier;

  List<Region> get regions => _regions;
  Region? get selectedRegion => _selectedRegion;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<String> get locations => LocalStoreService().getLocations();

  CommunityProvider() {
    _loadCommunities();
    _initFirestoreListener();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (Firebase.apps.isEmpty) {
        refreshCommunities(userIdentifier: _activeUserIdentifier);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _firestoreSub?.cancel();
    super.dispose();
  }

  void _initFirestoreListener() {
    if (Firebase.apps.isEmpty) return;
    try {
      _firestoreSub = FirebaseFirestore.instance
          .collection('communities')
          .snapshots()
          .listen((snap) {
        if (snap.docs.isNotEmpty) {
          final Map<String, Community> map = {};
          final cleanUser = (_activeUserIdentifier ?? '').toLowerCase().replaceAll('@', '');

          for (final doc in snap.docs) {
            final data = doc.data();
            final c = Community.fromJson({
              ...data,
              'id': doc.id,
            });
            final cName = c.name.toLowerCase();
            if (c.id.startsWith('c') ||
                cName.contains('canteen') ||
                cName.contains('hostel') ||
                cName.contains('robotics') ||
                c.creatorId == 'rahul123') {
              continue;
            }
            final existingIdx = _communities.indexWhere((item) => item.id == c.id);
            final wasJoined = existingIdx != -1 ? _communities[existingIdx].isJoined : false;
            final isMember = cleanUser.isNotEmpty && c.members.any((m) => m.toLowerCase().replaceAll('@', '') == cleanUser);
            final isJoined = c.isJoined || wasJoined || isMember;

            final updated = c.copyWith(isJoined: isJoined);
            map[c.id] = updated;
            LocalStoreService().addCommunity(updated);
            LocalStoreService().addLocation(c.regionName);
          }

          _communities = map.values.toList();
          _syncRegions();
          notifyListeners();
        }
      }, onError: (err) {
        debugPrint('[CommunityProvider] Firestore communities notice: $err');
      });
    } catch (_) {}
  }

  void addLocation(String location) {
    LocalStoreService().addLocation(location);
    _syncRegions();
    notifyListeners();
  }

  void _syncRegions() {
    final locs = LocalStoreService().getLocations();
    _regions = locs.map((name) {
      final cleanId = 'region_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
      final commCount = _communities.where((c) => c.regionName.toLowerCase() == name.toLowerCase()).length;
      return Region(
        id: cleanId,
        name: name,
        category: name.contains('Campus') || name.contains('College') || name.contains('DDU') ? 'Campus' : 'City',
        description: 'Local campus and city community members in $name',
        activeCommunitiesCount: commCount,
        activeMembersCount: 0,
        iconEmoji: '📍',
      );
    }).toList();
  }

  void _loadCommunities() {
    _communities = LocalStoreService().getCommunities();
    _syncRegions();
    if (_regions.isNotEmpty && _selectedRegion == null) {
      _selectedRegion = _regions.first;
    }
    notifyListeners();
    refreshCommunities();
  }

  Future<void> refreshCommunities({String? userIdentifier}) async {
    if (userIdentifier != null && userIdentifier.isNotEmpty) {
      _activeUserIdentifier = userIdentifier;
    }
    try {
      final remoteList = await ApiService().getCommunities(userIdentifier: _activeUserIdentifier);
      final Map<String, Community> map = {};
      bool hasChanges = false;
      final cleanUser = (_activeUserIdentifier ?? '').toLowerCase().replaceAll('@', '');

      for (final rc in remoteList) {
        final cName = rc.name.toLowerCase();
        if (rc.id.startsWith('c') ||
            cName.contains('canteen') ||
            cName.contains('hostel') ||
            cName.contains('robotics') ||
            rc.creatorId == 'rahul123') {
          continue;
        }
        final existingIdx = _communities.indexWhere((c) => c.id == rc.id);
        final bool wasJoined = existingIdx != -1 ? _communities[existingIdx].isJoined : false;
        final bool isMember = cleanUser.isNotEmpty && rc.members.any((m) => m.toLowerCase().replaceAll('@', '') == cleanUser);
        final bool isJoined = rc.isJoined || wasJoined || isMember;

        final updated = rc.copyWith(isJoined: isJoined);
        map[rc.id] = updated;
        LocalStoreService().addCommunity(updated);
        LocalStoreService().addLocation(rc.regionName);
        if (existingIdx == -1 ||
            _communities[existingIdx].isJoined != isJoined ||
            _communities[existingIdx].memberCount != rc.memberCount) {
          hasChanges = true;
        }
      }
      if (hasChanges || _communities.length != map.length) {
        _communities = map.values.toList();
        _syncRegions();
        notifyListeners();
      }
    } catch (_) {}
  }

  void selectRegion(Region region) {
    _selectedRegion = region;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Community> get communities {
    final Map<String, Community> unique = {};
    for (final c in _communities) {
      unique[c.id] = c;
    }
    return unique.values.toList();
  }

  List<Community> get allCommunities => communities;

  List<Community> get joinedCommunities {
    final Map<String, Community> unique = {};
    for (final c in _communities) {
      if (c.isJoined) {
        unique[c.id] = c;
      }
    }
    return unique.values.toList();
  }

  List<Community> get filteredCommunities {
    return _communities.where((c) {
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.locationSpot.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.regionName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Community? getCommunityById(String id) {
    try {
      return _communities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleJoinCommunity(String communityId, {String? userIdentifier}) async {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index != -1) {
      final current = _communities[index];
      final newJoined = !current.isJoined;

      final effUser = (userIdentifier ?? _activeUserIdentifier ?? '').toLowerCase().replaceAll('@', '').trim();
      final updatedMembers = List<String>.from(current.members);
      if (newJoined) {
        if (effUser.isNotEmpty && !updatedMembers.any((m) => m.toLowerCase().replaceAll('@', '').trim() == effUser)) {
          updatedMembers.add(effUser);
        }
      } else {
        if (effUser.isNotEmpty) {
          updatedMembers.removeWhere((m) => m.toLowerCase().replaceAll('@', '').trim() == effUser);
        }
      }

      final distinctCount = updatedMembers
          .map((m) => m.toLowerCase().replaceAll('@', '').trim())
          .where((m) => m.isNotEmpty)
          .toSet()
          .length;
      final newCount = distinctCount > 0
          ? distinctCount
          : (newJoined ? 1 : 0);

      _communities[index] = current.copyWith(
        isJoined: newJoined,
        memberCount: newCount,
        members: updatedMembers,
      );
      LocalStoreService().toggleJoinCommunity(communityId);
      notifyListeners();

      if (effUser.isNotEmpty) {
        // 1. Cloud Firestore update
        if (Firebase.apps.isNotEmpty) {
          try {
            final docRef = FirebaseFirestore.instance.collection('communities').doc(communityId);
            if (newJoined) {
              docRef.update({
                'members': FieldValue.arrayUnion([effUser]),
                'memberCount': FieldValue.increment(1),
              });
            } else {
              docRef.update({
                'members': FieldValue.arrayRemove([effUser]),
                'memberCount': FieldValue.increment(-1),
              });
            }
          } catch (e) {
            debugPrint('[CommunityProvider] Firestore toggleJoin notice: $e');
          }
        }

        // 2. Also notify API
        try {
          final updated = await ApiService().toggleJoinCommunity(communityId, userIdentifier: effUser);
          if (updated != null) {
            final idx = _communities.indexWhere((c) => c.id == communityId);
            if (idx != -1) {
              _communities[idx] = updated;
              LocalStoreService().addCommunity(updated);
              notifyListeners();
            }
          }
        } catch (_) {}
      }
    }
  }

  Community createCommunity({
    required String name,
    required String description,
    required String category,
    required String iconEmoji,
    required int bannerColorHex,
    String? regionId,
    String? regionName,
    String locationSpot = 'City / Campus Spot',
    String creatorId = 'user-hardik',
    bool isGroupType = true,
    List<String>? rules,
  }) {
    final effectiveRegionName = regionName ?? _selectedRegion?.name ?? 'DDU, Nadiad, Gujarat';
    final effectiveRegionId = regionId ?? 'region_${effectiveRegionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final cleanCreator = creatorId.toLowerCase().replaceAll('@', '');

    addLocation(effectiveRegionName);

    final newCommunity = Community(
      id: const Uuid().v4(),
      name: name,
      description: description,
      regionId: effectiveRegionId,
      regionName: effectiveRegionName,
      locationSpot: locationSpot,
      creatorId: cleanCreator,
      category: category,
      memberCount: 1,
      questionCount: 0,
      iconEmoji: iconEmoji,
      bannerColorHex: bannerColorHex,
      isJoined: true,
      isGroupType: isGroupType,
      members: [cleanCreator],
      rules: rules ?? [
        '1. Respect all members',
        '2. No spam or commercial promotions',
        '3. No abusive language or harassment',
        '4. Stay on topic and share relevant updates',
      ],
    );

    _communities.insert(0, newCommunity);
    LocalStoreService().addCommunity(newCommunity);
    notifyListeners();

    // 1. Cloud Firestore write
    if (Firebase.apps.isNotEmpty) {
      try {
        FirebaseFirestore.instance
            .collection('communities')
            .doc(newCommunity.id)
            .set({
              ...newCommunity.toJson(),
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('[CommunityProvider] Firestore createCommunity notice: $e');
      }
    }

    // 2. Also notify API
    ApiService().createCommunity(newCommunity).then((created) {
      if (created != null) {
        final idx = _communities.indexWhere((c) => c.id == newCommunity.id);
        if (idx != -1) {
          _communities[idx] = created.copyWith(isJoined: true);
          LocalStoreService().addCommunity(_communities[idx]);
          notifyListeners();
        }
      }
    }).catchError((_) {});

    return newCommunity;
  }

  bool deleteCommunity(String communityId, String currentUserId, {String? currentUsername}) {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index != -1) {
      final comm = _communities[index];
      final cleanUid = currentUserId.toLowerCase().replaceAll('@', '').trim();
      final cleanUname = (currentUsername ?? '').toLowerCase().replaceAll('@', '').trim();
      final cleanCreator = comm.creatorId.toLowerCase().replaceAll('@', '').trim();

      final isAllowed = cleanCreator.isEmpty ||
          cleanUid.isEmpty ||
          cleanCreator == cleanUid ||
          (cleanUname.isNotEmpty && cleanCreator == cleanUname) ||
          cleanCreator == 'user-hardik' ||
          cleanCreator == 'admin';

      if (isAllowed) {
        _communities.removeAt(index);
        LocalStoreService().deleteCommunity(communityId);

        // 1. Cloud Firestore delete
        if (Firebase.apps.isNotEmpty) {
          try {
            FirebaseFirestore.instance.collection('communities').doc(communityId).delete();
          } catch (_) {}
        }

        // 2. Also notify API
        ApiService().deleteCommunity(communityId, currentUserId);
        notifyListeners();
        return true;
      }
    }
    return false;
  }
}
