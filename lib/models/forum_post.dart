class ForumPost {
  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorProfileImage;
  final String title;
  final String content;
  final String? gameId; // Optional: if post is related to a specific game
  final String? gameTitle;
  final List<String> tags;
  final String? parentPostId; // For replies - null for top-level posts
  final int replyCount;
  final int likeCount;
  final List<String> likedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isPinned;
  final bool isLocked;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorProfileImage,
    required this.title,
    required this.content,
    this.gameId,
    this.gameTitle,
    this.tags = const [],
    this.parentPostId,
    this.replyCount = 0,
    this.likeCount = 0,
    this.likedBy = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.isPinned = false,
    this.isLocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorDisplayName': authorDisplayName,
      'authorProfileImage': authorProfileImage,
      'title': title,
      'content': content,
      'gameId': gameId,
      'gameTitle': gameTitle,
      'tags': tags,
      'parentPostId': parentPostId,
      'replyCount': replyCount,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isEdited': isEdited,
      'isPinned': isPinned,
      'isLocked': isLocked,
    };
  }

  factory ForumPost.fromMap(Map<String, dynamic> map) {
    return ForumPost(
      id: map['id'] ?? '',
      authorId: map['authorId'] ?? '',
      authorUsername: map['authorUsername'] ?? '',
      authorDisplayName: map['authorDisplayName'],
      authorProfileImage: map['authorProfileImage'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      gameId: map['gameId'],
      gameTitle: map['gameTitle'],
      tags: List<String>.from(map['tags'] ?? []),
      parentPostId: map['parentPostId'],
      replyCount: map['replyCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
      isEdited: map['isEdited'] ?? false,
      isPinned: map['isPinned'] ?? false,
      isLocked: map['isLocked'] ?? false,
    );
  }

  ForumPost copyWith({
    String? id,
    String? authorId,
    String? authorUsername,
    String? authorDisplayName,
    String? authorProfileImage,
    String? title,
    String? content,
    String? gameId,
    String? gameTitle,
    List<String>? tags,
    String? parentPostId,
    int? replyCount,
    int? likeCount,
    List<String>? likedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    bool? isPinned,
    bool? isLocked,
  }) {
    return ForumPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      title: title ?? this.title,
      content: content ?? this.content,
      gameId: gameId ?? this.gameId,
      gameTitle: gameTitle ?? this.gameTitle,
      tags: tags ?? this.tags,
      parentPostId: parentPostId ?? this.parentPostId,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  bool get isReply => parentPostId != null;
  bool get isTopLevel => parentPostId == null;
}