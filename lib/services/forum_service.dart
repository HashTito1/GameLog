import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/forum_post.dart';
import 'user_data_service.dart';

class ForumService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _postsCollection = 'forum_posts';
  
  // Singleton pattern
  static final ForumService _instance = ForumService._internal();
  factory ForumService() => _instance;
  ForumService._internal();
  static ForumService get instance => _instance;

  // Create a new forum post
  Future<String> createPost({
    required String authorId,
    required String authorUsername,
    required String title,
    required String content,
    String? gameId,
    String? gameTitle,
    List<String> tags = const [],
    String? parentPostId, // For replies
  }) async {
    try {
      debugPrint('Creating forum post in cloud storage...');
      final now = DateTime.now();
      final postId = _firestore.collection(_postsCollection).doc().id;
      
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
      
      final post = ForumPost(
        id: postId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorDisplayName: displayName,
        authorProfileImage: profileImage,
        title: title,
        content: content,
        gameId: gameId,
        gameTitle: gameTitle,
        tags: tags,
        parentPostId: parentPostId,
        createdAt: now,
        updatedAt: now,
      );

      // Save to Firestore cloud database
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .set(post.toMap());

      debugPrint('Forum post saved to cloud: $postId');

      // If this is a reply, increment the parent post's reply count
      if (parentPostId != null) {
        await _incrementReplyCount(parentPostId);
      }

      return postId;
    } catch (e) {
      debugPrint('Error saving forum post to cloud: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  // Get all top-level posts (not replies)
  Future<List<ForumPost>> getTopLevelPosts({
    int limit = 20,
    String? gameId,
    List<String>? tags,
  }) async {
    try {
      debugPrint('Fetching top-level posts from cloud storage...');
      
      Query query = _firestore
          .collection(_postsCollection)
          .where('parentPostId', isNull: true)
          .orderBy('isPinned', descending: true)
          .orderBy('updatedAt', descending: true);

      if (gameId != null) {
        query = query.where('gameId', isEqualTo: gameId);
      }

      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }

      final querySnapshot = await query.limit(limit).get();
      debugPrint('Retrieved ${querySnapshot.docs.length} posts from cloud');

      return querySnapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting top level posts from cloud: $e');
      
      // Fallback to simpler query if indexes aren't deployed yet
      try {
        debugPrint('Trying fallback query without isPinned ordering...');
        final querySnapshot = await _firestore
            .collection(_postsCollection)
            .where('parentPostId', isNull: true)
            .orderBy('updatedAt', descending: true)
            .limit(limit)
            .get();
        
        final posts = querySnapshot.docs
            .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        
        // Sort pinned posts to the top manually
        posts.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        return posts;
      } catch (fallbackError) {
        debugPrint('Fallback query also failed: $fallbackError');
        return [];
      }
    }
  }

  // Get real-time stream of top-level posts
  Stream<List<ForumPost>> getTopLevelPostsStream({
    int limit = 20,
    String? gameId,
    List<String>? tags,
  }) {
    try {
      Query query = _firestore
          .collection(_postsCollection)
          .where('parentPostId', isNull: true)
          .orderBy('isPinned', descending: true)
          .orderBy('updatedAt', descending: true);

      if (gameId != null) {
        query = query.where('gameId', isEqualTo: gameId);
      }

      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }

      return query.limit(limit).snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Error creating posts stream: $e');
      // Return fallback stream
      return _firestore
          .collection(_postsCollection)
          .where('parentPostId', isNull: true)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final posts = snapshot.docs
            .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        
        // Sort pinned posts to the top manually
        posts.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        return posts;
      });
    }
  }

  // Get replies for a specific post
  Future<List<ForumPost>> getReplies(String parentPostId, {int limit = 50}) async {
    try {
      debugPrint('Fetching replies from cloud storage for post: $parentPostId');
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .where('parentPostId', isEqualTo: parentPostId)
          .orderBy('createdAt', descending: false) // Oldest first for replies
          .limit(limit)
          .get();

      debugPrint('Retrieved ${querySnapshot.docs.length} replies from cloud');
      return querySnapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting replies from cloud: $e');
      return [];
    }
  }

  // Get real-time stream of replies for a specific post
  Stream<List<ForumPost>> getRepliesStream(String parentPostId, {int limit = 50}) {
    return _firestore
        .collection(_postsCollection)
        .where('parentPostId', isEqualTo: parentPostId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Get real-time stream of a specific post
  Stream<ForumPost?> getPostStream(String postId) {
    return _firestore
        .collection(_postsCollection)
        .doc(postId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ForumPost.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Get a specific post by ID
  Future<ForumPost?> getPost(String postId) async {
    try {
      final doc = await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ForumPost.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting post: $e');
      return null;
    }
  }

  // Get threaded conversation (post + all its replies)
  Future<Map<String, dynamic>> getThreadedConversation(String postId) async {
    try {
      final post = await getPost(postId);
      if (post == null) {
        return {'post': null, 'replies': <ForumPost>[]};
      }

      final replies = await getReplies(postId);
      
      return {
        'post': post,
        'replies': replies,
      };
    } catch (e) {
      debugPrint('Error getting threaded conversation: $e');
      return {'post': null, 'replies': <ForumPost>[]};
    }
  }

  // Like/unlike a post
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postRef = _firestore.collection(_postsCollection).doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }
        
        final data = postDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final likeCount = data['likeCount'] ?? 0;
        
        if (likedBy.contains(userId)) {
          // Unlike
          likedBy.remove(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likeCount': likeCount - 1,
          });
        } else {
          // Like
          likedBy.add(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likeCount': likeCount + 1,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Edit a post
  Future<void> editPost(String postId, String newContent) async {
    try {
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({
        'content': newContent,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'isEdited': true,
      });
    } catch (e) {
      throw Exception('Failed to edit post: $e');
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      final post = await getPost(postId);
      if (post == null) return;

      // If this is a reply, decrement parent's reply count
      if (post.parentPostId != null) {
        await _decrementReplyCount(post.parentPostId!);
      }

      // Delete all replies to this post first
      final replies = await getReplies(postId);
      for (final reply in replies) {
        await _firestore.collection(_postsCollection).doc(reply.id).delete();
      }

      // Delete the post itself
      await _firestore.collection(_postsCollection).doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Search posts
  Future<List<ForumPost>> searchPosts(String query, {int limit = 20}) async {
    try {
      // Note: This is a basic search. For production, consider using Algolia or similar
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .where('parentPostId', isNull: true) // Only search top-level posts
          .orderBy('updatedAt', descending: true)
          .limit(limit * 2) // Get more to filter
          .get();

      final posts = querySnapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .where((post) => 
              post.title.toLowerCase().contains(query.toLowerCase()) ||
              post.content.toLowerCase().contains(query.toLowerCase()) ||
              post.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))
          )
          .take(limit)
          .toList();

      return posts;
    } catch (e) {
      debugPrint('Error searching posts: $e');
      return [];
    }
  }

  // Get posts by user
  Future<List<ForumPost>> getUserPosts(String userId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }

  // Pin/unpin a post (admin function)
  Future<void> togglePin(String postId) async {
    try {
      final postRef = _firestore.collection(_postsCollection).doc(postId);
      final postDoc = await postRef.get();
      
      if (postDoc.exists) {
        final isPinned = postDoc.data()?['isPinned'] ?? false;
        await postRef.update({'isPinned': !isPinned});
      }
    } catch (e) {
      throw Exception('Failed to toggle pin: $e');
    }
  }

  // Lock/unlock a post (admin function)
  Future<void> toggleLock(String postId) async {
    try {
      final postRef = _firestore.collection(_postsCollection).doc(postId);
      final postDoc = await postRef.get();
      
      if (postDoc.exists) {
        final isLocked = postDoc.data()?['isLocked'] ?? false;
        await postRef.update({'isLocked': !isLocked});
      }
    } catch (e) {
      throw Exception('Failed to toggle lock: $e');
    }
  }

  // Helper method to increment reply count
  Future<void> _incrementReplyCount(String postId) async {
    try {
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({
        'replyCount': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error incrementing reply count: $e');
    }
  }

  // Helper method to decrement reply count
  Future<void> _decrementReplyCount(String postId) async {
    try {
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({
        'replyCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error decrementing reply count: $e');
    }
  }

  // Get recent activity (for notifications)
  Future<List<ForumPost>> getRecentActivity({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ForumPost.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent activity: $e');
      return [];
    }
  }

  // Verify cloud storage connection and status
  static Future<Map<String, dynamic>> getCloudStorageStatus() async {
    try {
      debugPrint('Checking cloud storage connection...');
      
      // Test connection by getting a small sample of data
      await _firestore
          .collection(_postsCollection)
          .limit(1)
          .get();

      // Get total document count (approximate)
      final allPosts = await _firestore
          .collection(_postsCollection)
          .get();

      final status = {
        'connected': true,
        'totalPosts': allPosts.docs.length,
        'collection': _postsCollection,
        'database': 'Firebase Firestore',
        'lastChecked': DateTime.now().toIso8601String(),
      };

      debugPrint('Cloud storage status: $status');
      return status;
    } catch (e) {
      debugPrint('Cloud storage connection error: $e');
      return {
        'connected': false,
        'error': e.toString(),
        'collection': _postsCollection,
        'database': 'Firebase Firestore',
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }

  // Backup forum data (for admin use)
  static Future<List<Map<String, dynamic>>> backupAllForumData() async {
    try {
      debugPrint('Creating backup of all forum data from cloud...');
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .get();

      final backupData = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      debugPrint('Backed up ${backupData.length} forum posts from cloud');
      return backupData;
    } catch (e) {
      debugPrint('Error creating forum backup: $e');
      return [];
    }
  }
}