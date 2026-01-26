import 'package:flutter/material.dart';

class Game {
  final String id;
  final String title;
  final String developer;
  final String publisher;
  final String releaseDate;
  final List<String> platforms;
  final List<String> genres;
  final String coverImage;
  final String description;
  final double averageRating;
  final int totalReviews;

  Game({
    required this.id,
    required this.title,
    required this.developer,
    required this.publisher,
    required this.releaseDate,
    required this.platforms,
    required this.genres,
    required this.coverImage,
    required this.description,
    required this.averageRating,
    required this.totalReviews,
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'developer': developer,
      'publisher': publisher,
      'releaseDate': releaseDate,
      'platforms': platforms,
      'genres': genres,
      'coverImage': coverImage,
      'description': description,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      developer: json['developer'] ?? '',
      publisher: json['publisher'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
      platforms: List<String>.from(json['platforms'] ?? []),
      genres: List<String>.from(json['genres'] ?? []),
      coverImage: json['coverImage'] ?? '',
      description: json['description'] ?? '',
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
    );
  }
}

class GameReview {
  final String id;
  final String gameId;
  final String userId;
  final String username;
  final double rating;
  final String reviewText;
  final DateTime dateReviewed;
  final int likes;
  final bool isLiked;

  GameReview({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.username,
    required this.rating,
    required this.reviewText,
    required this.dateReviewed,
    required this.likes,
    required this.isLiked,
  });
}

class GameListEntry {
  final String id;
  final String gameId;
  final String userId;
  final GameStatus status;
  final double? rating;
  final DateTime dateAdded;
  final DateTime? dateCompleted;
  final int? hoursPlayed;

  GameListEntry({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.status,
    this.rating,
    required this.dateAdded,
    this.dateCompleted,
    this.hoursPlayed,
  });
}

enum GameStatus {
  playing,
  completed,
  dropped,
  planToPlay,
  rated,
  backlog,
}

extension GameStatusExtension on GameStatus {
  String get displayName {
    switch (this) {
      case GameStatus.playing:
        return 'Playing';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.dropped:
        return 'Dropped';
      case GameStatus.planToPlay:
        return 'Plan to Play';
      case GameStatus.rated:
        return 'Rated';
      case GameStatus.backlog:
        return 'Backlog';
    }
  }

  Color get color {
    switch (this) {
      case GameStatus.playing:
        return const Color(0xFF10B981);
      case GameStatus.completed:
        return const Color(0xFF6366F1);
      case GameStatus.dropped:
        return const Color(0xFFEF4444);
      case GameStatus.planToPlay:
        return const Color(0xFFF59E0B);
      case GameStatus.rated:
        return const Color(0xFFFBBF24); // Gold color for rated
      case GameStatus.backlog:
        return const Color(0xFF8B5CF6); // Purple color for backlog
    }
  }
}


