import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rawg_service.dart';

class UserDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _userLibraryCollection = 'user_library';
  static const String _userRatingsCollection = 'user_ratings';
  
  // Singleton pattern
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();
  static UserDataService get instance => _instance;

  // ========== COMPREHENSIVE USER PROFILE MANAGEMENT ==========

  /// Create or update a complete user profile with all data
  static Future<void> createOrUpdateUserProfile({
    required String userId,
    String? username,
    String? displayName,
    String? email,
    String? bio,
    String? profileImageUrl,
    String? bannerImageUrl,
    Map<String, dynamic>? favoriteGame,
    List<Map<String, dynamic>>? playlists,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? stats,
  }) async {
    try {
      final now = DateTime.now();
      final profileData = <String, dynamic>{
        'id': userId,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': now.millisecondsSinceEpoch,
        'isOnline': true,
      };

      // Only update fields that are provided
      if (username != null) profileData['username'] = username;
      if (displayName != null) profileData['displayName'] = displayName;
      if (email != null) profileData['email'] = email;
      if (bio != null) profileData['bio'] = bio;
      if (profileImageUrl != null) profileData['profileImage'] = profileImageUrl;
      if (bannerImageUrl != null) profileData['bannerImage'] = bannerImageUrl;
      if (favoriteGame != null) profileData['favoriteGame'] = favoriteGame;
      if (playlists != null) profileData['playlists'] = playlists;
      if (preferences != null) profileData['preferences'] = preferences;
      if (stats != null) profileData['stats'] = stats;

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      debugPrint('User profile updated successfully for: $userId');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get complete user profile with all associated data
  static Future<Map<String, dynamic>?> getCompleteUserProfile(String userId) async {
    try {
      // Get basic profile
      final profileDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!profileDoc.exists || profileDoc.data() == null) {
        return null;
      }

      final profileData = profileDoc.data()!;

      // Get library stats
      final libraryStats = await _getUserLibraryStats(userId);
      profileData['libraryStats'] = libraryStats;

      // Get rating stats
      final ratingStats = await _getUserRatingStats(userId);
      profileData['ratingStats'] = ratingStats;

      // Get recent activity
      final recentActivity = await _getUserRecentActivity(userId);
      profileData['recentActivity'] = recentActivity;

      return profileData;
    } catch (e) {
      debugPrint('Error getting complete user profile: $e');
      return null;
    }
  }

  // ========== GAME LIBRARY MANAGEMENT ==========

  /// Add or update a game in user's library with comprehensive data
  static Future<void> updateUserLibraryEntry({
    required String userId,
    required String gameId,
    required String gameTitle,
    String? gameCoverImage,
    String? gameDeveloper,
    String? gameReleaseDate,
    List<String>? gameGenres,
    List<String>? gamePlatforms,
    String status = 'want_to_play', // want_to_play, playing, completed, dropped, on_hold
    double? rating,
    String? review,
    int? hoursPlayed,
    DateTime? startedDate,
    DateTime? completedDate,
    Map<String, dynamic>? customData,
  }) async {
    try {
      final now = DateTime.now();
      final entryId = '${userId}_$gameId';

      final libraryEntry = <String, dynamic>{
        'id': entryId,
        'userId': userId,
        'gameId': gameId,
        'gameTitle': gameTitle,
        'status': status,
        'dateAdded': FieldValue.serverTimestamp(),
        'dateUpdated': FieldValue.serverTimestamp(),
        'lastModified': now.millisecondsSinceEpoch,
      };

      // Add optional fields
      if (gameCoverImage != null) libraryEntry['gameCoverImage'] = gameCoverImage;
      if (gameDeveloper != null) libraryEntry['gameDeveloper'] = gameDeveloper;
      if (gameReleaseDate != null) libraryEntry['gameReleaseDate'] = gameReleaseDate;
      if (gameGenres != null) libraryEntry['gameGenres'] = gameGenres;
      if (gamePlatforms != null) libraryEntry['gamePlatforms'] = gamePlatforms;
      if (rating != null) libraryEntry['userRating'] = rating;
      if (review != null) libraryEntry['userReview'] = review;
      if (hoursPlayed != null) libraryEntry['hoursPlayed'] = hoursPlayed;
      if (startedDate != null) libraryEntry['startedDate'] = startedDate.millisecondsSinceEpoch;
      if (completedDate != null) libraryEntry['completedDate'] = completedDate.millisecondsSinceEpoch;
      if (customData != null) libraryEntry['customData'] = customData;

      // Save to user's library subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('library')
          .doc(gameId)
          .set(libraryEntry, SetOptions(merge: true));

      // Also save to global library collection for easier querying
      await _firestore
          .collection(_userLibraryCollection)
          .doc(entryId)
          .set(libraryEntry, SetOptions(merge: true));

      // Update user stats
      await _updateUserStats(userId);

      debugPrint('Library entry updated for user $userId, game $gameId');
    } catch (e) {
      debugPrint('Error updating library entry: $e');
      throw Exception('Failed to update library entry: $e');
    }
  }

  /// Get user's complete library with filtering options
  static Future<List<Map<String, dynamic>>> getUserLibrary(
    String userId, {
    String? status,
    int limit = 100,
    String orderBy = 'dateUpdated',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('library');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy(orderBy, descending: descending).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting user library: $e');
      return [];
    }
  }

  // ========== RATING MANAGEMENT ==========

  /// Submit or update a user's rating with comprehensive data (optimized)
  static Future<void> submitUserRating({
    required String userId,
    required String gameId,
    required String gameTitle,
    required double rating,
    String? review,
    List<String>? tags,
    bool isRecommended = true,
    bool containsSpoilers = false,
    Map<String, dynamic>? customData,
  }) async {
    try {
      debugPrint('🔍 UserDataService.submitUserRating called');
      debugPrint('   userId: $userId');
      debugPrint('   gameId: $gameId');
      debugPrint('   gameTitle: $gameTitle');
      debugPrint('   rating: $rating');
      debugPrint('   review: $review');
      
      final now = DateTime.now();
      final ratingId = '${userId}_$gameId';

      final ratingData = <String, dynamic>{
        'id': ratingId,
        'userId': userId,
        'gameId': gameId,
        'gameTitle': gameTitle,
        'rating': rating,
        'isRecommended': isRecommended,
        'containsSpoilers': containsSpoilers,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModified': now.millisecondsSinceEpoch,
      };

      if (review != null) ratingData['review'] = review;
      if (tags != null) ratingData['tags'] = tags;
      if (customData != null) ratingData['customData'] = customData;

      debugPrint('📝 Rating data prepared: $ratingData');

      // Use batch write for better performance
      final batch = _firestore.batch();

      // Save to user's ratings subcollection
      final userRatingRef = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('ratings')
          .doc(gameId);
      batch.set(userRatingRef, ratingData, SetOptions(merge: true));
      debugPrint('📝 Added user rating to batch: ${userRatingRef.path}');

      // Also save to global ratings collection for easier querying
      final globalRatingRef = _firestore
          .collection(_userRatingsCollection)
          .doc(ratingId);
      batch.set(globalRatingRef, ratingData, SetOptions(merge: true));
      debugPrint('📝 Added global rating to batch: ${globalRatingRef.path}');

      // Update library entry with rating (if exists)
      final libraryRef = _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('library')
          .doc(gameId);
      
      batch.set(libraryRef, {
        'userRating': rating,
        'userReview': review,
        'dateUpdated': FieldValue.serverTimestamp(),
        'lastModified': now.millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      debugPrint('📝 Added library update to batch: ${libraryRef.path}');

      // Update global library entry
      final globalLibraryRef = _firestore
          .collection(_userLibraryCollection)
          .doc('${userId}_$gameId');
      
      batch.set(globalLibraryRef, {
        'userRating': rating,
        'userReview': review,
        'dateUpdated': FieldValue.serverTimestamp(),
        'lastModified': now.millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      debugPrint('📝 Added global library update to batch: ${globalLibraryRef.path}');

      // Commit all writes at once
      debugPrint('🚀 Committing batch write...');
      await batch.commit();
      debugPrint('✅ Batch write committed successfully');

      // Update stats asynchronously (don't wait for it)
      _updateUserStatsAsync(userId);

      debugPrint('✅ Rating submitted for user $userId, game $gameId');
    } catch (e) {
      debugPrint('❌ Error submitting rating: $e');
      throw Exception('Failed to submit rating: $e');
    }
  }

  /// Get user's ratings with filtering options
  static Future<List<Map<String, dynamic>>> getUserRatings(
    String userId, {
    int limit = 50,
    String orderBy = 'updatedAt',
    bool descending = true,
  }) async {
    try {
      debugPrint('🔍 getUserRatings called for userId: $userId');
      
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('ratings')
          .orderBy(orderBy, descending: descending)
          .limit(limit)
          .get();

      final ratings = querySnapshot.docs.map((doc) => doc.data()).toList();
      debugPrint('📊 Found ${ratings.length} ratings for user $userId');
      
      return ratings;
    } catch (e) {
      debugPrint('❌ Error getting user ratings: $e');
      return [];
    }
  }

  // ========== STATISTICS AND ANALYTICS ==========

  /// Get comprehensive user library statistics
  static Future<Map<String, dynamic>> _getUserLibraryStats(String userId) async {
    try {
      final librarySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('library')
          .get();

      final games = librarySnapshot.docs.map((doc) => doc.data()).toList();
      
      final stats = <String, dynamic>{
        'totalGames': games.length,
        'wantToPlay': games.where((g) => g['status'] == 'want_to_play').length,
        'playing': games.where((g) => g['status'] == 'playing').length,
        'completed': games.where((g) => g['status'] == 'completed').length,
        'dropped': games.where((g) => g['status'] == 'dropped').length,
        'onHold': games.where((g) => g['status'] == 'on_hold').length,
      };

      // Calculate total hours played
      int totalHours = 0;
      for (final game in games) {
        totalHours += (game['hoursPlayed'] ?? 0) as int;
      }
      stats['totalHoursPlayed'] = totalHours;

      // Calculate genre distribution
      final Map<String, int> genreCounts = {};
      for (final game in games) {
        final genres = List<String>.from(game['gameGenres'] ?? []);
        for (final genre in genres) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }
      stats['favoriteGenres'] = genreCounts;

      return stats;
    } catch (e) {
      debugPrint('Error getting library stats: $e');
      return {};
    }
  }

  /// Get comprehensive user rating statistics
  static Future<Map<String, dynamic>> _getUserRatingStats(String userId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('ratings')
          .get();

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      
      if (ratings.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'ratingDistribution': {},
        };
      }

      double totalRating = 0.0;
      final Map<String, int> ratingDistribution = {};

      for (final rating in ratings) {
        final ratingValue = (rating['rating'] ?? 0.0).toDouble();
        totalRating += ratingValue;
        
        final ratingKey = ratingValue.toString();
        ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;
      }

      return {
        'totalRatings': ratings.length,
        'averageRating': totalRating / ratings.length,
        'ratingDistribution': ratingDistribution,
        'recommendedGames': ratings.where((r) => r['isRecommended'] == true).length,
      };
    } catch (e) {
      debugPrint('Error getting rating stats: $e');
      return {};
    }
  }

  /// Get user's recent activity
  static Future<List<Map<String, dynamic>>> _getUserRecentActivity(String userId) async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Get recent ratings
      final recentRatings = await getUserRatings(userId, limit: 5);
      for (final rating in recentRatings) {
        activities.add({
          'type': 'rating',
          'gameTitle': rating['gameTitle'],
          'rating': rating['rating'],
          'timestamp': rating['lastModified'],
        });
      }

      // Get recent library additions
      final recentLibrary = await getUserLibrary(userId, limit: 5);
      for (final entry in recentLibrary) {
        activities.add({
          'type': 'library',
          'gameTitle': entry['gameTitle'],
          'status': entry['status'],
          'timestamp': entry['lastModified'],
        });
      }

      // Sort by timestamp
      activities.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      
      return activities.take(10).toList();
    } catch (e) {
      debugPrint('Error getting recent activity: $e');
      return [];
    }
  }

  /// Update user statistics (optimized async version)
  static void _updateUserStatsAsync(String userId) {
    // Run stats update in background without blocking the UI
    Future.microtask(() async {
      try {
        await _updateUserStats(userId);
      } catch (e) {
        debugPrint('Error updating user stats async: $e');
      }
    });
  }

  /// Update user statistics (optimized)
  static Future<void> _updateUserStats(String userId) async {
    try {
      // Use parallel execution for better performance
      final futures = await Future.wait([
        _getUserLibraryStatsOptimized(userId),
        _getUserRatingStatsOptimized(userId),
      ]);
      
      final libraryStats = futures[0] as Map<String, dynamic>;
      final ratingStats = futures[1] as Map<String, dynamic>;
      final now = DateTime.now();

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set({
        'stats': {
          'library': libraryStats,
          'ratings': ratingStats,
          'lastUpdated': now.millisecondsSinceEpoch,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user stats: $e');
    }
  }

  /// Get optimized user library statistics (using aggregation where possible)
  static Future<Map<String, dynamic>> _getUserLibraryStatsOptimized(String userId) async {
    try {
      final librarySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('library')
          .get();

      if (librarySnapshot.docs.isEmpty) {
        return {
          'totalGames': 0,
          'wantToPlay': 0,
          'playing': 0,
          'completed': 0,
          'dropped': 0,
          'onHold': 0,
          'totalHoursPlayed': 0,
          'favoriteGenres': <String, int>{},
        };
      }

      final games = librarySnapshot.docs.map((doc) => doc.data()).toList();
      
      final stats = <String, dynamic>{
        'totalGames': games.length,
        'wantToPlay': games.where((g) => g['status'] == 'want_to_play').length,
        'playing': games.where((g) => g['status'] == 'playing').length,
        'completed': games.where((g) => g['status'] == 'completed').length,
        'dropped': games.where((g) => g['status'] == 'dropped').length,
        'onHold': games.where((g) => g['status'] == 'on_hold').length,
      };

      // Calculate total hours played
      int totalHours = 0;
      for (final game in games) {
        totalHours += (game['hoursPlayed'] ?? 0) as int;
      }
      stats['totalHoursPlayed'] = totalHours;

      // Calculate genre distribution (limit to avoid large objects)
      final Map<String, int> genreCounts = {};
      for (final game in games) {
        final genres = List<String>.from(game['gameGenres'] ?? []);
        for (final genre in genres.take(5)) { // Limit genres per game
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }
      
      // Keep only top 10 genres to avoid large documents
      final sortedGenres = genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      stats['favoriteGenres'] = Map.fromEntries(sortedGenres.take(10));

      return stats;
    } catch (e) {
      debugPrint('Error getting optimized library stats: $e');
      return {};
    }
  }

  /// Get optimized user rating statistics
  static Future<Map<String, dynamic>> _getUserRatingStatsOptimized(String userId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('ratings')
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'ratingDistribution': <String, int>{},
          'recommendedGames': 0,
        };
      }

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      
      double totalRating = 0.0;
      final Map<String, int> ratingDistribution = {};
      int recommendedCount = 0;

      for (final rating in ratings) {
        final ratingValue = (rating['rating'] ?? 0.0).toDouble();
        totalRating += ratingValue;
        
        // Round to nearest 0.5 for distribution
        final roundedRating = (ratingValue * 2).round() / 2;
        final ratingKey = roundedRating.toString();
        ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;
        
        if (rating['isRecommended'] == true) {
          recommendedCount++;
        }
      }

      return {
        'totalRatings': ratings.length,
        'averageRating': totalRating / ratings.length,
        'ratingDistribution': ratingDistribution,
        'recommendedGames': recommendedCount,
      };
    } catch (e) {
      debugPrint('Error getting optimized rating stats: $e');
      return {};
    }
  }

  // ========== LEGACY COMPATIBILITY METHODS ==========

  // Save user's favorite game to Firestore
  static Future<void> saveFavoriteGame({
    required String userId,
    required String gameId,
    required String gameName,
    String? gameImage,
  }) async {
    try {
      final now = DateTime.now();
      await createOrUpdateUserProfile(
        userId: userId,
        favoriteGame: {
          'gameId': gameId,
          'gameName': gameName,
          'gameImage': gameImage,
          'updatedAt': now.millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Error saving favorite game: $e');
      throw Exception('Failed to save favorite game: $e');
    }
  }

  // Get user's favorite game from Firestore
  static Future<Map<String, dynamic>?> getFavoriteGame(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?['favoriteGame'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting favorite game: $e');
      return null;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Get user playlists
  static Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      final playlists = profile?['playlists'] as List<dynamic>?;
      return playlists?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('Error getting user playlists: $e');
      return [];
    }
  }

  // Save user profile
  static Future<void> saveUserProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set(profileData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      throw Exception('Failed to save user profile: $e');
    }
  }

  // ========== PLAYLIST MANAGEMENT ==========

  /// Create a new playlist with comprehensive game data
  static Future<void> createPlaylistWithGames({
    required String userId,
    required String playlistName,
    String description = '',
    List<String> gameIds = const [],
    bool isPublic = false,
  }) async {
    try {
      final now = DateTime.now();
      final playlistId = now.millisecondsSinceEpoch.toString();
      
      // Get game details for each game ID
      final List<Map<String, dynamic>> games = [];
      for (final gameId in gameIds) {
        try {
          final game = await RAWGService.instance.getGameDetails(gameId);
          if (game != null) {
            games.add({
              'gameId': gameId,
              'gameTitle': game.title,
              'gameCoverImage': game.coverImage,
              'gameDeveloper': game.developer,
              'gameGenres': game.genres,
              'addedAt': now.millisecondsSinceEpoch,
            });
          }
        } catch (e) {
          debugPrint('Error getting game details for $gameId: $e');
          // Add basic game info if API fails
          games.add({
            'gameId': gameId,
            'gameTitle': 'Unknown Game',
            'gameCoverImage': '',
            'gameDeveloper': 'Unknown Developer',
            'gameGenres': <String>[],
            'addedAt': now.millisecondsSinceEpoch,
          });
        }
      }

      final playlistData = {
        'id': playlistId,
        'name': playlistName,
        'description': description,
        'userId': userId,
        'games': games,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'isPublic': isPublic,
      };

      // Save to user's playlists subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .set(playlistData);

      // Also save to global playlists collection for easier querying
      await _firestore
          .collection('playlists')
          .doc(playlistId)
          .set(playlistData);

      // Update user profile with playlist reference
      final userProfile = await getUserProfile(userId);
      final playlists = List<Map<String, dynamic>>.from(userProfile?['playlists'] ?? []);
      playlists.add({
        'id': playlistId,
        'name': playlistName,
        'gameCount': games.length,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      await createOrUpdateUserProfile(
        userId: userId,
        playlists: playlists,
      );

      debugPrint('Playlist created successfully: $playlistId');
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      throw Exception('Failed to create playlist: $e');
    }
  }

  /// Add a game to an existing playlist
  static Future<void> addGameToPlaylist({
    required String userId,
    required String playlistId,
    required String gameId,
    required String gameTitle,
    String gameCoverImage = '',
    String gameDeveloper = '',
    List<String> gameGenres = const [],
  }) async {
    try {
      final now = DateTime.now();
      
      // Get current playlist
      final playlistDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .get();

      if (!playlistDoc.exists) {
        throw Exception('Playlist not found');
      }

      final playlistData = playlistDoc.data()!;
      final games = List<Map<String, dynamic>>.from(playlistData['games'] ?? []);
      
      // Check if game already exists
      final existingGameIndex = games.indexWhere((game) => game['gameId'] == gameId);
      if (existingGameIndex != -1) {
        throw Exception('Game already exists in playlist');
      }

      // Add new game
      games.add({
        'gameId': gameId,
        'gameTitle': gameTitle,
        'gameCoverImage': gameCoverImage,
        'gameDeveloper': gameDeveloper,
        'gameGenres': gameGenres,
        'addedAt': now.millisecondsSinceEpoch,
      });

      // Update playlist
      final updatedPlaylistData = {
        ...playlistData,
        'games': games,
        'updatedAt': now.millisecondsSinceEpoch,
      };

      // Update in user's subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .set(updatedPlaylistData);

      // Update in global collection
      await _firestore
          .collection('playlists')
          .doc(playlistId)
          .set(updatedPlaylistData);

      // Update user profile playlist reference
      final userProfile = await getUserProfile(userId);
      final playlists = List<Map<String, dynamic>>.from(userProfile?['playlists'] ?? []);
      final playlistIndex = playlists.indexWhere((p) => p['id'] == playlistId);
      if (playlistIndex != -1) {
        playlists[playlistIndex]['gameCount'] = games.length;
        playlists[playlistIndex]['updatedAt'] = now.millisecondsSinceEpoch;
        
        await createOrUpdateUserProfile(
          userId: userId,
          playlists: playlists,
        );
      }

      debugPrint('Game added to playlist successfully');
    } catch (e) {
      debugPrint('Error adding game to playlist: $e');
      throw Exception('Failed to add game to playlist: $e');
    }
  }

  /// Get user's playlists with full game details
  static Future<List<Map<String, dynamic>>> getUserPlaylistsWithGames(String userId) async {
    try {
      final playlistsSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .orderBy('updatedAt', descending: true)
          .get();

      return playlistsSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting user playlists: $e');
      return [];
    }
  }

  /// Get a specific playlist with full details
  static Future<Map<String, dynamic>?> getPlaylistDetails(String userId, String playlistId) async {
    try {
      final playlistDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .get();

      if (playlistDoc.exists) {
        return playlistDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting playlist details: $e');
      return null;
    }
  }

  /// Remove a game from playlist
  static Future<void> removeGameFromPlaylist({
    required String userId,
    required String playlistId,
    required String gameId,
  }) async {
    try {
      final now = DateTime.now();
      
      // Get current playlist
      final playlistDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .get();

      if (!playlistDoc.exists) {
        throw Exception('Playlist not found');
      }

      final playlistData = playlistDoc.data()!;
      final games = List<Map<String, dynamic>>.from(playlistData['games'] ?? []);
      
      // Remove game
      games.removeWhere((game) => game['gameId'] == gameId);

      // Update playlist
      final updatedPlaylistData = {
        ...playlistData,
        'games': games,
        'updatedAt': now.millisecondsSinceEpoch,
      };

      // Update in user's subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .set(updatedPlaylistData);

      // Update in global collection
      await _firestore
          .collection('playlists')
          .doc(playlistId)
          .set(updatedPlaylistData);

      // Update user profile playlist reference
      final userProfile = await getUserProfile(userId);
      final playlists = List<Map<String, dynamic>>.from(userProfile?['playlists'] ?? []);
      final playlistIndex = playlists.indexWhere((p) => p['id'] == playlistId);
      if (playlistIndex != -1) {
        playlists[playlistIndex]['gameCount'] = games.length;
        playlists[playlistIndex]['updatedAt'] = now.millisecondsSinceEpoch;
        
        await createOrUpdateUserProfile(
          userId: userId,
          playlists: playlists,
        );
      }

      debugPrint('Game removed from playlist successfully');
    } catch (e) {
      debugPrint('Error removing game from playlist: $e');
      throw Exception('Failed to remove game from playlist: $e');
    }
  }

  /// Delete a playlist
  static Future<void> deletePlaylist({
    required String userId,
    required String playlistId,
  }) async {
    try {
      // Delete from user's subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .delete();

      // Delete from global collection
      await _firestore
          .collection('playlists')
          .doc(playlistId)
          .delete();

      // Update user profile playlist references
      final userProfile = await getUserProfile(userId);
      final playlists = List<Map<String, dynamic>>.from(userProfile?['playlists'] ?? []);
      playlists.removeWhere((p) => p['id'] == playlistId);
      
      await createOrUpdateUserProfile(
        userId: userId,
        playlists: playlists,
      );

      debugPrint('Playlist deleted successfully');
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
      throw Exception('Failed to delete playlist: $e');
    }
  }

  // Search users by username or display name
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final queryLower = query.toLowerCase();
      
      // Get all users first (for better search capability)
      final allUsersQuery = await _firestore
          .collection(_usersCollection)
          .limit(100) // Reasonable limit for search
          .get();
      
      final List<Map<String, dynamic>> results = [];
      
      for (final doc in allUsersQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final username = (data['username'] ?? '').toString().toLowerCase();
        final displayName = (data['displayName'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        
        // Check if query matches username, display name, or email
        if (username.contains(queryLower) || 
            displayName.contains(queryLower) || 
            email.contains(queryLower)) {
          results.add(data);
        }
      }
      
      // Sort results by relevance (exact matches first, then partial matches)
      results.sort((a, b) {
        final aUsername = (a['username'] ?? '').toString().toLowerCase();
        final bUsername = (b['username'] ?? '').toString().toLowerCase();
        final aDisplayName = (a['displayName'] ?? '').toString().toLowerCase();
        final bDisplayName = (b['displayName'] ?? '').toString().toLowerCase();
        
        // Exact username matches first
        if (aUsername == queryLower && bUsername != queryLower) return -1;
        if (bUsername == queryLower && aUsername != queryLower) return 1;
        
        // Exact display name matches next
        if (aDisplayName == queryLower && bDisplayName != queryLower) return -1;
        if (bDisplayName == queryLower && aDisplayName != queryLower) return 1;
        
        // Username starts with query
        if (aUsername.startsWith(queryLower) && !bUsername.startsWith(queryLower)) return -1;
        if (bUsername.startsWith(queryLower) && !aUsername.startsWith(queryLower)) return 1;
        
        // Display name starts with query
        if (aDisplayName.startsWith(queryLower) && !bDisplayName.startsWith(queryLower)) return -1;
        if (bDisplayName.startsWith(queryLower) && !aDisplayName.startsWith(queryLower)) return 1;
        
        // Alphabetical order
        return aUsername.compareTo(bUsername);
      });
      
      return results.take(50).toList(); // Limit final results
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Ensure user profile exists in Firestore (migration helper)
  static Future<Map<String, dynamic>?> ensureUserProfile(String userId) async {
    try {
      // First try to get existing profile
      final existingProfile = await getUserProfile(userId);
      if (existingProfile != null) {
        return existingProfile;
      }

      // If no profile exists, try to get from Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.uid == userId) {
        debugPrint('Creating Firestore profile for user: $userId');
        
        await createOrUpdateUserProfile(
          userId: firebaseUser.uid,
          username: firebaseUser.email?.split('@')[0] ?? 'user',
          displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
          email: firebaseUser.email ?? '',
          bio: '',
          profileImageUrl: '',
          bannerImageUrl: '',
        );
        
        return await getUserProfile(userId);
      }

      return null;
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
      return null;
    }
  }

  // Get all users (for development/testing - limit in production)
  static Future<List<Map<String, dynamic>>> getAllUsers({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> users = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        users.add(data);
      }
      
      return users;
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  // Update username while preserving user ID
  static Future<bool> updateUsername(String userId, String newUsername) async {
    try {
      // Validate username format
      if (newUsername.isEmpty || newUsername.length < 3) {
        throw Exception('Username must be at least 3 characters long');
      }
      
      // Check if username contains only allowed characters
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(newUsername)) {
        throw Exception('Username can only contain letters, numbers, and underscores');
      }
      
      // Check if username is already taken by another user
      final existingUsers = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: newUsername.toLowerCase())
          .get();
      
      // If username exists and belongs to a different user, it's taken
      if (existingUsers.docs.isNotEmpty && existingUsers.docs.first.id != userId) {
        throw Exception('Username is already taken');
      }
      
      // Update the username
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'username': newUsername.toLowerCase(),
        'displayName': newUsername, // Also update display name to match
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Username updated successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error updating username: $e');
      throw Exception('Failed to update username: $e');
    }
  }

  // ========== REAL-TIME SOCIAL DATA STREAMS ==========

  /// Get real-time stream of user's followers
  static Stream<List<String>> getUserFollowersStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final followersList = data['followersList'] as List<dynamic>?;
        return followersList?.cast<String>() ?? [];
      }
      return <String>[];
    });
  }

  /// Get real-time stream of user's following
  static Stream<List<String>> getUserFollowingStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final followingList = data['followingList'] as List<dynamic>?;
        return followingList?.cast<String>() ?? [];
      }
      return <String>[];
    });
  }

  /// Get real-time stream of user's social stats (followers and following counts)
  static Stream<Map<String, int>> getUserSocialStatsStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'followers': data['followers'] ?? 0,
          'following': data['following'] ?? 0,
        };
      }
      return {'followers': 0, 'following': 0};
    });
  }
}


