class GamePlaylist {
  final String id;
  final String name;
  final String description;
  final String userId;
  final List<PlaylistGame> games;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  GamePlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    required this.games,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
  });

  factory GamePlaylist.fromMap(Map<String, dynamic> map) {
    return GamePlaylist(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      userId: map['userId'] ?? '',
      games: (map['games'] as List<dynamic>?)
          ?.map((game) => PlaylistGame.fromMap(game as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
      isPublic: map['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'userId': userId,
      'games': games.map((game) => game.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isPublic': isPublic,
    };
  }

  GamePlaylist copyWith({
    String? id,
    String? name,
    String? description,
    String? userId,
    List<PlaylistGame>? games,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
  }) {
    return GamePlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      games: games ?? this.games,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

class PlaylistGame {
  final String gameId;
  final String gameTitle;
  final String gameCoverImage;
  final String gameDeveloper;
  final List<String> gameGenres;
  final DateTime addedAt;

  PlaylistGame({
    required this.gameId,
    required this.gameTitle,
    required this.gameCoverImage,
    required this.gameDeveloper,
    required this.gameGenres,
    required this.addedAt,
  });

  factory PlaylistGame.fromMap(Map<String, dynamic> map) {
    return PlaylistGame(
      gameId: map['gameId'] ?? '',
      gameTitle: map['gameTitle'] ?? '',
      gameCoverImage: map['gameCoverImage'] ?? '',
      gameDeveloper: map['gameDeveloper'] ?? '',
      gameGenres: List<String>.from(map['gameGenres'] ?? []),
      addedAt: map['addedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'gameTitle': gameTitle,
      'gameCoverImage': gameCoverImage,
      'gameDeveloper': gameDeveloper,
      'gameGenres': gameGenres,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }
}