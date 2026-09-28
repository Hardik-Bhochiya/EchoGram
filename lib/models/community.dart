class Community {
  final String id;
  final String name;
  final String description;
  final String regionId;
  final String regionName;
  final String locationSpot; // e.g. 'DDU Library', 'Campus Canteen', 'Sports Ground'
  final String creatorId; // WhatsApp-style creator ID who can delete the group
  final String category; // 'Campus', 'Academics', 'Housing', 'Food & Dining', 'Tech & Clubs', 'Sports'
  final int memberCount;
  final int questionCount;
  final String iconEmoji;
  final int bannerColorHex;
  final bool isJoined;
  final List<String> rules;
  final List<String> members;

  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.regionId,
    required this.regionName,
    this.locationSpot = 'DDU Campus',
    this.creatorId = '',
    required this.category,
    required this.memberCount,
    required this.questionCount,
    required this.iconEmoji,
    required this.bannerColorHex,
    this.isJoined = false,
    this.rules = const [
      'Respect & Civility: Treat all members with dignity. No harassment, abusive words, or bullying.',
      'Authentic Local Info: Keep questions and discussions genuine and relevant to this community.',
      'No Spam or Ads: Commercial promotions, phishing links, and repetitive spam are strictly prohibited.',
      'Privacy & Anonymity: Respect anonymity of posters. Never attempt to expose real identities.',
      'Academic & Campus Integrity: Abide by student conduct guidelines and community safety standards.',
    ],
    this.members = const [],
  });

  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? regionId,
    String? regionName,
    String? locationSpot,
    String? creatorId,
    String? category,
    int? memberCount,
    int? questionCount,
    String? iconEmoji,
    int? bannerColorHex,
    bool? isJoined,
    List<String>? rules,
    List<String>? members,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      regionId: regionId ?? this.regionId,
      regionName: regionName ?? this.regionName,
      locationSpot: locationSpot ?? this.locationSpot,
      creatorId: creatorId ?? this.creatorId,
      category: category ?? this.category,
      memberCount: memberCount ?? this.memberCount,
      questionCount: questionCount ?? this.questionCount,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      bannerColorHex: bannerColorHex ?? this.bannerColorHex,
      isJoined: isJoined ?? this.isJoined,
      rules: rules ?? this.rules,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'regionId': regionId,
      'regionName': regionName,
      'locationSpot': locationSpot,
      'creatorId': creatorId,
      'category': category,
      'memberCount': memberCount,
      'questionCount': questionCount,
      'iconEmoji': iconEmoji,
      'bannerColorHex': bannerColorHex,
      'isJoined': isJoined,
      'rules': rules,
      'members': members,
    };
  }

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      regionId: json['regionId'] as String? ?? 'default',
      regionName: json['regionName'] as String? ?? 'General Campus',
      locationSpot: json['locationSpot'] as String? ?? 'DDU Campus',
      creatorId: json['creatorId'] as String? ?? '',
      category: json['category'] as String? ?? 'Campus',
      memberCount: json['memberCount'] as int? ?? 0,
      questionCount: json['questionCount'] as int? ?? 0,
      iconEmoji: json['iconEmoji'] as String? ?? '🏛️',
      bannerColorHex: json['bannerColorHex'] as int? ?? 0xFF4F46E5,
      isJoined: json['isJoined'] as bool? ?? false,
      rules: List<String>.from(json['rules'] ?? []),
      members: List<String>.from(json['members'] ?? []),
    );
  }
}
