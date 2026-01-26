class AuthUser {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? profileImage;
  final String? bannerImage;
  final String? bio;
  final String? favoriteGameId;
  final String? favoriteGameName;
  final String? favoriteGameImage;
  final List<GamePlaylist> playlists;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isEmailVerified;
  final UserPreferences preferences;

  AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.profileImage,
    this.bannerImage,
    this.bio,
    this.favoriteGameId,
    this.favoriteGameName,
    this.favoriteGameImage,
    this.playlists = const [],
    required this.createdAt,
    required this.lastLoginAt,
    required this.isEmailVerified,
    required this.preferences,
  });

  // Getter for uid to maintain compatibility
  String get uid => id;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      displayName: json['displayName'],
      profileImage: json['profileImage'],
      bannerImage: json['bannerImage'],
      bio: json['bio'],
      favoriteGameId: json['favoriteGameId'],
      favoriteGameName: json['favoriteGameName'],
      favoriteGameImage: json['favoriteGameImage'],
      playlists: (json['playlists'] as List<dynamic>?)
          ?.map((playlist) => GamePlaylist.fromJson(playlist))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      lastLoginAt: DateTime.parse(json['lastLoginAt']),
      isEmailVerified: json['isEmailVerified'] ?? false,
      preferences: UserPreferences.fromJson(json['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'profileImage': profileImage,
      'bannerImage': bannerImage,
      'bio': bio,
      'favoriteGameId': favoriteGameId,
      'favoriteGameName': favoriteGameName,
      'favoriteGameImage': favoriteGameImage,
      'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'preferences': preferences.toJson(),
    };
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? profileImage,
    String? bannerImage,
    String? bio,
    String? favoriteGameId,
    String? favoriteGameName,
    String? favoriteGameImage,
    List<GamePlaylist>? playlists,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isEmailVerified,
    UserPreferences? preferences,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
      bannerImage: bannerImage ?? this.bannerImage,
      bio: bio ?? this.bio,
      favoriteGameId: favoriteGameId ?? this.favoriteGameId,
      favoriteGameName: favoriteGameName ?? this.favoriteGameName,
      favoriteGameImage: favoriteGameImage ?? this.favoriteGameImage,
      playlists: playlists ?? this.playlists,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      preferences: preferences ?? this.preferences,
    );
  }
}

class UserPreferences {
  final bool darkMode;
  final String language;
  final bool notificationsEnabled;
  final bool publicProfile;
  final List<String> favoriteGenres;

  UserPreferences({
    this.darkMode = true,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.publicProfile = true,
    this.favoriteGenres = const [],
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      darkMode: json['darkMode'] ?? true,
      language: json['language'] ?? 'en',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      publicProfile: json['publicProfile'] ?? true,
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'publicProfile': publicProfile,
      'favoriteGenres': favoriteGenres,
    };
  }
}

class GamePlaylist {
  final String id;
  final String name;
  final String description;
  final List<PlaylistGame> games;
  final DateTime createdAt;
  final DateTime updatedAt;

  GamePlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.games,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GamePlaylist.fromJson(Map<String, dynamic> json) {
    return GamePlaylist(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      games: (json['games'] as List<dynamic>?)
          ?.map((game) => PlaylistGame.fromJson(game))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'games': games.map((game) => game.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  GamePlaylist copyWith({
    String? id,
    String? name,
    String? description,
    List<PlaylistGame>? games,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GamePlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      games: games ?? this.games,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PlaylistGame {
  final String gameId;
  final String gameName;
  final String? gameImage;
  final DateTime addedAt;

  PlaylistGame({
    required this.gameId,
    required this.gameName,
    this.gameImage,
    required this.addedAt,
  });

  factory PlaylistGame.fromJson(Map<String, dynamic> json) {
    return PlaylistGame(
      gameId: json['gameId'],
      gameName: json['gameName'],
      gameImage: json['gameImage'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'gameName': gameName,
      'gameImage': gameImage,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}


