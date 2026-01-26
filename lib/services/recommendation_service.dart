import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
import '../services/firebase_auth_service.dart';

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
      final originalGame = await RAWGService.instance.getGameDetails(gameId);
      if (originalGame == null) {
        return [];
      }

      // Search for games with similar genres
      List<Game> similarGames = [];
      
      // Try to find games with matching genres
      for (final genre in originalGame.genres.take(2)) { // Use top 2 genres
        try {
          final genreGames = await RAWGService.instance.getGamesByGenre(
            genre.toLowerCase().replaceAll(' ', '-'),
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
          final popularGames = await RAWGService.instance.getPopularGames(
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
        return [];
      }

      // TODO: Implement actual personalized recommendations based on:
      // 1. User's game library and ratings
      // 2. Friends' recommendations
      // 3. Popular games in preferred genres
      // 4. Trending games

      // For now, return a mix of trending and popular games
      final trendingGames = await RAWGService.instance.getTrendingGames(limit: limit ~/ 2);
      final popularGames = await RAWGService.instance.getPopularGames(limit: limit ~/ 2);

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
        print('Error getting personalized recommendations: $e');
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