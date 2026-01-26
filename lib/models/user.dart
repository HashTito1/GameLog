class User {
  final String id;
  final String username;
  final String email;
  final String profileImage;
  final String bio;
  final int gamesPlayed;
  final int reviewsWritten;
  final int followers;
  final int following;
  final DateTime joinDate;
  final String displayName;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.profileImage,
    required this.bio,
    required this.gamesPlayed,
    required this.reviewsWritten,
    required this.followers,
    required this.following,
    required this.joinDate,
    required this.displayName,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'] ?? '',
      bio: map['bio'] ?? '',
      gamesPlayed: map['gamesPlayed'] ?? 0,
      reviewsWritten: map['reviewsWritten'] ?? 0,
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
      joinDate: map['joinDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['joinDate'])
          : DateTime.now(),
      displayName: map['displayName'] ?? map['username'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profileImage': profileImage,
      'bio': bio,
      'gamesPlayed': gamesPlayed,
      'reviewsWritten': reviewsWritten,
      'followers': followers,
      'following': following,
      'joinDate': joinDate.millisecondsSinceEpoch,
      'displayName': displayName,
    };
  }
}


