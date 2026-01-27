import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_service.dart';

class DatabaseMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate existing user data to the new comprehensive structure
  static Future<void> migrateUserData(String userId) async {
    try {
      debugPrint('Starting migration for user: $userId');

      // Get existing user profile
      final existingProfile = await UserDataService.getUserProfile(userId);
      if (existingProfile == null) {
        debugPrint('No existing profile found for user: $userId');
        return;
      }

      // Migrate library data
      await _migrateLibraryData(userId);

      // Migrate rating data
      await _migrateRatingData(userId);

      // Update user profile with new structure
      await _updateUserProfileStructure(userId, existingProfile);

      debugPrint('Migration completed for user: $userId');
    } catch (e) {
      debugPrint('Error migrating user data: $e');
      throw Exception('Failed to migrate user data: $e');
    }
  }

  /// Migrate all users in the database
  static Future<void> migrateAllUsers() async {
    try {
      debugPrint('Starting migration for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          await migrateUserData(userDoc.id);
          debugPrint('Migrated user: ${userDoc.id}');
        } catch (e) {
          debugPrint('Failed to migrate user ${userDoc.id}: $e');
          // Continue with other users
        }
      }

      debugPrint('Migration completed for all users');
    } catch (e) {
      debugPrint('Error migrating all users: $e');
      throw Exception('Failed to migrate all users: $e');
    }
  }

  /// Migrate library data from old structure to new structure
  static Future<void> _migrateLibraryData(String userId) async {
    try {
      // Get existing library data from the old collection
      final librarySnapshot = await _firestore
          .collection('user_library')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in librarySnapshot.docs) {
        final data = doc.data();
        
        // Convert to new structure
        await UserDataService.updateUserLibraryEntry(
          userId: userId,
          gameId: data['gameId'] ?? '',
          gameTitle: data['gameTitle'] ?? 'Unknown Game',
          gameCoverImage: data['gameCoverImage'],
          gameDeveloper: data['gameDeveloper'],
          gameReleaseDate: data['gameReleaseDate'],
          gameGenres: List<String>.from(data['gameGenres'] ?? []),
          gamePlatforms: List<String>.from(data['gamePlatforms'] ?? []),
          status: _convertOldStatus(data['status'] ?? 'rated'),
          rating: (data['userRating'] ?? 0.0).toDouble(),
          review: data['userReview'],
        );
      }

      debugPrint('Library migration completed for user: $userId');
    } catch (e) {
      debugPrint('Error migrating library data: $e');
    }
  }

  /// Migrate rating data from old structure to new structure
  static Future<void> _migrateRatingData(String userId) async {
    try {
      // Get existing rating data from the old collection
      final ratingsSnapshot = await _firestore
          .collection('game_ratings')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in ratingsSnapshot.docs) {
        final data = doc.data();
        
        // Convert to new structure
        await UserDataService.submitUserRating(
          userId: userId,
          gameId: data['gameId'] ?? '',
          gameTitle: data['gameTitle'] ?? 'Unknown Game',
          rating: (data['rating'] ?? 0.0).toDouble(),
          review: data['review'],
          isRecommended: (data['rating'] ?? 0.0) >= 3.5, // Assume 3.5+ is recommended
        );
      }

      debugPrint('Rating migration completed for user: $userId');
    } catch (e) {
      debugPrint('Error migrating rating data: $e');
    }
  }

  /// Update user profile to new structure
  static Future<void> _updateUserProfileStructure(
    String userId, 
    Map<String, dynamic> existingProfile,
  ) async {
    try {
      await UserDataService.createOrUpdateUserProfile(
        userId: userId,
        username: existingProfile['username'],
        displayName: existingProfile['displayName'],
        email: existingProfile['email'],
        bio: existingProfile['bio'] ?? '',
        profileImageUrl: existingProfile['profileImage'] ?? '',
        bannerImageUrl: existingProfile['bannerImage'] ?? '',
        favoriteGame: existingProfile['favoriteGame'],
        playlists: List<Map<String, dynamic>>.from(existingProfile['playlists'] ?? []),
        preferences: existingProfile['preferences'] ?? {},
      );

      debugPrint('Profile structure updated for user: $userId');
    } catch (e) {
      debugPrint('Error updating profile structure: $e');
    }
  }

  /// Convert old status values to new status values
  static String _convertOldStatus(String oldStatus) {
    switch (oldStatus) {
      case 'rated':
        return 'completed';
      case 'want_to_play':
        return 'want_to_play';
      case 'completed':
        return 'completed';
      case 'backlog':
        return 'want_to_play';
      default:
        return 'want_to_play';
    }
  }

  /// Clean up old collections after migration (use with caution!)
  static Future<void> cleanupOldCollections() async {
    try {
      debugPrint('WARNING: This will delete old collection data!');
      
      // Uncomment these lines only after confirming migration is successful
      /*
      // Delete old user_library collection
      final librarySnapshot = await _firestore.collection('user_library').get();
      for (final doc in librarySnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete old game_ratings collection
      final ratingsSnapshot = await _firestore.collection('game_ratings').get();
      for (final doc in ratingsSnapshot.docs) {
        await doc.reference.delete();
      }
      */

      debugPrint('Old collections cleanup completed');
    } catch (e) {
      debugPrint('Error cleaning up old collections: $e');
    }
  }

  /// Verify migration integrity
  static Future<Map<String, dynamic>> verifyMigration(String userId) async {
    try {
      final results = <String, dynamic>{
        'userId': userId,
        'profileExists': false,
        'libraryCount': 0,
        'ratingsCount': 0,
        'statsGenerated': false,
        'errors': <String>[],
      };

      // Check profile
      final profile = await UserDataService.getUserProfile(userId);
      results['profileExists'] = profile != null;

      if (profile != null) {
        // Check library
        final library = await UserDataService.getUserLibrary(userId);
        results['libraryCount'] = library.length;

        // Check ratings
        final ratings = await UserDataService.getUserRatings(userId);
        results['ratingsCount'] = ratings.length;

        // Check stats
        results['statsGenerated'] = profile['stats'] != null;
      }

      return results;
    } catch (e) {
      return {
        'userId': userId,
        'error': e.toString(),
      };
    }
  }

  /// Generate comprehensive migration report
  static Future<Map<String, dynamic>> generateMigrationReport() async {
    try {
      final report = <String, dynamic>{
        'totalUsers': 0,
        'migratedUsers': 0,
        'errors': <String>[],
        'userDetails': <Map<String, dynamic>>[],
      };

      final usersSnapshot = await _firestore.collection('users').get();
      report['totalUsers'] = usersSnapshot.docs.length;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final verification = await verifyMigration(userDoc.id);
          report['userDetails'].add(verification);
          
          if (verification['profileExists'] == true) {
            report['migratedUsers']++;
          }
        } catch (e) {
          report['errors'].add('User ${userDoc.id}: $e');
        }
      }

      return report;
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}