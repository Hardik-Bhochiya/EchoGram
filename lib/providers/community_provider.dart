import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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

  List<Region> get regions => _regions;
  List<Community> get communities => _communities;
  List<Community> get allCommunities => _communities;
  Region? get selectedRegion => _selectedRegion;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<String> get locations => LocalStoreService().getLocations();

  CommunityProvider() {
    _loadCommunities();
    // Periodically poll backend for cross-device consistency (e.g. mobile created community appears on laptop)
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshCommunities();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
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

  Future<void> refreshCommunities() async {
    try {
      final remoteList = await ApiService().getCommunities();
      final Map<String, Community> map = {};
      bool hasChanges = false;
      for (final rc in remoteList) {
        final existingIdx = _communities.indexWhere((c) => c.id == rc.id);
        final isJoined = existingIdx != -1 ? _communities[existingIdx].isJoined : false;
        map[rc.id] = rc.copyWith(isJoined: isJoined);
        LocalStoreService().addCommunity(map[rc.id]!);
        addLocation(rc.regionName);
        if (existingIdx == -1 || _communities[existingIdx].memberCount != rc.memberCount) {
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

  List<Community> get joinedCommunities {
    return _communities.where((c) => c.isJoined).toList();
  }

  List<Community> get filteredCommunities {
    return _communities.where((c) {
      final matchesRegion = _selectedRegion == null || c.regionId == _selectedRegion!.id;
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRegion && matchesCategory && matchesSearch;
    }).toList();
  }

  Community? getCommunityById(String id) {
    try {
      return _communities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void toggleJoinCommunity(String communityId) {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index != -1) {
      final current = _communities[index];
      final newJoined = !current.isJoined;
      final newCount = newJoined ? current.memberCount + 1 : current.memberCount - 1;
      _communities[index] = current.copyWith(
        isJoined: newJoined,
        memberCount: newCount < 0 ? 0 : newCount,
      );
      LocalStoreService().toggleJoinCommunity(communityId);
      notifyListeners();
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
    List<String>? rules,
  }) {
    final effectiveRegionName = regionName ?? _selectedRegion?.name ?? 'Nadiad';
    final effectiveRegionId = regionId ?? 'region_${effectiveRegionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

    // Auto-register location in the app's dynamic location registry
    addLocation(effectiveRegionName);

    final newCommunity = Community(
      id: const Uuid().v4(),
      name: name,
      description: description,
      regionId: effectiveRegionId,
      regionName: effectiveRegionName,
      locationSpot: locationSpot,
      creatorId: creatorId,
      category: category,
      memberCount: 1,
      questionCount: 0,
      iconEmoji: iconEmoji,
      bannerColorHex: bannerColorHex,
      isJoined: true,
      rules: rules ?? [
        '1. Respect all members',
        '2. No spam or commercial promotions',
        '3. No abusive language or harassment',
        '4. Stay on topic and share relevant updates',
      ],
    );

    _communities.insert(0, newCommunity);
    LocalStoreService().addCommunity(newCommunity);
    ApiService().createCommunity(newCommunity);
    notifyListeners();
    return newCommunity;
  }

  bool deleteCommunity(String communityId, String currentUserId) {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index != -1) {
      final comm = _communities[index];
      // Creator can delete their community
      if (comm.creatorId == currentUserId || currentUserId.isEmpty) {
        _communities.removeAt(index);
        LocalStoreService().deleteCommunity(communityId);
        ApiService().deleteCommunity(communityId, currentUserId);
        notifyListeners();
        return true;
      }
    }
    return false;
  }
}
