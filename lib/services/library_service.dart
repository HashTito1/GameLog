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
      final libraryEntryId = '${userId}_${game.id}';
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

      // Save to both old and new structure for compatibility
      await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .set(libraryEntry, SetOptions(merge: true));
      
      // Also save to new structure (user's library subcollection)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .doc(game.id)
          .set(libraryEntry, SetOptions(merge: true));
      
      // Verify the game was added
      final savedDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .doc(game.id)
          .get();
      
      if (savedDoc.exists) {
        debugPrint('Game ${game.title} added to library successfully');
      } else {
        throw Exception('Library entry was not saved properly');
      }
      
    } catch (e) {
      debugPrint('Error adding game to library: $e');
      throw Exception('Failed to add game to library: $e');
    }
  }

  // Get user's library (updated to use new data structure)
  Future<List<Map<String, dynamic>>> getUserLibrary(String userId, {int limit = 50}) async {
    try {
      debugPrint('🔍 Loading library for user: $userId');
      
      // Get data from user's library subcollection (new structure)
      final librarySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .orderBy('dateUpdated', descending: true)
          .limit(limit)
          .get();

      debugPrint('📚 Found ${librarySnapshot.docs.length} games in new library structure');

      // If no games in new structure, try old structure
      List<Map<String, dynamic>> libraryGames = [];
      if (librarySnapshot.docs.isEmpty) {
        debugPrint('🔍 Checking old library structure...');
        final oldLibrarySnapshot = await _firestore
            .collection(_libraryCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('dateUpdated', descending: true)
            .limit(limit)
            .get();
        
        debugPrint('📚 Found ${oldLibrarySnapshot.docs.length} games in old library structure');
        libraryGames = oldLibrarySnapshot.docs.map((doc) => doc.data()).toList();
      } else {
        libraryGames = librarySnapshot.docs.map((doc) => doc.data()).toList();
      }

      // Get ratings to merge with library data
      final ratingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .get();

      debugPrint('⭐ Found ${ratingsSnapshot.docs.length} ratings');

      final ratingsMap = <String, Map<String, dynamic>>{};
      
      // Create a map of ratings by gameId
      for (final ratingDoc in ratingsSnapshot.docs) {
        final ratingData = ratingDoc.data();
        final gameId = ratingData['gameId'] ?? ratingDoc.id;
        ratingsMap[gameId] = ratingData;
      }

      // Merge library and rating data
      final mergedGames = <Map<String, dynamic>>[];
      
      // Add library games with their ratings
      for (final game in libraryGames) {
        final gameId = game['gameId'] ?? '';
        final rating = ratingsMap[gameId];
        
        final mergedGame = Map<String, dynamic>.from(game);
        if (rating != null) {
          mergedGame['userRating'] = rating['rating'] ?? 0.0;
          mergedGame['userReview'] = rating['review'];
        }
        mergedGames.add(mergedGame);
      }
      
      // Add rated games that aren't in library yet
      for (final entry in ratingsMap.entries) {
        final gameId = entry.key;
        final rating = entry.value;
        
        // Check if this game is already in library
        final existsInLibrary = mergedGames.any((game) => game['gameId'] == gameId);
        if (!existsInLibrary) {
          // Add as a rated game
          mergedGames.add({
            'id': '${userId}_$gameId',
            'userId': userId,
            'gameId': gameId,
            'gameTitle': rating['gameTitle'] ?? 'Unknown Game',
            'gameCoverImage': '',
            'gameDeveloper': '',
            'gameReleaseDate': '',
            'gameGenres': <String>[],
            'gamePlatforms': <String>[],
            'userRating': rating['rating'] ?? 0.0,
            'userReview': rating['review'],
            'status': 'rated',
            'dateAdded': rating['createdAt'] is Timestamp 
                ? (rating['createdAt'] as Timestamp).millisecondsSinceEpoch
                : (rating['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
            'dateUpdated': rating['updatedAt'] is Timestamp 
                ? (rating['updatedAt'] as Timestamp).millisecondsSinceEpoch
                : (rating['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch),
          });
        }
      }
      
      debugPrint('✅ Returning ${mergedGames.length} total games (library + ratings)');
      return mergedGames;
    } catch (e) {
      debugPrint('❌ Error getting user library: $e');
      return [];
    }
  }

  // Check if game is in user's library
  Future<bool> isGameInLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '${userId}_$gameId';
      final doc = await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if game is in library: $e');
      return false;
    }
  }

  // Get game data from user's library
  Future<Map<String, dynamic>?> getGameFromLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '${userId}_$gameId';
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
      final libraryEntryId = '${userId}_$gameId';
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
        debugPrint('Game updated in library successfully');
      } else {
        throw Exception('Library entry not found for update');
      }
      
    } catch (e) {
      throw Exception('Failed to update game in library: $e');
    }
  }

  // Get user's library stats (updated to use new data structure)
  Future<Map<String, dynamic>> getUserLibraryStats(String userId) async {
    try {
      // Get data from user's subcollections (new structure)
      final librarySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .get();

      final ratingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .get();

      final libraryGames = librarySnapshot.docs.map((doc) => doc.data()).toList();
      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      
      int totalGames = libraryGames.length;
      double totalRating = 0.0;
      int ratedGames = ratings.length; // Count from ratings collection
      int backlogGames = 0;
      int completedGames = 0;
      Map<String, int> genreCounts = {};
      
      // Calculate rating stats from ratings collection
      for (final rating in ratings) {
        final ratingValue = (rating['rating'] ?? 0.0).toDouble();
        if (ratingValue > 0) {
          totalRating += ratingValue;
        }
      }
      
      // Calculate library stats from library collection
      for (final game in libraryGames) {
        final status = game['status'] ?? 'rated';
        
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
      
      // If no library games but have ratings, count ratings as total games
      if (totalGames == 0 && ratedGames > 0) {
        totalGames = ratedGames;
      }
      
      return {
        'totalGames': totalGames,
        'averageRating': ratedGames > 0 ? totalRating / ratedGames : 0.0,
        'ratedGames': ratedGames, // Count from ratings collection
        'completedGames': completedGames,
        'backlogGames': backlogGames,
        'favoriteGenres': genreCounts.entries
            .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
      };
    } catch (e) {
      debugPrint('Error getting user library stats: $e');
      return {
        'totalGames': 0,
        'averageRating': 0.0,
        'ratedGames': 0,
        'completedGames': 0,
        'backlogGames': 0,
        'favoriteGenres': <MapEntry<String, int>>[],
      };
    }
  }

  // Add game to backlog
  Future<void> addGameToBacklog({
    required String userId,
    required Game game,
  }) async {
    try {
      final libraryEntryId = '${userId}_${game.id}';
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
        debugPrint('Game ${game.title} added to backlog successfully');
      } else {
        throw Exception('Backlog entry was not saved properly');
      }
      
    } catch (e) {
      throw Exception('Failed to add game to backlog: $e');
    }
  }

  // Remove game from library
  Future<void> removeGameFromLibrary(String userId, String gameId) async {
    try {
      final libraryEntryId = '${userId}_$gameId';
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


