class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendUsername;
  final String friendDisplayName;
  final String? friendProfileImage;
  final DateTime createdAt;
  final FriendStatus status;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendUsername,
    required this.friendDisplayName,
    this.friendProfileImage,
    required this.createdAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'friendUsername': friendUsername,
      'friendDisplayName': friendDisplayName,
      'friendProfileImage': friendProfileImage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.toString(),
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      friendId: map['friendId'] ?? '',
      friendUsername: map['friendUsername'] ?? '',
      friendDisplayName: map['friendDisplayName'] ?? '',
      friendProfileImage: map['friendProfileImage'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      status: FriendStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => FriendStatus.pending,
      ),
    );
  }

  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendUsername,
    String? friendDisplayName,
    String? friendProfileImage,
    DateTime? createdAt,
    FriendStatus? status,
  }) {
    return Friend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      friendUsername: friendUsername ?? this.friendUsername,
      friendDisplayName: friendDisplayName ?? this.friendDisplayName,
      friendProfileImage: friendProfileImage ?? this.friendProfileImage,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String fromDisplayName;
  final String? fromProfileImage;
  final String toUserId;
  final String toUsername;
  final String toDisplayName;
  final String? toProfileImage;
  final DateTime createdAt;
  final FriendRequestStatus status;
  final String? message;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromDisplayName,
    this.fromProfileImage,
    required this.toUserId,
    required this.toUsername,
    required this.toDisplayName,
    this.toProfileImage,
    required this.createdAt,
    required this.status,
    this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
      'fromProfileImage': fromProfileImage,
      'toUserId': toUserId,
      'toUsername': toUsername,
      'toDisplayName': toDisplayName,
      'toProfileImage': toProfileImage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.toString(),
      'message': message,
    };
  }

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      id: map['id'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUsername: map['fromUsername'] ?? '',
      fromDisplayName: map['fromDisplayName'] ?? '',
      fromProfileImage: map['fromProfileImage'],
      toUserId: map['toUserId'] ?? '',
      toUsername: map['toUsername'] ?? '',
      toDisplayName: map['toDisplayName'] ?? '',
      toProfileImage: map['toProfileImage'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      message: map['message'],
    );
  }

  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? fromUsername,
    String? fromDisplayName,
    String? fromProfileImage,
    String? toUserId,
    String? toUsername,
    String? toDisplayName,
    String? toProfileImage,
    DateTime? createdAt,
    FriendRequestStatus? status,
    String? message,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      fromDisplayName: fromDisplayName ?? this.fromDisplayName,
      fromProfileImage: fromProfileImage ?? this.fromProfileImage,
      toUserId: toUserId ?? this.toUserId,
      toUsername: toUsername ?? this.toUsername,
      toDisplayName: toDisplayName ?? this.toDisplayName,
      toProfileImage: toProfileImage ?? this.toProfileImage,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

enum FriendStatus {
  pending,
  accepted,
  blocked,
}

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
}

enum FriendshipStatus {
  none,
  friends,
  requestSent,
  requestReceived,
  self,
}

class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String email;
  final String? bio;
  final String? profileImage;
  final String? bannerImage;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  final int totalGames;
  final int ratedGames;
  final double averageRating;

  UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    this.bio,
    this.profileImage,
    this.bannerImage,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isOnline,
    required this.totalGames,
    required this.ratedGames,
    required this.averageRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'profileImage': profileImage,
      'bannerImage': bannerImage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'totalGames': totalGames,
      'ratedGames': ratedGames,
      'averageRating': averageRating,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      bio: map['bio'],
      profileImage: map['profileImage'],
      bannerImage: map['bannerImage'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt'] ?? 0),
      isOnline: map['isOnline'] ?? false,
      totalGames: map['totalGames'] ?? 0,
      ratedGames: map['ratedGames'] ?? 0,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
    );
  }
}


