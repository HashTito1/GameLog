import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _adminsCollection = 'admins';
  static const String _adminListDoc = 'list';

  // Singleton pattern
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();
  static AdminService get instance => _instance;

  // Admin roles live in admins/list ({adminIds: [...], superAdminId: uid}),
  // keyed by Firebase Auth uid. Usernames are user-editable, so they are never
  // used for authorization. Firestore rules enforce the same checks server-side.
  Future<Map<String, dynamic>?> _getAdminList() async {
    final adminDoc = await _firestore
        .collection(_adminsCollection)
        .doc(_adminListDoc)
        .get();
    return adminDoc.exists ? adminDoc.data() : null;
  }

  // Check if current user is super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return false;

    try {
      final adminList = await _getAdminList();
      return adminList != null && adminList['superAdminId'] == currentUser.uid;
    } catch (e) {
      debugPrint('Error checking super admin status: $e');
      return false;
    }
  }

  // Check if current user is admin (including super admin)
  Future<bool> isCurrentUserAdmin() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return false;
    return isUserAdmin(currentUser.uid);
  }

  // Check if a specific user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      final adminList = await _getAdminList();
      if (adminList == null) return false;
      final adminIds = List<String>.from(adminList['adminIds'] ?? []);
      return adminIds.contains(userId) || adminList['superAdminId'] == userId;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Add user as admin (only super admin can do this)
  Future<void> addAdmin(String userId) async {
    if (!await isCurrentUserSuperAdmin()) {
      throw Exception('Only the super admin can add other admins');
    }

    await _firestore
        .collection(_adminsCollection)
        .doc(_adminListDoc)
        .update({
      'adminIds': FieldValue.arrayUnion([userId]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': FirebaseAuthService().currentUser?.uid,
    });
  }

  // Remove admin (only super admin can do this)
  Future<void> removeAdmin(String userId) async {
    if (!await isCurrentUserSuperAdmin()) {
      throw Exception('Only the super admin can remove other admins');
    }

    final adminList = await _getAdminList();
    if (adminList?['superAdminId'] == userId) {
      throw Exception('The super admin cannot be removed');
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
      // Server-side count aggregations: one cheap read each instead of
      // downloading every document.
      Future<int> countOf(String collection) async {
        final snapshot = await _firestore.collection(collection).count().get();
        return snapshot.count ?? 0;
      }

      final counts = await Future.wait([
        countOf('forum_posts'),
        countOf('game_ratings'),
        countOf('rating_comments'),
        countOf('banned_users'),
        countOf('users'),
      ]);
      final forumPostsCount = counts[0];
      final gameRatingsCount = counts[1];
      final ratingCommentsCount = counts[2];
      final bannedUsersCount = counts[3];
      final usersCount = counts[4];

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

  // The admin list can no longer be created from the app: whoever got there
  // first would have become super admin. It is created once from the
  // Firebase console instead (see docs/ADMIN_SETUP.md).
  static Future<void> initializeSuperAdmin() async {
    final adminDoc = await _firestore
        .collection(_adminsCollection)
        .doc(_adminListDoc)
        .get();
    if (!adminDoc.exists) {
      throw Exception(
        'Admin system is not set up yet. Create admins/list in the Firebase '
        'console (see docs/ADMIN_SETUP.md).',
      );
    }
  }
}