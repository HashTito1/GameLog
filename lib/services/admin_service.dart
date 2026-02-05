import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _adminsCollection = 'admins';
  static const String _adminListDoc = 'list';
  static const String _superAdminUsername = 'petrichorvibe69'; // Super admin username
  
  // Singleton pattern
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();
  static AdminService get instance => _instance;

  // Check if current user is super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return false;
    
    debugPrint('Checking super admin: current username = "${currentUser.username}", expected = "$_superAdminUsername"');
    return currentUser.username.toLowerCase() == _superAdminUsername.toLowerCase();
  }

  // Check if current user is admin (including super admin)
  Future<bool> isCurrentUserAdmin() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return false;
    
    // Super admin is always an admin
    if (await isCurrentUserSuperAdmin()) return true;
    
    try {
      return await isUserAdmin(currentUser.uid);
    } catch (e) {
      // If admin document doesn't exist yet, check if this is the super admin
      debugPrint('Admin document not found, checking if super admin: $e');
      return await isCurrentUserSuperAdmin();
    }
  }

  // Check if a specific user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      final adminDoc = await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .get();

      if (adminDoc.exists && adminDoc.data() != null) {
        final adminIds = List<String>.from(adminDoc.data()!['adminIds'] ?? []);
        return adminIds.contains(userId);
      }
      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      // If we can't access the admin document, check if this is the super admin
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        return currentUser.username.toLowerCase() == _superAdminUsername.toLowerCase();
      }
      return false;
    }
  }

  // Add user as admin (only super admin can do this)
  Future<void> addAdmin(String userId) async {
    if (!await isCurrentUserSuperAdmin()) {
      throw Exception('Only the super admin can add other admins');
    }

    try {
      await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .update({
        'adminIds': FieldValue.arrayUnion([userId]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedBy': FirebaseAuthService().currentUser?.uid,
      });
    } catch (e) {
      // If document doesn't exist, create it
      await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .set({
        'adminIds': [userId],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'createdBy': FirebaseAuthService().currentUser?.uid,
        'updatedBy': FirebaseAuthService().currentUser?.uid,
      });
    }
  }

  // Remove admin (only super admin can do this)
  Future<void> removeAdmin(String userId) async {
    if (!await isCurrentUserSuperAdmin()) {
      throw Exception('Only the super admin can remove other admins');
    }

    try {
      await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .update({
        'adminIds': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedBy': FirebaseAuthService().currentUser?.uid,
      });
    } catch (e) {
      throw Exception('Failed to remove admin: $e');
    }
  }

  // Get all admin user IDs
  Future<List<String>> getAllAdminIds() async {
    try {
      final adminDoc = await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .get();

      if (adminDoc.exists && adminDoc.data() != null) {
        return List<String>.from(adminDoc.data()!['adminIds'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting admin IDs: $e');
      return [];
    }
  }

  // Get admin details with user information
  Future<List<Map<String, dynamic>>> getAllAdminDetails() async {
    if (!await isCurrentUserSuperAdmin()) {
      throw Exception('Only the super admin can view admin details');
    }

    try {
      final adminIds = await getAllAdminIds();
      final adminDetails = <Map<String, dynamic>>[];

      for (final adminId in adminIds) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(adminId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data()!;
            adminDetails.add({
              'userId': adminId,
              'username': userData['username'] ?? 'Unknown',
              'displayName': userData['displayName'] ?? userData['username'] ?? 'Unknown',
              'profileImage': userData['profileImage'],
              'email': userData['email'],
              'addedAt': userData['createdAt'],
            });
          }
        } catch (e) {
          debugPrint('Error fetching admin details for $adminId: $e');
        }
      }

      return adminDetails;
    } catch (e) {
      throw Exception('Failed to get admin details: $e');
    }
  }

  // Delete forum post (admin only)
  Future<void> deleteForumPost(String postId) async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can delete forum posts');
    }

    try {
      // Get the post first to check if it has replies
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final parentPostId = postData['parentPostId'];

      // If this is a reply, decrement parent's reply count
      if (parentPostId != null) {
        await _firestore
            .collection('forum_posts')
            .doc(parentPostId)
            .update({
          'replyCount': FieldValue.increment(-1),
        });
      }

      // Delete all replies to this post first
      final repliesQuery = await _firestore
          .collection('forum_posts')
          .where('parentPostId', isEqualTo: postId)
          .get();

      for (final replyDoc in repliesQuery.docs) {
        await replyDoc.reference.delete();
      }

      // Delete the post itself
      await _firestore
          .collection('forum_posts')
          .doc(postId)
          .delete();

      debugPrint('Admin deleted forum post: $postId');
    } catch (e) {
      throw Exception('Failed to delete forum post: $e');
    }
  }

  // Delete game rating (admin only)
  Future<void> deleteGameRating(String ratingId) async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can delete game ratings');
    }

    try {
      await _firestore
          .collection('game_ratings')
          .doc(ratingId)
          .delete();

      debugPrint('Admin deleted game rating: $ratingId');
    } catch (e) {
      throw Exception('Failed to delete game rating: $e');
    }
  }

  // Delete rating comment (admin only)
  Future<void> deleteRatingComment(String commentId) async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can delete rating comments');
    }

    try {
      await _firestore
          .collection('rating_comments')
          .doc(commentId)
          .delete();

      debugPrint('Admin deleted rating comment: $commentId');
    } catch (e) {
      throw Exception('Failed to delete rating comment: $e');
    }
  }

  // Ban user (admin only) - prevents them from posting
  Future<void> banUser(String userId, String reason) async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can ban users');
    }

    try {
      await _firestore
          .collection('banned_users')
          .doc(userId)
          .set({
        'userId': userId,
        'reason': reason,
        'bannedAt': DateTime.now().millisecondsSinceEpoch,
        'bannedBy': FirebaseAuthService().currentUser?.uid,
      });

      debugPrint('Admin banned user: $userId for reason: $reason');
    } catch (e) {
      throw Exception('Failed to ban user: $e');
    }
  }

  // Unban user (admin only)
  Future<void> unbanUser(String userId) async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can unban users');
    }

    try {
      await _firestore
          .collection('banned_users')
          .doc(userId)
          .delete();

      debugPrint('Admin unbanned user: $userId');
    } catch (e) {
      throw Exception('Failed to unban user: $e');
    }
  }

  // Check if user is banned
  Future<bool> isUserBanned(String userId) async {
    try {
      final banDoc = await _firestore
          .collection('banned_users')
          .doc(userId)
          .get();

      return banDoc.exists;
    } catch (e) {
      debugPrint('Error checking ban status: $e');
      return false;
    }
  }

  // Get moderation statistics
  Future<Map<String, dynamic>> getModerationStats() async {
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admins can view moderation stats');
    }

    try {
      // Get total counts
      final forumPostsCount = await _firestore
          .collection('forum_posts')
          .get()
          .then((snapshot) => snapshot.docs.length);

      final gameRatingsCount = await _firestore
          .collection('game_ratings')
          .get()
          .then((snapshot) => snapshot.docs.length);

      final ratingCommentsCount = await _firestore
          .collection('rating_comments')
          .get()
          .then((snapshot) => snapshot.docs.length);

      final bannedUsersCount = await _firestore
          .collection('banned_users')
          .get()
          .then((snapshot) => snapshot.docs.length);

      final usersCount = await _firestore
          .collection('users')
          .get()
          .then((snapshot) => snapshot.docs.length);

      final adminCount = (await getAllAdminIds()).length;

      return {
        'totalForumPosts': forumPostsCount,
        'totalGameRatings': gameRatingsCount,
        'totalRatingComments': ratingCommentsCount,
        'totalBannedUsers': bannedUsersCount,
        'totalUsers': usersCount,
        'totalAdmins': adminCount,
        'isSuperAdmin': await isCurrentUserSuperAdmin(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get moderation stats: $e');
    }
  }

  // Initialize admin system (call this once to set up the super admin)
  static Future<void> initializeSuperAdmin() async {
    try {
      // Find the super admin user by username
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _superAdminUsername)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        debugPrint('Super admin user $_superAdminUsername not found');
        return;
      }

      final superAdminUserId = usersQuery.docs.first.id;

      await _firestore
          .collection(_adminsCollection)
          .doc(_adminListDoc)
          .set({
        'adminIds': [superAdminUserId],
        'superAdminId': superAdminUserId,
        'superAdminUsername': _superAdminUsername,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('Super admin system initialized for user: $_superAdminUsername ($superAdminUserId)');
    } catch (e) {
      debugPrint('Error initializing super admin system: $e');
    }
  }

  // Initialize super admin if current user is the super admin
  Future<void> initializeSuperAdminIfNeeded() async {
    if (await isCurrentUserSuperAdmin()) {
      try {
        final currentUser = FirebaseAuthService().currentUser;
        if (currentUser != null) {
          // Clear any existing admin data and set this user as the sole super admin
          await _firestore
              .collection(_adminsCollection)
              .doc(_adminListDoc)
              .set({
            'adminIds': [currentUser.uid], // Only this user as admin
            'superAdminId': currentUser.uid,
            'superAdminUsername': _superAdminUsername,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
          debugPrint('Super admin system initialized for current user: ${currentUser.username} (${currentUser.uid})');
        }
      } catch (e) {
        debugPrint('Error initializing super admin: $e');
      }
    }
  }
}