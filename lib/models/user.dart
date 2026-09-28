class User {
  final String id;
  final String username; // Unique primary key handle (e.g. 'hardik')
  final String name;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? avatarUrl;
  final String campusOrCity;
  final String? majorOrBio;
  final int reputation;
  final List<String> joinedCommunityIds;
  final List<String> badges;
  final bool isCollegeVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.name,
    this.firstName,
    this.lastName,
    required this.email,
    this.avatarUrl,
    required this.campusOrCity,
    this.majorOrBio,
    this.reputation = 50,
    this.joinedCommunityIds = const [],
    this.badges = const ['Newcomer'],
    this.isCollegeVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  // Getters for standardized Firebase field names
  String get uid => id;
  String get displayName => name;
  String get photoUrl => avatarUrl ?? '';
  String get handle => '@$username';

  String get rank {
    if (reputation >= 300) return 'Platinum';
    if (reputation >= 150) return 'Gold';
    if (reputation >= 50) return 'Silver';
    return 'Bronze';
  }

  String get rankEmoji {
    if (reputation >= 300) return '💎';
    if (reputation >= 150) return '🥇';
    if (reputation >= 50) return '🥈';
    return '🥉';
  }

  int get nextRankThreshold {
    if (reputation < 50) return 50;
    if (reputation < 150) return 150;
    if (reputation < 300) return 300;
    return 300;
  }

  User copyWith({
    String? id,
    String? username,
    String? name,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    String? campusOrCity,
    String? majorOrBio,
    int? reputation,
    List<String>? joinedCommunityIds,
    List<String>? badges,
    bool? isCollegeVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      campusOrCity: campusOrCity ?? this.campusOrCity,
      majorOrBio: majorOrBio ?? this.majorOrBio,
      reputation: reputation ?? this.reputation,
      joinedCommunityIds: joinedCommunityIds ?? this.joinedCommunityIds,
      badges: badges ?? this.badges,
      isCollegeVerified: isCollegeVerified ?? this.isCollegeVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': id,
      'username': username,
      'normalizedUsername': username.toLowerCase().trim(),
      'name': name,
      'displayName': name,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'avatarUrl': avatarUrl,
      'photoUrl': avatarUrl,
      'campusOrCity': campusOrCity,
      'majorOrBio': majorOrBio,
      'bio': majorOrBio,
      'reputation': reputation,
      'joinedCommunityIds': joinedCommunityIds,
      'badges': badges,
      'isCollegeVerified': isCollegeVerified,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? json['displayName'] as String? ?? 'User';
    final parts = rawName.trim().split(' ');
    final fName = json['firstName'] as String? ?? (parts.isNotEmpty ? parts.first : 'User');
    final lName = json['lastName'] as String? ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
    final uname = json['username'] as String? ??
        rawName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    return User(
      id: json['id'] as String? ?? json['uid'] as String? ?? json['_id']?.toString() ?? '',
      username: uname.isEmpty ? 'user' : uname,

      name: rawName,
      firstName: fName,
      lastName: lName,
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['photoUrl'] as String?,
      campusOrCity: json['campusOrCity'] as String? ?? json['city'] as String? ?? 'DDU, Nadiad',
      majorOrBio: json['majorOrBio'] as String? ?? json['bio'] as String?,
      reputation: json['reputation'] as int? ?? 50,
      joinedCommunityIds: List<String>.from(json['joinedCommunityIds'] ?? []),
      badges: List<String>.from(json['badges'] ?? ['Newcomer']),
      isCollegeVerified: json['isCollegeVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt'] as String)
              : null)
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is String
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null)
          : null,
    );
  }

  factory User.fromFirestore(Map<String, dynamic> data, String docId) {
    return User.fromJson({
      ...data,
      'id': docId,
      'uid': docId,
    });
  }
}
