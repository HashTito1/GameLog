import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/library_service.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();
  static RecommendationService get instance => _instance;

  /// Recommend a game to a friend
  Future<bool> recommendGame({
    required String gameId,
    required String friendId,
    String? message,
  }) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // TODO: Implement actual recommendation storage in Firestore
      // For now, simulate the API call
      await Future.delayed(const Duration(milliseconds: 500));

      // In a real implementation, this would:
      // 1. Store the recommendation in Firestore
      // 2. Send a notification to the friend
      // 3. Update recommendation statistics

      if (kDebugMode) {
        print('Game $gameId recommended to friend $friendId by ${currentUser.id}');
        if (message != null) {
          print('Message: $message');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error recommending game: $e');
      }
      return false;
    }
  }

  /// Get similar games based on genres and tags
  Future<List<Game>> getSimilarGames(String gameId, {int limit = 6}) async {
    try {
      // Get the original game details
      final originalGame = await IGDBService.instance.getGameDetails(gameId);
      if (originalGame == null) {
        return [];
      }

      // Search for games with similar genres
      List<Game> similarGames = [];
      
      // Try to find games with matching genres
      for (final genre in originalGame.genres.take(2)) { // Use top 2 genres
        try {
          final genreGames = await IGDBService.instance.getGamesByGenre(
            genre.toLowerCase().replaceAll(' ', '-').replaceAll('(', '').replaceAll(')', ''),
            limit: 10,
          );
          
          // Filter out the original game and add to similar games
          final filteredGames = genreGames
              .where((game) => game.id != gameId)
              .take(3)
              .toList();
          
          similarGames.addAll(filteredGames);
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching games for genre $genre: $e');
          }
        }
      }

      // Remove duplicates and limit results
      final uniqueGames = <String, Game>{};
      for (final game in similarGames) {
        uniqueGames[game.id] = game;
      }

      final result = uniqueGames.values.take(limit).toList();
      
      // If we don't have enough similar games, fill with popular games
      if (result.length < limit) {
        try {
          final popularGames = await IGDBService.instance.getPopularGames(
            limit: limit - result.length + 5,
          );
          
          final additionalGames = popularGames
              .where((game) => 
                  game.id != gameId && 
                  !uniqueGames.containsKey(game.id))
              .take(limit - result.length)
              .toList();
          
          result.addAll(additionalGames);
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching popular games for similar games: $e');
          }
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting similar games: $e');
      }
      return [];
    }
  }

  /// Get personalized game recommendations for the current user
  Future<List<Game>> getPersonalizedRecommendations({int limit = 10}) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        return await _getFallbackRecommendations(limit);
      }

      // Get user's library data to analyze preferences
      final libraryData = await LibraryService.instance.getUserLibrary(currentUser.id, limit: 100);
      
      if (libraryData.isEmpty) {
        // New user with no library - return popular games
        return await _getFallbackRecommendations(limit);
      }

      // Analyze user preferences from library
      final preferences = _analyzeUserPreferences(libraryData);
      
      // Get recommendations based on preferences
      final recommendations = await _getRecommendationsFromPreferences(preferences, limit);
      
      // If we don't have enough recommendations, fill with popular games
      if (recommendations.length < limit) {
        final fallbackGames = await _getFallbackRecommendations(limit - recommendations.length);
        
        // Filter out games already in recommendations
        final existingIds = recommendations.map((g) => g.id).toSet();
        final filteredFallback = fallbackGames.where((g) => !existingIds.contains(g.id)).toList();
        
        recommendations.addAll(filteredFallback);
      }

      return recommendations.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting personalized recommendations: $e');
      }
      return await _getFallbackRecommendations(limit);
    }
  }

  /// Analyze user preferences from their library
  Map<String, dynamic> _analyzeUserPreferences(List<Map<String, dynamic>> libraryData) {
    final genreScores = <String, double>{};
    final developerScores = <String, double>{};
    final platformScores = <String, double>{};
    double totalRating = 0.0;
    int ratedGames = 0;
    
    for (final entry in libraryData) {
      final rating = (entry['userRating'] ?? 0.0).toDouble();
      final genres = List<String>.from(entry['gameGenres'] ?? []);
      final developer = entry['gameDeveloper'] ?? '';
      final platforms = List<String>.from(entry['gamePlatforms'] ?? []);
      
      // Only consider games with ratings for preference analysis
      if (rating > 0) {
        totalRating += rating;
        ratedGames++;
        
        // Weight preferences by rating (higher rated games have more influence)
        final weight = rating / 5.0; // Normalize to 0-1 scale
        
        // Analyze genre preferences
        for (final genre in genres) {
          if (genre.isNotEmpty) {
            genreScores[genre] = (genreScores[genre] ?? 0.0) + weight;
          }
        }
        
        // Analyze developer preferences
        if (developer.isNotEmpty && developer != 'Unknown Developer') {
          developerScores[developer] = (developerScores[developer] ?? 0.0) + weight;
        }
        
        // Analyze platform preferences
        for (final platform in platforms) {
          if (platform.isNotEmpty) {
            platformScores[platform] = (platformScores[platform] ?? 0.0) + weight;
          }
        }
      }
    }
    
    // Sort preferences by score
    final sortedGenres = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final sortedDevelopers = developerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final averageRating = ratedGames > 0 ? totalRating / ratedGames : 3.0;
    
    return {
      'favoriteGenres': sortedGenres.take(5).map((e) => e.key).toList(),
      'favoriteDevelopers': sortedDevelopers.take(3).map((e) => e.key).toList(),
      'averageRating': averageRating,
      'totalGames': libraryData.length,
      'ratedGames': ratedGames,
    };
  }

  /// Get recommendations based on user preferences
  Future<List<Game>> _getRecommendationsFromPreferences(Map<String, dynamic> preferences, int limit) async {
    final recommendations = <Game>[];
    final seenGameIds = <String>{};
    
    final favoriteGenres = List<String>.from(preferences['favoriteGenres'] ?? []);
    
    // Get games from favorite genres (60% of recommendations)
    final genreLimit = (limit * 0.6).round();
    for (final genre in favoriteGenres.take(3)) {
      try {
        final genreGames = await IGDBService.instance.getGamesByGenre(
          genre,
          limit: genreLimit ~/ favoriteGenres.length + 2,
        );
        
        for (final game in genreGames) {
          if (!seenGameIds.contains(game.id) && recommendations.length < genreLimit) {
            recommendations.add(game);
            seenGameIds.add(game.id);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching games for genre $genre: $e');
        }
      }
    }
    
    // Get highly rated recent games (40% of recommendations)
    final recentLimit = limit - recommendations.length;
    if (recentLimit > 0) {
      try {
        final recentGames = await IGDBService.instance.getPopularGames(limit: recentLimit + 5);
        
        for (final game in recentGames) {
          if (!seenGameIds.contains(game.id) && recommendations.length < limit) {
            recommendations.add(game);
            seenGameIds.add(game.id);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching recent popular games: $e');
        }
      }
    }
    
    return recommendations;
  }

  /// Get fallback recommendations for users without library data
  Future<List<Game>> _getFallbackRecommendations(int limit) async {
    try {
      // Mix of trending and popular games for new users
      final trendingGames = await IGDBService.instance.getTrendingGames(limit: limit ~/ 2);
      final popularGames = await IGDBService.instance.getPopularGames(limit: limit ~/ 2);

      final recommendations = <Game>[];
      recommendations.addAll(trendingGames);
      recommendations.addAll(popularGames);

      // Remove duplicates
      final uniqueRecommendations = <String, Game>{};
      for (final game in recommendations) {
        uniqueRecommendations[game.id] = game;
      }

      return uniqueRecommendations.values.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting fallback recommendations: $e');
      }
      return [];
    }
  }

  /// Get games recommended by friends
  Future<List<Map<String, dynamic>>> getFriendRecommendations({int limit = 10}) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        return [];
      }

      // TODO: Implement actual friend recommendations from Firestore
      // For now, return empty list
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting friend recommendations: $e');
      }
      return [];
    }
  }

  /// Get recommendation statistics for a game
  Future<Map<String, int>> getRecommendationStats(String gameId) async {
    try {
      // TODO: Implement actual recommendation statistics from Firestore
      // For now, return mock data
      return {
        'totalRecommendations': 0,
        'friendRecommendations': 0,
        'recentRecommendations': 0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recommendation stats: $e');
      }
      return {
        'totalRecommendations': 0,
        'friendRecommendations': 0,
        'recentRecommendations': 0,
      };
    }
  }
}