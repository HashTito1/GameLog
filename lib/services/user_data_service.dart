import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  
  // Singleton pattern
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();
  static UserDataService get instance => _instance;

  // Save user's favorite game to Firestore
  static Future<void> saveFavoriteGame({
    required String userId,
    required String gameId,
    required String gameName,
    String? gameImage,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set({
        'favoriteGame': {
          'gameId': gameId,
          'gameName': gameName,
          'gameImage': gameImage,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving favorite game: $e');
      throw Exception('Failed to save favorite game: $e');
    }
  }

  // Get user's favorite game from Firestore
  static Future<Map<String, dynamic>?> getFavoriteGame(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final favoriteGame = data['favoriteGame'] as Map<String, dynamic>?;
        
        if (favoriteGame != null) {
          return favoriteGame;
        }
      }
      
      return null;
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
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final playlists = data['playlists'] as List<dynamic>?;
        return playlists?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
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

  // Create playlist
  static Future<void> createPlaylist(String userId, String playlistName, List<String> gameIds) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      List<Map<String, dynamic>> playlists = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final existingPlaylists = data['playlists'] as List<dynamic>?;
        playlists = existingPlaylists?.cast<Map<String, dynamic>>() ?? [];
      }

      playlists.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': playlistName,
        'gameIds': gameIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set({
        'playlists': playlists,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      throw Exception('Failed to create playlist: $e');
    }
  }
}


