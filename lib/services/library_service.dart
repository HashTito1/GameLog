import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';

class LibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _libraryCollection = 'user_library';

  // Singleton pattern
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();
  static LibraryService get instance => _instance;

  // Add game to user's library
  Future<void> addGameToLibrary({
    required String userId,
    required Game game,
    required double rating,
    String? review,
    String status = 'rated',
  }) async {
    try {
      final libraryEntryId = '$userId${game.id}';
      final now = DateTime.now();
      
                  final libraryEntry = {
        'id': libraryEntryId,
        'userId': userId,
        'gameId': game.id,
        'gameTitle': game.title,
        'gameCoverImage': game.coverImage,
        'gameDeveloper': game.developer,
        'gameReleaseDate': game.releaseDate,
        'gameGenres': game.genres,
        'gamePlatforms': game.platforms,
        'userRating': rating,
        'userReview': review,
        'status': status,
        'dateAdded': now.millisecondsSinceEpoch,
        'dateUpdated': now.millisecondsSinceEpoch,
      };

                        await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .set(libraryEntry, SetOptions(merge: true));
      
            // Verify the game was added
      final savedDoc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();
      
      if (savedDoc.exists) {
        } else {
                throw Exception('Library entry was not saved properly');
      }
      
    } catch (e) {
      throw Exception('Failed to add game to library: $e');
    }
  }

  // Get user's library
  Future<List<Map<String, dynamic>>> getUserLibrary(String userId, {int limit = 50}) async {
    try {
            final querySnapshot = await _firestore
          .collection(_libraryCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('dateUpdated', descending: true)
          .limit(limit)
          .get();

            final libraryGames = querySnapshot.docs.map((doc) {
        final data = doc.data();
                return data;
      }).toList();
      
      // Force debug: Check for games with ratings
      final ratedGames = libraryGames.where((game) => (game['userRating'] ?? 0.0) > 0).toList();
            for (final _ in ratedGames) {
        // Process game: ${game['gameTitle'] ?? 'Unknown'}
      }
      
      return libraryGames;
    } catch (e) {
      print('Error loading user library: $e');
      return [];
    }
  }

  // Check if game is in user's library
  Future<bool> isGameInLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '$userId$gameId';
      final doc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking if game is in library: $e');
      return false;
    }
  }

  // Get game data from user's library
  Future<Map<String, dynamic>?> getGameFromLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '$userId$gameId';
      final doc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting game from library: $e');
      return null;
    }
  }

  // Update game in library
  Future<void> updateGameInLibrary({
    required String userId,
    required String gameId,
    required double rating,
    String? review,
    String? status,
  }) async {
    try {
      final libraryEntryId = '$userId$gameId';
      final now = DateTime.now();
      
                  final updateData = <String, dynamic>{
        'userRating': rating,
        'dateUpdated': now.millisecondsSinceEpoch,
      };
      
      if (review != null) {
        updateData['userReview'] = review;
      }
      
      if (status != null) {
        updateData['status'] = status;
      }

            await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .update(updateData);
      
            // Verify the update
      final updatedDoc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();
      
      if (updatedDoc.exists) {
        } else {
                throw Exception('Library entry not found for update');
      }
      
    } catch (e) {
      throw Exception('Failed to update game in library: $e');
    }
  }

  // Get user's library stats
  Future<Map<String, dynamic>> getUserLibraryStats(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_libraryCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final games = querySnapshot.docs.map((doc) => doc.data()).toList();
      
      int totalGames = games.length;
      double totalRating = 0.0;
      int ratedGames = 0;
      int backlogGames = 0;
      int completedGames = 0;
      Map<String, int> genreCounts = {};
      
      for (final game in games) {
        final rating = (game['userRating'] ?? 0.0).toDouble();
        final status = game['status'] ?? 'rated';
        
        // Count games with ratings (both 'rated' and 'completed' status)
        if (rating > 0 && (status == 'rated' || status == 'completed')) {
          totalRating += rating;
          ratedGames++;
        }
        
        if (status == 'backlog') {
          backlogGames++;
        }
        
        if (status == 'completed') {
          completedGames++;
        }
        
        final genres = List<String>.from(game['gameGenres'] ?? []);
        for (final genre in genres) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }
      
      return {
        'totalGames': totalGames,
        'averageRating': ratedGames > 0 ? totalRating / ratedGames : 0.0,
        'ratedGames': ratedGames, // This includes both 'rated' and 'completed' games
        'completedGames': completedGames,
        'backlogGames': backlogGames,
        'favoriteGenres': genreCounts.entries
            .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
      };
    } catch (e) {
            return {
        'totalGames': 0,
        'averageRating': 0.0,
        'ratedGames': 0,
        'completedGames': 0,
        'backlogGames': 0,
        'favoriteGenres': <MapEntry<String, int>>[],
        // Error handled
    };
    }
  }

  // Add game to backlog
  Future<void> addGameToBacklog({
    required String userId,
    required Game game,
  }) async {
    try {
      final libraryEntryId = '$userId${game.id}';
      final now = DateTime.now();
      
            final libraryEntry = {
        'id': libraryEntryId,
        'userId': userId,
        'gameId': game.id,
        'gameTitle': game.title,
        'gameCoverImage': game.coverImage,
        'gameDeveloper': game.developer,
        'gameReleaseDate': game.releaseDate,
        'gameGenres': game.genres,
        'gamePlatforms': game.platforms,
        'userRating': 0.0, // No rating for backlog items
        'userReview': null,
        'status': 'backlog',
        'dateAdded': now.millisecondsSinceEpoch,
        'dateUpdated': now.millisecondsSinceEpoch,
      };

      await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .set(libraryEntry, SetOptions(merge: true));
      
            // Verify the game was added
      final savedDoc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();
      
      if (savedDoc.exists) {
              } else {
              }
      
    } catch (e) {
      throw Exception('Failed to add game to backlog: $e');
    }
  }

  // Remove game from library
  Future<void> removeGameFromLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '$userId$gameId';
      await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .delete();
      
    } catch (e) {
      debugPrint('Error removing game from library: $e');
      throw Exception('Failed to remove game from library: $e');
    }
  }

  // Method aliases for compatibility
  Future<Map<String, dynamic>?> getLibraryEntry(String userId, String gameId) async {
    return getGameFromLibrary(userId, gameId);
  }

  Future<void> removeFromLibrary(String userId, String gameId) async {
    return removeGameFromLibrary(userId, gameId);
  }

  Future<void> addToLibrary({
    required String userId,
    required Game game,
    String status = 'want_to_play',
    double? rating,
    String? review,
  }) async {
    if (rating != null) {
      return addGameToLibrary(
        userId: userId,
        game: game,
        rating: rating,
        review: review,
        status: status,
      );
    } else {
      return addGameToBacklog(
        userId: userId,
        game: game,
      );
    }
  }
}


