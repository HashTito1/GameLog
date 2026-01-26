import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/auth_user.dart';

class StorageService {
  static const String _userKey = 'current_user';
  static const String _usersKey = 'all_users';
  static const String _passwordsKey = 'user_passwords';

  // Save current user
  static Future<void> saveUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    
    // Also save to users list
    final users = await getAllUsers();
    users[user.email] = user.toJson();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  // Get current user
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  // Clear current user
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Get user by email
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final users = await getAllUsers();
    return users[email];
  }

  // Get all users
  static Future<Map<String, dynamic>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      return Map<String, dynamic>.from(jsonDecode(usersJson));
    }
    return {};
  }

  // Save password (in production, use proper encryption)
  static Future<void> savePassword(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await getPasswords();
    passwords[email] = password; // In production, hash this!
    await prefs.setString(_passwordsKey, jsonEncode(passwords));
  }

  // Get password
  static Future<String?> getPassword(String email) async {
    final passwords = await getPasswords();
    return passwords[email];
  }

  // Get all passwords
  static Future<Map<String, String>> getPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final passwordsJson = prefs.getString(_passwordsKey);
    if (passwordsJson != null) {
      return Map<String, String>.from(jsonDecode(passwordsJson));
    }
    return {};
  }

  // Check if user exists
  static Future<bool> userExists(String email) async {
    final users = await getAllUsers();
    return users.containsKey(email);
  }

  // Validate user credentials
  static Future<bool> validateCredentials(String email, String password) async {
    final storedPassword = await getPassword(email);
    return storedPassword == password;
  }

  // Save game library for user
  static Future<void> saveUserLibrary(String userId, List<Map<String, dynamic>> library) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_$userId', jsonEncode(library));
  }

  // Get game library for user
  static Future<List<Map<String, dynamic>>> getUserLibrary(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final libraryJson = prefs.getString('library_$userId');
    if (libraryJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(libraryJson));
    }
    return [];
  }

  // Save user reviews
  static Future<void> saveUserReviews(String userId, List<Map<String, dynamic>> reviews) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reviews_$userId', jsonEncode(reviews));
  }

  // Get user reviews
  static Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final reviewsJson = prefs.getString('reviews_$userId');
    if (reviewsJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(reviewsJson));
    }
    return [];
  }

  // Clear all data (for testing)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Export user data (for backup/migration)
  static Future<Map<String, dynamic>> exportUserData(String userId) async {
    final user = await getUser();
    final library = await getUserLibrary(userId);
    final reviews = await getUserReviews(userId);

    return {
      'user': user,
      'library': library,
      'reviews': reviews,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  // Import user data
  static Future<void> importUserData(Map<String, dynamic> data) async {
    if (data['user'] != null) {
      final user = AuthUser.fromJson(data['user']);
      await saveUser(user);
    }
    
    if (data['library'] != null && data['user'] != null) {
      final userId = data['user']['id'];
      await saveUserLibrary(userId, List<Map<String, dynamic>>.from(data['library']));
    }
    
    if (data['reviews'] != null && data['user'] != null) {
      final userId = data['user']['id'];
      await saveUserReviews(userId, List<Map<String, dynamic>>.from(data['reviews']));
    }
  }

  // Save user's favorite game
  static Future<void> saveFavoriteGame(String userId, String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_game_$userId', gameId);
  }

  // Get user's favorite game
  static Future<String?> getFavoriteGame(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('favorite_game_$userId');
  }

  // Save user's playlists
  static Future<void> saveUserPlaylists(String userId, List<Map<String, dynamic>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlists_$userId', jsonEncode(playlists));
  }

  // Get user's playlists
  static Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistsJson = prefs.getString('playlists_$userId');
    if (playlistsJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(playlistsJson));
    }
    return [];
  }

  // Add game to playlist
  static Future<void> addGameToPlaylist(String userId, String playlistId, String gameId, String gameName, String? gameImage) async {
    final playlists = await getUserPlaylists(userId);
    final playlistIndex = playlists.indexWhere((p) => p['id'] == playlistId);
    
    if (playlistIndex != -1) {
      final games = List<Map<String, dynamic>>.from(playlists[playlistIndex]['games'] ?? []);
      final gameExists = games.any((g) => g['gameId'] == gameId);
      
      if (!gameExists) {
        games.add({
          'gameId': gameId,
          'gameName': gameName,
          'gameImage': gameImage,
          'addedAt': DateTime.now().toIso8601String(),
        });
        playlists[playlistIndex]['games'] = games;
        await saveUserPlaylists(userId, playlists);
      }
    }
  }

  // Remove game from playlist
  static Future<void> removeGameFromPlaylist(String userId, String playlistId, String gameId) async {
    final playlists = await getUserPlaylists(userId);
    final playlistIndex = playlists.indexWhere((p) => p['id'] == playlistId);
    
    if (playlistIndex != -1) {
      final games = List<Map<String, dynamic>>.from(playlists[playlistIndex]['games'] ?? []);
      games.removeWhere((g) => g['gameId'] == gameId);
      playlists[playlistIndex]['games'] = games;
      await saveUserPlaylists(userId, playlists);
    }
  }

  // Create new playlist
  static Future<void> createPlaylist(String userId, String name, String description) async {
    final playlists = await getUserPlaylists(userId);
    final newPlaylist = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'description': description,
      'games': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    playlists.add(newPlaylist);
    await saveUserPlaylists(userId, playlists);
  }

  // Delete playlist
  static Future<void> deletePlaylist(String userId, String playlistId) async {
    final playlists = await getUserPlaylists(userId);
    playlists.removeWhere((p) => p['id'] == playlistId);
    await saveUserPlaylists(userId, playlists);
  }
}