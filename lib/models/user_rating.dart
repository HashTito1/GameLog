class UserRating {
  final String id;
  final String gameId;
  final String userId;
  final String username;
  final double rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserRating({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.username,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'userId': userId,
      'username': username,
      'rating': rating,
      'review': review,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserRating.fromMap(Map<String, dynamic> map) {
    return UserRating(
      id: map['id'] ?? '',
      gameId: map['gameId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  UserRating copyWith({
    String? id,
    String? gameId,
    String? userId,
    String? username,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserRating(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


