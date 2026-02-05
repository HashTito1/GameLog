import 'package:cloud_firestore/cloud_firestore.dart';

class UserRating {
  final String id;
  final String gameId;
  final String userId;
  final String username;
  final String? profileImage;
  final String? displayName;
  final double rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final List<String> likedBy;
  final int commentCount;

  UserRating({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.username,
    this.profileImage,
    this.displayName,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.likeCount = 0,
    this.likedBy = const [],
    this.commentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'userId': userId,
      'username': username,
      'profileImage': profileImage,
      'displayName': displayName,
      'rating': rating,
      'review': review,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'commentCount': commentCount,
    };
  }

  factory UserRating.fromMap(Map<String, dynamic> map) {
    return UserRating(
      id: map['id'] ?? '',
      gameId: map['gameId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      profileImage: map['profileImage'],
      displayName: map['displayName'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['createdAt']))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] is Timestamp 
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['updatedAt']))
          : DateTime.now(),
      likeCount: map['likeCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentCount: map['commentCount'] ?? 0,
    );
  }

  UserRating copyWith({
    String? id,
    String? gameId,
    String? userId,
    String? username,
    String? profileImage,
    String? displayName,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    List<String>? likedBy,
    int? commentCount,
  }) {
    return UserRating(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      displayName: displayName ?? this.displayName,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}


