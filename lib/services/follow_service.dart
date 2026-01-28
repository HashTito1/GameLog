import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';

class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Singleton pattern
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();
  static FollowService get instance => _instance;

  /// Follow a user
  static Future<void> followUser(String targetUserId) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (currentUser.uid == targetUserId) {
        throw Exception('Cannot follow yourself');
      }

      final batch = _firestore.batch();
      final now = DateTime.now();

      // Add to current user's following list
      final followingRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId);
      
      batch.set(followingRef, {
        'userId': targetUserId,
        'followedAt': FieldValue.serverTimestamp(),
        'createdAt': now.millisecondsSinceEpoch,
      });

      // Add to target user's followers list
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid);
      
      batch.set(followerRef, {
        'userId': currentUser.uid,
        'followedAt': FieldValue.serverTimestamp(),
        'createdAt': now.millisecondsSinceEpoch,
      });

      // Update follow counts
      final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'following': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      batch.update(targetUserRef, {
        'followers': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Successfully followed user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      throw Exception('Failed to follow user: $e');
    }
  }

  /// Unfollow a user
  static Future<void> unfollowUser(String targetUserId) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();

      // Remove from current user's following list
      final followingRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId);
      
      batch.delete(followingRef);

      // Remove from target user's followers list
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid);
      
      batch.delete(followerRef);

      // Update follow counts
      final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'following': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      batch.update(targetUserRef, {
        'followers': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Successfully unfollowed user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      throw Exception('Failed to unfollow user: $e');
    }
  }

  /// Check if current user is following a specific user
  static Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return false;

      final followingDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId)
          .get();

      return followingDoc.exists;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Get list of users that current user is following
  static Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> following = [];
      
      for (final doc in followingSnapshot.docs) {
        final followData = doc.data();
        final targetUserId = followData['userId'];
        
        // Get user profile data
        final userDoc = await _firestore
            .collection('users')
            .doc(targetUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userData['followedAt'] = followData['followedAt'];
          following.add(userData);
        }
      }

      return following;
    } catch (e) {
      debugPrint('❌ Error getting following list: $e');
      return [];
    }
  }

  /// Get list of users following the current user
  static Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .orderBy('followedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> followers = [];
      
      for (final doc in followersSnapshot.docs) {
        final followData = doc.data();
        final followerUserId = followData['userId'];
        
        // Get user profile data
        final userDoc = await _firestore
            .collection('users')
            .doc(followerUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userData['followedAt'] = followData['followedAt'];
          followers.add(userData);
        }
      }

      return followers;
    } catch (e) {
      debugPrint('❌ Error getting followers list: $e');
      return [];
    }
  }

  /// Create notification when a followed user rates a game
  static Future<void> notifyFollowersOfRating({
    required String userId,
    required String gameId,
    required String gameTitle,
    required double rating,
    String? review,
  }) async {
    try {
      // Get all followers of this user
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      if (followersSnapshot.docs.isEmpty) return;

      // Get user profile for notification
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final username = userData?['displayName'] ?? userData?['username'] ?? 'Someone';

      final batch = _firestore.batch();
      final now = DateTime.now();

      // Create notification for each follower
      for (final followerDoc in followersSnapshot.docs) {
        final followerId = followerDoc.data()['userId'];
        
        final notificationRef = _firestore
            .collection('users')
            .doc(followerId)
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'id': notificationRef.id,
          'type': 'follow_rating',
          'fromUserId': userId,
          'fromUsername': username,
          'gameId': gameId,
          'gameTitle': gameTitle,
          'rating': rating,
          'review': review,
          'message': '$username rated $gameTitle ${rating.toStringAsFixed(1)} stars',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': now.millisecondsSinceEpoch,
        });
      }

      await batch.commit();
      debugPrint('✅ Notified ${followersSnapshot.docs.length} followers about rating');
    } catch (e) {
      debugPrint('❌ Error notifying followers: $e');
    }
  }
}