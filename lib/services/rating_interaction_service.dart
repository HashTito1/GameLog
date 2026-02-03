import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rating_comment.dart';
import '../models/user_rating.dart';
import 'user_data_service.dart';

class RatingInteractionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ratingsCollection = 'game_ratings';
  static const String _commentsCollection = 'rating_comments';
  
  // Singleton pattern
  static final RatingInteractionService _instance = RatingInteractionService._internal();
  factory RatingInteractionService() => _instance;
  RatingInteractionService._internal();
  static RatingInteractionService get instance => _instance;

  // Like/unlike a rating - Updated to work with both storage systems
  Future<void> toggleRatingLike(String ratingId, String userId) async {
    try {
      debugPrint('Toggling like for rating: $ratingId by user: $userId');
      
      // Try to find the rating in the old game_ratings collection first
      final oldRatingRef = _firestore.collection(_ratingsCollection).doc(ratingId);
      final oldRatingDoc = await oldRatingRef.get();
      
      if (oldRatingDoc.exists) {
        // Update the old collection
        await _updateRatingLikes(oldRatingRef, userId);
      }
      
      // Also update the new user subcollection structure
      // Extract userId and gameId from ratingId (format: userId_gameId)
      final parts = ratingId.split('_');
      if (parts.length >= 2) {
        final ratingUserId = parts[0];
        final gameId = parts.sublist(1).join('_'); // Handle gameIds with underscores
        
        final userRatingRef = _firestore
            .collection('users')
            .doc(ratingUserId)
            .collection('ratings')
            .doc(gameId);
            
        final userRatingDoc = await userRatingRef.get();
        if (userRatingDoc.exists) {
          await _updateRatingLikes(userRatingRef, userId);
        }
      }
      
      debugPrint('Rating like toggled successfully');
    } catch (e) {
      debugPrint('Error toggling rating like: $e');
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Helper method to update likes on a rating document
  Future<void> _updateRatingLikes(DocumentReference ratingRef, String userId) async {
    await _firestore.runTransaction((transaction) async {
      final ratingDoc = await transaction.get(ratingRef);
      
      if (!ratingDoc.exists) {
        return;
      }
      
      final data = ratingDoc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final likeCount = data['likeCount'] ?? 0;
      
      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        transaction.update(ratingRef, {
          'likedBy': likedBy,
          'likeCount': likeCount - 1,
        });
        debugPrint('Rating unliked. New count: ${likeCount - 1}');
      } else {
        // Like
        likedBy.add(userId);
        transaction.update(ratingRef, {
          'likedBy': likedBy,
          'likeCount': likeCount + 1,
        });
        debugPrint('Rating liked. New count: ${likeCount + 1}');
      }
    });
  }

  // Add a comment to a rating
  Future<String> addComment({
    required String ratingId,
    required String authorId,
    required String authorUsername,
    required String content,
  }) async {
    try {
      debugPrint('Adding comment to rating: $ratingId');
      final now = DateTime.now();
      final commentId = _firestore.collection(_commentsCollection).doc().id;
      
      // Get current user profile data
      String? displayName;
      String? profileImage;
      
      try {
        final userProfile = await UserDataService.getUserProfile(authorId);
        if (userProfile != null) {
          displayName = userProfile['displayName'] ?? userProfile['username'];
          profileImage = userProfile['profileImage'];
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
      }
      
      final comment = RatingComment(
        id: commentId,
        ratingId: ratingId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: displayName,
        authorProfileImage: profileImage,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

      // Save comment to Firestore
      await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .set(comment.toMap());

      // Increment comment count on both rating storage systems
      await _incrementCommentCount(ratingId);

      debugPrint('Comment added successfully: $commentId');
      return commentId;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a rating
  Future<List<RatingComment>> getCommentsForRating(String ratingId, {int limit = 50}) async {
    try {
      debugPrint('Fetching comments for rating: $ratingId');
      final querySnapshot = await _firestore
          .collection(_commentsCollection)
          .where('ratingId', isEqualTo: ratingId)
          .orderBy('createdAt', descending: false) // Oldest first
          .limit(limit)
          .get();

      final comments = querySnapshot.docs
          .map((doc) => RatingComment.fromMap(doc.data()))
          .toList();

      debugPrint('Found ${comments.length} comments for rating');
      return comments;
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  // Like/unlike a comment
  Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      debugPrint('Toggling like for comment: $commentId by user: $userId');
      final commentRef = _firestore.collection(_commentsCollection).doc(commentId);
      
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }
        
        final data = commentDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final likeCount = data['likeCount'] ?? 0;
        
        if (likedBy.contains(userId)) {
          // Unlike
          likedBy.remove(userId);
          transaction.update(commentRef, {
            'likedBy': likedBy,
            'likeCount': likeCount - 1,
          });
          debugPrint('Comment unliked. New count: ${likeCount - 1}');
        } else {
          // Like
          likedBy.add(userId);
          transaction.update(commentRef, {
            'likedBy': likedBy,
            'likeCount': likeCount + 1,
          });
          debugPrint('Comment liked. New count: ${likeCount + 1}');
        }
      });
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  // Edit a comment
  Future<void> editComment(String commentId, String newContent) async {
    try {
      debugPrint('Editing comment: $commentId');
      await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .update({
        'content': newContent,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'isEdited': true,
      });
      debugPrint('Comment edited successfully');
    } catch (e) {
      debugPrint('Error editing comment: $e');
      throw Exception('Failed to edit comment: $e');
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String ratingId) async {
    try {
      debugPrint('Deleting comment: $commentId');
      await _firestore.collection(_commentsCollection).doc(commentId).delete();
      
      // Decrement comment count on both rating storage systems
      await _decrementCommentCount(ratingId);
      
      debugPrint('Comment deleted successfully');
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Get rating with interaction data (likes, comments)
  Future<Map<String, dynamic>> getRatingWithInteractions(String ratingId, String currentUserId) async {
    try {
      // Try to get the rating from the old collection first
      final ratingDoc = await _firestore.collection(_ratingsCollection).doc(ratingId).get();
      UserRating? rating;
      
      if (ratingDoc.exists) {
        rating = UserRating.fromMap(ratingDoc.data()!);
      } else {
        // Try to get from user subcollection
        final parts = ratingId.split('_');
        if (parts.length >= 2) {
          final ratingUserId = parts[0];
          final gameId = parts.sublist(1).join('_');
          
          final userRatingDoc = await _firestore
              .collection('users')
              .doc(ratingUserId)
              .collection('ratings')
              .doc(gameId)
              .get();
              
          if (userRatingDoc.exists) {
            final data = userRatingDoc.data()!;
            data['id'] = ratingId; // Ensure the ID is set correctly
            rating = UserRating.fromMap(data);
          }
        }
      }
      
      if (rating == null) {
        return {'rating': null, 'comments': <RatingComment>[], 'isLiked': false};
      }

      final isLiked = rating.likedBy.contains(currentUserId);

      // Get comments
      final comments = await getCommentsForRating(ratingId);

      return {
        'rating': rating,
        'comments': comments,
        'isLiked': isLiked,
      };
    } catch (e) {
      debugPrint('Error getting rating with interactions: $e');
      return {'rating': null, 'comments': <RatingComment>[], 'isLiked': false};
    }
  }

  // Get user's recent comments
  Future<List<RatingComment>> getUserComments(String userId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_commentsCollection)
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => RatingComment.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting user comments: $e');
      return [];
    }
  }

  // Helper method to increment comment count on both storage systems
  Future<void> _incrementCommentCount(String ratingId) async {
    try {
      // Update old collection
      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .update({
        'commentCount': FieldValue.increment(1),
      });
      
      // Update new user subcollection
      final parts = ratingId.split('_');
      if (parts.length >= 2) {
        final ratingUserId = parts[0];
        final gameId = parts.sublist(1).join('_');
        
        await _firestore
            .collection('users')
            .doc(ratingUserId)
            .collection('ratings')
            .doc(gameId)
            .update({
          'commentCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Error incrementing comment count: $e');
    }
  }

  // Helper method to decrement comment count on both storage systems
  Future<void> _decrementCommentCount(String ratingId) async {
    try {
      // Update old collection
      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .update({
        'commentCount': FieldValue.increment(-1),
      });
      
      // Update new user subcollection
      final parts = ratingId.split('_');
      if (parts.length >= 2) {
        final ratingUserId = parts[0];
        final gameId = parts.sublist(1).join('_');
        
        await _firestore
            .collection('users')
            .doc(ratingUserId)
            .collection('ratings')
            .doc(gameId)
            .update({
          'commentCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      debugPrint('Error decrementing comment count: $e');
    }
  }

  // Get interaction statistics
  Future<Map<String, dynamic>> getInteractionStats(String ratingId) async {
    try {
      final ratingDoc = await _firestore.collection(_ratingsCollection).doc(ratingId).get();
      if (!ratingDoc.exists) {
        return {'likeCount': 0, 'commentCount': 0};
      }

      final data = ratingDoc.data()!;
      return {
        'likeCount': data['likeCount'] ?? 0,
        'commentCount': data['commentCount'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting interaction stats: $e');
      return {'likeCount': 0, 'commentCount': 0};
    }
  }
}