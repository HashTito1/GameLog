import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_service.dart';

class DatabaseDebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search for users by username, display name, or email
  static Future<void> searchAndDisplayUser(String query) async {
    try {
      debugPrint('=== SEARCHING FOR USER: "$query" ===');
      
      // Search using the existing search method
      final searchResults = await UserDataService.searchUsers(query);
      
      if (searchResults.isEmpty) {
        debugPrint('❌ No users found matching "$query"');
        
        // Try to search all users and see what's available
        debugPrint('\n📋 Checking all users in database...');
        final allUsers = await UserDataService.getAllUsers(limit: 20);
        debugPrint('Total users in database: ${allUsers.length}');
        
        for (final user in allUsers) {
          debugPrint('User: ${user['username']} | Display: ${user['displayName']} | Email: ${user['email']}');
        }
        
        return;
      }
      
      debugPrint('✅ Found ${searchResults.length} user(s) matching "$query"');
      
      // Display each matching user
      for (int i = 0; i < searchResults.length; i++) {
        final user = searchResults[i];
        debugPrint('\n--- USER ${i + 1} ---');
        await _displayUserDetails(user);
      }
      
      debugPrint('\n=== SEARCH COMPLETE ===');
    } catch (e) {
      debugPrint('❌ Error searching for user: $e');
    }
  }

  /// Display detailed information about a user
  static Future<void> _displayUserDetails(Map<String, dynamic> user) async {
    try {
      final userId = user['id'] ?? 'unknown';
      
      debugPrint('🆔 User ID: $userId');
      debugPrint('👤 Username: ${user['username'] ?? 'N/A'}');
      debugPrint('📝 Display Name: ${user['displayName'] ?? 'N/A'}');
      debugPrint('📧 Email: ${user['email'] ?? 'N/A'}');
      debugPrint('📄 Bio: ${user['bio'] ?? 'N/A'}');
      debugPrint('🖼️ Profile Image: ${user['profileImage'] ?? 'N/A'}');
      debugPrint('🎨 Banner Image: ${user['bannerImage'] ?? 'N/A'}');
      debugPrint('📅 Join Date: ${_formatTimestamp(user['joinDate'])}');
      debugPrint('🔄 Last Active: ${_formatTimestamp(user['lastActiveAt'])}');
      debugPrint('🟢 Online: ${user['isOnline'] ?? false}');
      
      // Check for favorite game
      final favoriteGame = user['favoriteGame'];
      if (favoriteGame != null) {
        debugPrint('⭐ Favorite Game: ${favoriteGame['gameName']} (ID: ${favoriteGame['gameId']})');
      } else {
        debugPrint('⭐ Favorite Game: None');
      }
      
      // Check for playlists
      final playlists = user['playlists'] as List<dynamic>?;
      if (playlists != null && playlists.isNotEmpty) {
        debugPrint('📋 Playlists: ${playlists.length}');
        for (final playlist in playlists) {
          debugPrint('  - ${playlist['name']} (${playlist['gameIds']?.length ?? 0} games)');
        }
      } else {
        debugPrint('📋 Playlists: None');
      }
      
      // Check for stats
      final stats = user['stats'];
      if (stats != null) {
        debugPrint('📊 Stats Available: Yes');
        final libraryStats = stats['library'];
        final ratingStats = stats['ratings'];
        
        if (libraryStats != null) {
          debugPrint('  📚 Library: ${libraryStats['totalGames'] ?? 0} games');
          debugPrint('    - Want to Play: ${libraryStats['wantToPlay'] ?? 0}');
          debugPrint('    - Playing: ${libraryStats['playing'] ?? 0}');
          debugPrint('    - Completed: ${libraryStats['completed'] ?? 0}');
          debugPrint('    - Hours Played: ${libraryStats['totalHoursPlayed'] ?? 0}');
        }
        
        if (ratingStats != null) {
          debugPrint('  ⭐ Ratings: ${ratingStats['totalRatings'] ?? 0} ratings');
          debugPrint('    - Average: ${ratingStats['averageRating']?.toStringAsFixed(1) ?? 'N/A'}');
          debugPrint('    - Recommended: ${ratingStats['recommendedGames'] ?? 0}');
        }
      } else {
        debugPrint('📊 Stats Available: No');
      }
      
      // Check subcollections
      await _checkUserSubcollections(userId);
      
    } catch (e) {
      debugPrint('❌ Error displaying user details: $e');
    }
  }

  /// Check user's subcollections (library and ratings)
  static Future<void> _checkUserSubcollections(String userId) async {
    try {
      // Check library subcollection
      final librarySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .limit(5)
          .get();
      
      debugPrint('📚 Library Subcollection: ${librarySnapshot.docs.length} entries (showing first 5)');
      for (final doc in librarySnapshot.docs) {
        final data = doc.data();
        debugPrint('  - ${data['gameTitle']} (${data['status']}) - Rating: ${data['userRating'] ?? 'N/A'}');
      }
      
      // Check ratings subcollection
      final ratingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .limit(5)
          .get();
      
      debugPrint('⭐ Ratings Subcollection: ${ratingsSnapshot.docs.length} entries (showing first 5)');
      for (final doc in ratingsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  - ${data['gameTitle']} - ${data['rating']}/5 ${data['isRecommended'] == true ? '👍' : ''}');
      }
      
      // Check global collections
      await _checkGlobalCollections(userId);
      
    } catch (e) {
      debugPrint('❌ Error checking subcollections: $e');
    }
  }

  /// Check global collections for user data
  static Future<void> _checkGlobalCollections(String userId) async {
    try {
      // Check global library collection
      final globalLibrarySnapshot = await _firestore
          .collection('user_library')
          .where('userId', isEqualTo: userId)
          .limit(3)
          .get();
      
      debugPrint('🌐 Global Library: ${globalLibrarySnapshot.docs.length} entries');
      
      // Check global ratings collection
      final globalRatingsSnapshot = await _firestore
          .collection('user_ratings')
          .where('userId', isEqualTo: userId)
          .limit(3)
          .get();
      
      debugPrint('🌐 Global Ratings: ${globalRatingsSnapshot.docs.length} entries');
      
      // Check old collections for backward compatibility
      final oldLibrarySnapshot = await _firestore
          .collection('user_library')
          .where('userId', isEqualTo: userId)
          .limit(3)
          .get();
      
      final oldRatingsSnapshot = await _firestore
          .collection('game_ratings')
          .where('userId', isEqualTo: userId)
          .limit(3)
          .get();
      
      debugPrint('🔄 Old Library Collection: ${oldLibrarySnapshot.docs.length} entries');
      debugPrint('🔄 Old Ratings Collection: ${oldRatingsSnapshot.docs.length} entries');
      
    } catch (e) {
      debugPrint('❌ Error checking global collections: $e');
    }
  }

  /// Format timestamp for display
  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is int) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return timestamp.toString();
      }
      
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  /// Get all users with "ef" in their data
  static Future<void> findUsersWithEf() async {
    try {
      debugPrint('=== SEARCHING FOR USERS WITH "ef" ===');
      
      final allUsers = await UserDataService.getAllUsers(limit: 100);
      final matchingUsers = <Map<String, dynamic>>[];
      
      for (final user in allUsers) {
        final username = (user['username'] ?? '').toString().toLowerCase();
        final displayName = (user['displayName'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        
        if (username.contains('ef') || displayName.contains('ef') || email.contains('ef')) {
          matchingUsers.add(user);
        }
      }
      
      debugPrint('Found ${matchingUsers.length} users with "ef":');
      for (final user in matchingUsers) {
        debugPrint('- Username: ${user['username']}, Display: ${user['displayName']}, Email: ${user['email']}');
      }
      
      if (matchingUsers.isNotEmpty) {
        debugPrint('\nDetailed info for first match:');
        await _displayUserDetails(matchingUsers.first);
      }
      
    } catch (e) {
      debugPrint('❌ Error finding users with "ef": $e');
    }
  }

  /// Check database collections structure
  static Future<void> checkDatabaseStructure() async {
    try {
      debugPrint('=== DATABASE STRUCTURE CHECK ===');
      
      // Check main collections
      final collections = ['users', 'user_library', 'user_ratings', 'game_ratings'];
      
      for (final collection in collections) {
        try {
          final snapshot = await _firestore.collection(collection).limit(1).get();
          debugPrint('✅ Collection "$collection": ${snapshot.docs.length > 0 ? 'Has data' : 'Empty'}');
        } catch (e) {
          debugPrint('❌ Collection "$collection": Error - $e');
        }
      }
      
      // Check users collection structure
      final usersSnapshot = await _firestore.collection('users').limit(3).get();
      debugPrint('\n📊 Users collection sample:');
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        debugPrint('User ${doc.id}: ${data.keys.join(', ')}');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking database structure: $e');
    }
  }
}