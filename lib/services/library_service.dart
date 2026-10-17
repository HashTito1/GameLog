import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/library_status.dart';
import 'event_bus.dart';
import 'igdb_service.dart';

class LibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _libraryCollection = 'user_library';

  // Singleton pattern
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();
  static LibraryService get instance => _instance;

  // Helper method to convert various timestamp formats to milliseconds
  int _convertToMilliseconds(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    } else if (timestamp is int) {
      return timestamp;
    } else if (timestamp is num) {
      return timestamp.toInt();
    } else {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

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
        EventBus().fire(LibraryUpdatedEvent(userId: userId));
      } else {
        throw Exception('Library entry was not saved properly');
      }
      
    } catch (e) {
      debugPrint('Error adding game to library: $e');
      throw Exception('Failed to add game to library: $e');
    }
  }

  // Get user's library (updated to use new data structure and fetch missing game data)
  Future<List<Map<String, dynamic>>> getUserLibrary(String userId, {int limit = 500}) async {
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
      final processedGameIds = <String>{};
      final igdbService = IGDBService.instance;

      Future<Game?> details(String gameId) async {
        try {
          return await igdbService.getGameDetails(gameId);
        } catch (e) {
          debugPrint('Failed to fetch details for $gameId: $e');
          return null;
        }
      }

      // Library games with their ratings first. Entries missing their title
      // or developer get details from IGDB, all fetched in parallel.
      final libraryEntries = <Map<String, dynamic>>[];
      for (final game in libraryGames) {
        final gameId = game['gameId'] ?? '';
        if (gameId.isEmpty || processedGameIds.contains(gameId)) continue;
        final mergedGame = Map<String, dynamic>.from(game);
        final rating = ratingsMap[gameId];
        if (rating != null) {
          mergedGame['userRating'] = rating['rating'] ?? 0.0;
          mergedGame['userReview'] = rating['review'];
        }
        libraryEntries.add(mergedGame);
        processedGameIds.add(gameId);
      }
      bool missing(Map<String, dynamic> g) {
        final title = (g['gameTitle'] ?? '').toString();
        final dev = (g['gameDeveloper'] ?? '').toString();
        return title.isEmpty || title == 'Unknown Game' || dev.isEmpty || dev == 'Unknown Developer';
      }
      final toFill = libraryEntries.where(missing).toList();
      final filled = await Future.wait(toFill.map((g) => details(g['gameId'])));
      for (var i = 0; i < toFill.length; i++) {
        final gameDetails = filled[i];
        if (gameDetails == null) continue;
        toFill[i]
          ..['gameTitle'] = gameDetails.title
          ..['gameCoverImage'] = gameDetails.coverImage
          ..['gameDeveloper'] = gameDetails.developer
          ..['gameReleaseDate'] = gameDetails.releaseDate
          ..['gameGenres'] = gameDetails.genres
          ..['gamePlatforms'] = gameDetails.platforms;
      }
      mergedGames.addAll(libraryEntries);

      // Rated games that aren't in the library yet (details in parallel).
      final ratedOnly = ratingsMap.entries.where((e) => !processedGameIds.contains(e.key)).toList();
      final ratedDetails = await Future.wait(ratedOnly.map((e) => details(e.key)));
      for (var i = 0; i < ratedOnly.length; i++) {
        final gameId = ratedOnly[i].key;
        final rating = ratedOnly[i].value;
        final gameDetails = ratedDetails[i];
        // Add as a completed game with rating (rated games are considered completed)
        mergedGames.add({
          'id': '${userId}_$gameId',
          'userId': userId,
          'gameId': gameId,
          'gameTitle': gameDetails?.title ?? rating['gameTitle'] ?? 'Unknown Game',
          'gameCoverImage': gameDetails?.coverImage ?? '',
          'gameDeveloper': gameDetails?.developer ?? 'Unknown Developer',
          'gameReleaseDate': gameDetails?.releaseDate ?? '',
          'gameGenres': gameDetails?.genres ?? <String>[],
          'gamePlatforms': gameDetails?.platforms ?? <String>[],
          'userRating': rating['rating'] ?? 0.0,
          'userReview': rating['review'],
          'status': 'completed', // Rated games are considered completed
          'dateAdded': _convertToMilliseconds(rating['createdAt']),
          'dateUpdated': _convertToMilliseconds(rating['updatedAt']),
        });
        processedGameIds.add(gameId);
      }
      
      // Sort by date updated (most recent first)
      mergedGames.sort((a, b) {
        final aDate = a['dateUpdated'];
        final bDate = b['dateUpdated'];
        
        // Convert Timestamps to milliseconds for comparison
        int aMillis = 0;
        int bMillis = 0;
        
        if (aDate is Timestamp) {
          aMillis = aDate.millisecondsSinceEpoch;
        } else if (aDate is int) {
          aMillis = aDate;
        } else if (aDate is num) {
          aMillis = aDate.toInt();
        }
        
        if (bDate is Timestamp) {
          bMillis = bDate.millisecondsSinceEpoch;
        } else if (bDate is int) {
          bMillis = bDate;
        } else if (bDate is num) {
          bMillis = bDate.toInt();
        }
        
        return bMillis.compareTo(aMillis);
      });
      
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

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      
      // Count distinct games: older app versions could save the same game
      // twice, and getUserLibrary de-duplicates when listing them.
      int totalGames = {
        ...librarySnapshot.docs.map((doc) => (doc.data()['gameId'] ?? doc.id).toString()),
        ...ratingsSnapshot.docs.map((doc) => (doc.data()['gameId'] ?? doc.id).toString()),
      }.length;
      double totalRating = 0.0;
      int ratedGames = ratings.length; // Count from ratings collection
      final statusCounts = {for (final s in LibraryStatus.values) s.value: 0};
      Map<String, int> genreCounts = {};
      
      // Calculate rating stats from ratings collection
      for (final rating in ratings) {
        final ratingValue = (rating['rating'] ?? 0.0).toDouble();
        if (ratingValue > 0) {
          totalRating += ratingValue;
        }
      }
      
      // Status counts match the Library screen: an entry's status decides its
      // category, and rated games that aren't in the library count as
      // Completed.
      final libraryGameIds = <String>{};
      for (final doc in librarySnapshot.docs) {
        final game = doc.data();
        final gameId = (game['gameId'] ?? doc.id).toString();
        if (!libraryGameIds.add(gameId)) continue;
        final status = LibraryStatus.forEntry(game);
        statusCounts[status.value] = statusCounts[status.value]! + 1;

        final genres= List<String>.from(game['gameGenres'] ?? []);
        for (final genre in genres) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }
      
      for (final doc in ratingsSnapshot.docs) {
        final gameId = (doc.data()['gameId'] ?? doc.id).toString();
        if (libraryGameIds.add(gameId)) {
          statusCounts[LibraryStatus.completed.value] = statusCounts[LibraryStatus.completed.value]! + 1;
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
        'completedGames': statusCounts[LibraryStatus.completed.value],
        'backlogGames': statusCounts[LibraryStatus.backlog.value],
        'wantGames': statusCounts[LibraryStatus.want.value],
        'statusCounts': statusCounts,
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
        'wantGames': 0,
        'statusCounts': <String, int>{},
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
      debugPrint('🗑️ Starting removal process for game: $gameId, user: $userId');
      
      final libraryEntryId = '${userId}_$gameId';
      
      // Remove from both old and new structure
      debugPrint('🗑️ Removing from old library structure...');
      await _firestore
          .collection(_libraryCollection)
          .doc(libraryEntryId)
          .delete();
      
      debugPrint('🗑️ Removing from new library structure...');
      // Remove from new structure (user's library subcollection)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .doc(gameId)
          .delete();
      
      debugPrint('🗑️ Removing from user ratings...');
      // Remove from user's ratings subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .doc(gameId)
          .delete();
      
      debugPrint('🗑️ Removing from global ratings...');
      // Remove from global ratings collection
      await _firestore
          .collection('user_ratings')
          .doc(libraryEntryId)
          .delete();
      
      debugPrint('✅ Game removed from library successfully: $gameId');
      EventBus().fire(LibraryUpdatedEvent(userId: userId));
    } catch (e) {
      debugPrint('❌ Error removing game from library: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      throw Exception('Failed to remove game from library: $e');
    }
  }

  /// Move a library entry (as returned by [getUserLibrary]) to [status].
  /// Writes the whole entry so games that were only rated get a proper
  /// library record.
  Future<void> setStatus(String userId, Map<String, dynamic> entry, LibraryStatus status) async {
    final gameId = (entry['gameId'] ?? '').toString();
    if (gameId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'id': '${userId}_$gameId',
      'userId': userId,
      'gameId': gameId,
      'gameTitle': entry['gameTitle'] ?? '',
      'gameCoverImage': entry['gameCoverImage'] ?? '',
      'gameDeveloper': entry['gameDeveloper'] ?? '',
      'gameReleaseDate': entry['gameReleaseDate'] ?? '',
      'gameGenres': entry['gameGenres'] ?? const [],
      'gamePlatforms': entry['gamePlatforms'] ?? const [],
      'status': status.value,
      'dateAdded': entry['dateAdded'] ?? now,
      'dateUpdated': now,
    };
    await Future.wait([
      _firestore.collection(_libraryCollection).doc('${userId}_$gameId').set(data, SetOptions(merge: true)),
      _firestore.collection('users').doc(userId).collection('library').doc(gameId).set(data, SetOptions(merge: true)),
    ]);
    EventBus().fire(LibraryUpdatedEvent(userId: userId));
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


