import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_rating.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ratingsCollection = 'game_ratings';
  
  // Singleton pattern
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();
  static RatingService get instance => _instance;
  
  // Cache for rating data to speed up subsequent loads
  static final Map<String, Map<String, dynamic>> _ratingCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5); // Cache for 5 minutes

  // Submit or update a user's rating for a game
  Future<void> submitRating({
    required String gameId,
    required String userId,
    required String username,
    required double rating,
    String? review,
    String? gameTitle,
  }) async {
    try {
      final ratingId = '${userId}_$gameId';
      final now = DateTime.now();
      
      final userRating = UserRating(
        id: ratingId,
        gameId: gameId,
        userId: userId,
        username: username,
        rating: rating,
        review: review,
        createdAt: now,
        updatedAt: now,
      );

      // Create rating data with game title if provided
      final ratingData = userRating.toMap();
      if (gameTitle != null) {
        ratingData['gameTitle'] = gameTitle;
      }

      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .set(ratingData, SetOptions(merge: true));
      
      // Clear cache for this game to ensure fresh data on next load
      _clearGameCache(gameId);
      
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  // Get user rating, game ratings, and stats in a single optimized call with caching
  static Future<Map<String, dynamic>> getGameRatingDataOptimized(String gameId, String userId) async {
    try {
      final cacheKey = '${gameId}_$userId';
      final now = DateTime.now();
      
      // Check if we have cached data that's still valid
      if (_ratingCache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (now.difference(cacheTime) < _cacheExpiry) {
          return _ratingCache[cacheKey]!;
        }
      }
      
      // Single query to get all ratings for the game
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('gameId', isEqualTo: gameId)
          .get();

      UserRating? userRating;
      List<UserRating> gameRatings = [];
      double totalRating = 0.0;
      int count = 0;

      // Process all ratings in one pass
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final rating = UserRating.fromMap(data);
        
        // Check if this is the current user's rating
        if (rating.userId == userId) {
          userRating = rating;
        }
        
        gameRatings.add(rating);
        totalRating += rating.rating;
        count++;
      }

      // Sort ratings by most recent
      gameRatings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final averageRating = count > 0 ? totalRating / count : 0.0;
      
      final result = {
        'userRating': userRating,
        'gameRatings': gameRatings,
        'averageRating': averageRating,
        'totalRatings': count,
      };
      
      // Cache the result
      _ratingCache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = now;
      
      return result;
    } catch (e) {
      return {
        'userRating': null,
        'gameRatings': <UserRating>[],
        'averageRating': 0.0,
        'totalRatings': 0,
      };
    }
  }
  
  // Get user's rating for a specific game (fast method using document ID)
  Future<UserRating?> getUserRating(String userId, String gameId) async {
    try {
      final ratingId = '${userId}_$gameId';
      final doc = await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .get();

      if (doc.exists && doc.data() != null) {
        return UserRating.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Preload rating data for faster access (call this when user is browsing games)
  static Future<void> preloadGameRatingData(String gameId, String userId) async {
    // This will cache the data for faster access later
    await getGameRatingDataOptimized(gameId, userId);
  }
  
  // Clear all cache (useful for memory management)
  static void clearAllCache() {
    _ratingCache.clear();
    _cacheTimestamps.clear();
  }

  // Clear cache for a specific game when ratings are updated
  static void _clearGameCache(String gameId) {
    final keysToRemove = <String>[];
    for (final key in _ratingCache.keys) {
      if (key.startsWith(gameId)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _ratingCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  // Get all ratings for a specific game
  Future<List<UserRating>> getGameRatings(String gameId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('gameId', isEqualTo: gameId)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => UserRating.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get average rating and count for a game
  static Future<Map<String, dynamic>> getGameRatingStats(String gameId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('gameId', isEqualTo: gameId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
        };
      }

      double totalRating = 0.0;
      int count = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final rating = (data['rating'] ?? 0.0).toDouble();
        totalRating += rating;
        count++;
      }

      final averageRating = count > 0 ? totalRating / count : 0.0;
      return {
        'averageRating': averageRating,
        'totalRatings': count,
      };
    } catch (e) {
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
      };
    }
  }

  // Delete a user's rating
  static Future<void> deleteRating(String gameId, String userId) async {
    try {
      final ratingId = '${userId}_$gameId';
      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .delete();
      
    } catch (e) {
      throw Exception('Failed to delete rating: $e');
    }
  }

  // Get recent ratings by a user
  static Future<List<UserRating>> getUserRecentRatings(String userId, {int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => UserRating.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get top rated games
  static Future<List<Map<String, dynamic>>> getTopRatedGames({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .get();

      // Group ratings by gameId and calculate averages
      final Map<String, List<double>> gameRatings = {};
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final gameId = data['gameId'] as String;
        final rating = (data['rating'] ?? 0.0).toDouble();
        
        if (!gameRatings.containsKey(gameId)) {
          gameRatings[gameId] = [];
        }
        gameRatings[gameId]!.add(rating);
      }

      // Calculate averages and sort
      final List<Map<String, dynamic>> topGames = [];
      
      gameRatings.forEach((gameId, ratings) {
        if (ratings.length >= 3) { // Only include games with at least 3 ratings
          final average = ratings.reduce((a, b) => a + b) / ratings.length;
          topGames.add({
            'gameId': gameId,
            'averageRating': average,
            'totalRatings': ratings.length,
          });
        }
      });

      // Sort by average rating
      topGames.sort((a, b) => b['averageRating'].compareTo(a['averageRating']));
      
      return topGames.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get all recent ratings from all users (for discover screen)
  static Future<List<UserRating>> getAllRecentRatings({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      final ratings = querySnapshot.docs
          .map((doc) => UserRating.fromMap(doc.data()))
          .toList();
      
      return ratings;
    } catch (e) {
      return [];
    }
  }
}


