import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_data_service.dart';
import 'database_migration_service.dart';

class DatabaseInitializer {
  /// Initialize the database for the current user
  static Future<void> initializeForCurrentUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No current user found for database initialization');
        return;
      }

      debugPrint('Initializing database for user: ${currentUser.uid}');

      // Ensure user profile exists with new structure
      await UserDataService.ensureUserProfile(currentUser.uid);

      // Migrate existing data if needed
      await DatabaseMigrationService.migrateUserData(currentUser.uid);

      debugPrint('Database initialization completed for user: ${currentUser.uid}');
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  /// Initialize the database for all users (admin function)
  static Future<void> initializeForAllUsers() async {
    try {
      debugPrint('Starting database initialization for all users...');

      // Migrate all users to new structure
      await DatabaseMigrationService.migrateAllUsers();

      // Generate migration report
      final report = await DatabaseMigrationService.generateMigrationReport();
      debugPrint('Migration report: $report');

      debugPrint('Database initialization completed for all users');
    } catch (e) {
      debugPrint('Error initializing database for all users: $e');
    }
  }

  /// Check if user needs database migration
  static Future<bool> needsMigration(String userId) async {
    try {
      final profile = await UserDataService.getUserProfile(userId);
      
      // Check if profile has new structure indicators
      if (profile == null) return true;
      if (profile['stats'] == null) return true;
      
      // Check if subcollections exist
      final library = await UserDataService.getUserLibrary(userId, limit: 1);
      final ratings = await UserDataService.getUserRatings(userId, limit: 1);
      
      return library.isEmpty && ratings.isEmpty;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return true;
    }
  }

  /// Quick setup for new users
  static Future<void> setupNewUser(String userId) async {
    try {
      debugPrint('Setting up new user: $userId');

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || firebaseUser.uid != userId) {
        debugPrint('Firebase user not found or mismatch');
        return;
      }

      // Create comprehensive user profile
      await UserDataService.createOrUpdateUserProfile(
        userId: userId,
        username: firebaseUser.email?.split('@')[0] ?? 'user',
        displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
        email: firebaseUser.email ?? '',
        bio: '',
        profileImageUrl: '',
        bannerImageUrl: '',
        favoriteGame: null,
        playlists: [],
        preferences: {
          'theme': 'dark',
          'notifications': true,
          'privacy': 'public',
        },
      );

      debugPrint('New user setup completed: $userId');
    } catch (e) {
      debugPrint('Error setting up new user: $e');
    }
  }
}