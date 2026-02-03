class RatingComment {
  final String id;
  final String ratingId; // The rating this comment belongs to
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorProfileImage;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final int likeCount;
  final List<String> likedBy;

  RatingComment({
    required this.id,
    required this.ratingId,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorProfileImage,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.likeCount = 0,
    this.likedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ratingId': ratingId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorDisplayName': authorDisplayName,
      'authorProfileImage': authorProfileImage,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isEdited': isEdited,
      'likeCount': likeCount,
      'likedBy': likedBy,
    };
  }

  factory RatingComment.fromMap(Map<String, dynamic> map) {
    return RatingComment(
      id: map['id'] ?? '',
      ratingId: map['ratingId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorUsername: map['authorUsername'] ?? '',
      authorDisplayName: map['authorDisplayName'],
      authorProfileImage: map['authorProfileImage'],
      content: map['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
      isEdited: map['isEdited'] ?? false,
      likeCount: map['likeCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
    );
  }

  RatingComment copyWith({
    String? id,
    String? ratingId,
    String? authorId,
    String? authorUsername,
    String? authorDisplayName,
    String? authorProfileImage,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    int? likeCount,
    List<String>? likedBy,
  }) {
    return RatingComment(
      id: id ?? this.id,
      ratingId: ratingId ?? this.ratingId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}