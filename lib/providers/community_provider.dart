import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/region.dart';
import '../models/community.dart';
import '../services/local_store_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class CommunityProvider extends ChangeNotifier {
  List<Region> _regions = [];
  List<Community> _communities = [];
  Region? _selectedRegion;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  Timer? _syncTimer;
  StreamSubscription? _firestoreSub;
  StreamSubscription? _socketCommunitySub;
  StreamSubscription? _socketMemberUpdatedSub;
  StreamSubscription? _socketCommunityDeletedSub;
  String? _activeUserIdentifier;
  String? _activeUserId;
  String? _activeUsername;

  List<Region> get regions => _regions;
  Region? get selectedRegion => _selectedRegion;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<String> get locations => LocalStoreService().getLocations();

  CommunityProvider() {
    _loadCommunities();
    _initFirestoreListener();
    _initSocketListener();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (Firebase.apps.isEmpty) {
        refreshCommunities(userIdentifier: _activeUserIdentifier);
      }
    });
  }

  /// Sets the currently authenticated user's identifiers and refreshes community membership state
  void setActiveUser({String? userId, String? username}) {
    final cleanId = userId?.toLowerCase().replaceAll('@', '').trim();
    final cleanName = username?.toLowerCase().replaceAll('@', '').trim();
    final newIdentifier = (cleanId != null && cleanId.isNotEmpty) ? cleanId : cleanName;

    if (_activeUserId != cleanId || _activeUsername != cleanName || _activeUserIdentifier != newIdentifier) {
      _activeUserId = cleanId;
      _activeUsername = cleanName;
      _activeUserIdentifier = newIdentifier;
      _recalculateJoinedStatus();
      refreshCommunities(userIdentifier: _activeUserIdentifier);
    }
  }

  void _recalculateJoinedStatus() {
    final cleanUser = (_activeUserIdentifier ?? '').toLowerCase().replaceAll('@', '').trim();
    for (int i = 0; i < _communities.length; i++) {
      final c = _communities[i];
      final cleanCreator = c.creatorId.toLowerCase().replaceAll('@', '').trim();
      final isCreator = (_activeUserId != null && _activeUserId!.isNotEmpty && cleanCreator == _activeUserId) ||
          (_activeUsername != null && _activeUsername!.isNotEmpty && cleanCreator == _activeUsername);
      final isMember = (cleanUser.isNotEmpty && c.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == cleanUser)) ||
          (_activeUserId != null && _activeUserId!.isNotEmpty && c.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUserId)) ||
          (_activeUsername != null && _activeUsername!.isNotEmpty && c.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUsername));
      final bool isJoined = isCreator || isMember;
      _communities[i] = c.copyWith(isJoined: isJoined);
    }
    notifyListeners();
  }

  void _initSocketListener() {
    _socketCommunitySub?.cancel();
    // Real-time group / community addition listener from Socket.IO:
    // When another account creates a group, it immediately appears on this client with Join button!
    _socketCommunitySub = SocketService().onCommunityCreated.listen((data) {
      try {
        final incoming = Community.fromJson(data);
        final cleanCreator = incoming.creatorId.toLowerCase().replaceAll('@', '').trim();

        // Check if the current user is the creator or already in the members array
        final isCreator = (_activeUserId != null && _activeUserId!.isNotEmpty && cleanCreator == _activeUserId) ||
            (_activeUsername != null && _activeUsername!.isNotEmpty && cleanCreator == _activeUsername);
        final isMember = (_activeUserId != null && _activeUserId!.isNotEmpty && incoming.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUserId)) ||
            (_activeUsername != null && _activeUsername!.isNotEmpty && incoming.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUsername));

        // If I created it or am in members, isJoined = true. Otherwise, isJoined = false (shows "Join" button)!
        final bool isJoinedForMe = isCreator || isMember;
        final newComm = incoming.copyWith(isJoined: isJoinedForMe);

        final existingIdx = _communities.indexWhere((c) => c.id == newComm.id);
        if (existingIdx != -1) {
          _communities[existingIdx] = newComm;
        } else {
          _communities.insert(0, newComm);
        }
        LocalStoreService().addCommunity(newComm);
        _syncRegions();
        notifyListeners();
        debugPrint('[CommunityProvider] Real-time community received: "${newComm.name}" (isJoinedForMe: $isJoinedForMe)');
      } catch (e) {
        debugPrint('[CommunityProvider] onCommunityCreated processing error: $e');
      }
    });

    _socketMemberUpdatedSub?.cancel();
    // Real-time membership/memberCount update listener:
    // When any user joins or leaves a group, other users see the updated member count instantly without refreshing!
    _socketMemberUpdatedSub = SocketService().onCommunityMemberUpdated.listen((data) {
      try {
        final targetId = data['communityId']?.toString();
        if (targetId == null || targetId.isEmpty) return;

        final newCount = data['memberCount'] is int
            ? data['memberCount'] as int
            : (int.tryParse(data['memberCount']?.toString() ?? '') ?? 1);
        final rawMembers = data['members'] as List<dynamic>?;
        final updatedMembers = rawMembers?.map((e) => e.toString()).toList();

        final action = data['action']?.toString();
        final actionUser = data['userId']?.toString().toLowerCase().replaceAll('@', '').trim();
        final actionObjectId = data['userObjectId']?.toString().toLowerCase().trim();
        final actionUsername = data['username']?.toString().toLowerCase().replaceAll('@', '').trim();

        // Check if this action was taken by the current user
        final bool isMe = (actionUser != null && actionUser.isNotEmpty && (_activeUserId == actionUser || _activeUsername == actionUser)) ||
            (actionObjectId != null && actionObjectId.isNotEmpty && (_activeUserId == actionObjectId || _activeUsername == actionObjectId)) ||
            (actionUsername != null && actionUsername.isNotEmpty && (_activeUserId == actionUsername || _activeUsername == actionUsername));

        final idx = _communities.indexWhere((c) => c.id == targetId);
        if (idx != -1) {
          final oldComm = _communities[idx];
          // If it was me who joined/left, update isJoined. Otherwise preserve current isJoined state.
          final updatedJoined = isMe
              ? (action == 'join')
              : oldComm.isJoined;

          final updatedComm = oldComm.copyWith(
            memberCount: newCount,
            members: updatedMembers ?? oldComm.members,
            isJoined: updatedJoined,
          );

          _communities[idx] = updatedComm;
          LocalStoreService().addCommunity(updatedComm);
          notifyListeners();
          debugPrint('[CommunityProvider] Real-time member count updated: "${updatedComm.name}" -> $newCount members (isMe: $isMe, isJoined: $updatedJoined)');
        }
      } catch (e) {
        debugPrint('[CommunityProvider] onCommunityMemberUpdated error: $e');
      }
    });

    _socketCommunityDeletedSub?.cancel();
    // Real-time community deletion listener
    _socketCommunityDeletedSub = SocketService().onCommunityDeleted.listen((data) {
      try {
        final targetId = data['communityId']?.toString();
        if (targetId == null || targetId.isEmpty) return;

        final idx = _communities.indexWhere((c) => c.id == targetId);
        if (idx != -1) {
          _communities.removeAt(idx);
          LocalStoreService().deleteCommunity(targetId);
          _syncRegions();
          notifyListeners();
          debugPrint('[CommunityProvider] Real-time group deleted without refresh: $targetId');
        }
      } catch (e) {
        debugPrint('[CommunityProvider] onCommunityDeleted error: $e');
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _firestoreSub?.cancel();
    _socketCommunitySub?.cancel();
    _socketMemberUpdatedSub?.cancel();
    _socketCommunityDeletedSub?.cancel();
    super.dispose();
  }

  void _initFirestoreListener() {
    _firestoreSub?.cancel();
    // Bypassed: Communities sync directly with local MongoDB via ApiService.
    // Disabling Firestore stream prevents ghost communities (ABC, APC, Nadiad Hustlers) from reappearing.
    return;
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
        category: 'General',
        description: 'Community members in $name',
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
      final cleanUser = (_activeUserIdentifier ?? '').toLowerCase().replaceAll('@', '').trim();

      for (final rc in remoteList) {
        final cName = rc.name.toLowerCase();
        if (rc.id.startsWith('c') ||
            cName.contains('canteen') ||
            cName.contains('hostel') ||
            cName.contains('robotics') ||
            rc.creatorId == 'rahul123') {
          continue;
        }

        final cleanCreator = rc.creatorId.toLowerCase().replaceAll('@', '').trim();
        final isCreator = (_activeUserId != null && _activeUserId!.isNotEmpty && cleanCreator == _activeUserId) ||
            (_activeUsername != null && _activeUsername!.isNotEmpty && cleanCreator == _activeUsername);
        final isMember = (cleanUser.isNotEmpty && rc.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == cleanUser)) ||
            (_activeUserId != null && _activeUserId!.isNotEmpty && rc.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUserId)) ||
            (_activeUsername != null && _activeUsername!.isNotEmpty && rc.members.any((m) => m.toLowerCase().replaceAll('@', '').trim() == _activeUsername));

        // Join status is determined dynamically: creator ownership or explicit membership.
        // Never bleed sticky local wasJoined so unjoined communities correctly show the 'Join' button.
        final bool isJoined = isCreator || isMember;

        final updated = rc.copyWith(isJoined: isJoined);
        map[rc.id] = updated;
        LocalStoreService().addCommunity(updated);
        LocalStoreService().addLocation(rc.regionName);
        final existingIdx = _communities.indexWhere((c) => c.id == rc.id);
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

      final effUser = (userIdentifier ?? _activeUserIdentifier ?? _activeUserId ?? _activeUsername ?? '').toLowerCase().replaceAll('@', '').trim();
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
      LocalStoreService().addCommunity(_communities[index]);
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
              _communities[idx] = updated.copyWith(isJoined: newJoined);
              LocalStoreService().addCommunity(_communities[idx]);
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
    String locationSpot = 'General',
    String creatorId = 'user-hardik',
    bool isGroupType = true,
    List<String>? rules,
  }) {
    final effectiveRegionName = regionName ?? _selectedRegion?.name ?? 'General';
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
