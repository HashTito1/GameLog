import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  none,
  friends,
  requestSent,
  requestReceived,
  self,
}

class FriendsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _friendsCollection = 'friends';
  static const String _friendRequestsCollection = 'friend_requests';
  
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();
  static FriendsService get instance => _instance;

  static Future<FriendshipStatus> getFriendshipStatus(String currentUserId, String targetUserId) async {
    try {
      if (currentUserId == targetUserId) {
        return FriendshipStatus.self;
      }

      // Check if they are friends
      final friendDoc = await _firestore
          .collection(_friendsCollection)
          .doc('${currentUserId}_$targetUserId')
          .get();
      
      final reverseFriendDoc = await _firestore
          .collection(_friendsCollection)
          .doc('${targetUserId}_$currentUserId')
          .get();

      if (friendDoc.exists || reverseFriendDoc.exists) {
        return FriendshipStatus.friends;
      }

      // Check for pending requests
      final sentRequest = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (sentRequest.docs.isNotEmpty) {
        return FriendshipStatus.requestSent;
      }

      final receivedRequest = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: targetUserId)
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        return FriendshipStatus.requestReceived;
      }

      return FriendshipStatus.none;
    } catch (e) {
      debugPrint('Error getting friendship status: $e');
      return FriendshipStatus.none;
    }
  }

  static Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    try {
      // Check if request already exists
      final existingRequest = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request already sent');
      }

      // Create friend request
      await _firestore
          .collection(_friendRequestsCollection)
          .add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      throw Exception('Failed to send friend request: $e');
    }
  }

  static Future<void> acceptFriendRequest(String fromUserId, String toUserId) async {
    try {
      // Find the friend request
      final requestQuery = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestQuery.docs.isEmpty) {
        throw Exception('Friend request not found');
      }

      final requestDoc = requestQuery.docs.first;

      // Create friendship documents
      await _firestore
          .collection(_friendsCollection)
          .doc('${fromUserId}_$toUserId')
          .set({
        'userId1': fromUserId,
        'userId2': toUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection(_friendsCollection)
          .doc('${toUserId}_$fromUserId')
          .set({
        'userId1': toUserId,
        'userId2': fromUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update friend request status
      await requestDoc.reference.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      throw Exception('Failed to accept friend request: $e');
    }
  }

  static Future<void> declineFriendRequest(String fromUserId, String toUserId) async {
    try {
      final requestQuery = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await requestQuery.docs.first.reference.update({
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error declining friend request: $e');
      throw Exception('Failed to decline friend request: $e');
    }
  }

  static Future<void> removeFriend(String userId, String friendId) async {
    try {
      // Remove both friendship documents
      await _firestore
          .collection(_friendsCollection)
          .doc('${userId}_$friendId')
          .delete();

      await _firestore
          .collection(_friendsCollection)
          .doc('${friendId}_$userId')
          .delete();
    } catch (e) {
      debugPrint('Error removing friend: $e');
      throw Exception('Failed to remove friend: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    try {
      final friendsQuery = await _firestore
          .collection(_friendsCollection)
          .where('userId1', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> friends = [];
      for (final doc in friendsQuery.docs) {
        final data = doc.data();
        final friendId = data['userId2'];
        
        // Get friend's profile data
        final friendProfile = await _firestore
            .collection('users')
            .doc(friendId)
            .get();

        if (friendProfile.exists) {
          final friendData = friendProfile.data()!;
          friendData['id'] = friendId;
          friends.add(friendData);
        }
      }

      return friends;
    } catch (e) {
      debugPrint('Error getting friends: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String userId) async {
    try {
      final requestsQuery = await _firestore
          .collection(_friendRequestsCollection)
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];
      for (final doc in requestsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get sender's profile data
        final senderProfile = await _firestore
            .collection('users')
            .doc(data['fromUserId'])
            .get();

        if (senderProfile.exists) {
          final senderData = senderProfile.data()!;
          data['senderProfile'] = senderData;
        }
        
        requests.add(data);
      }

      return requests;
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSentRequests(String userId) async {
    try {
      final requestsQuery = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];
      for (final doc in requestsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get recipient's profile data
        final recipientProfile = await _firestore
            .collection('users')
            .doc(data['toUserId'])
            .get();

        if (recipientProfile.exists) {
          final recipientData = recipientProfile.data()!;
          data['recipientProfile'] = recipientData;
        }
        
        requests.add(data);
      }

      return requests;
    } catch (e) {
      debugPrint('Error getting sent requests: $e');
      return [];
    }
  }

  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    try {
      final requestQuery = await _firestore
          .collection(_friendRequestsCollection)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await requestQuery.docs.first.reference.delete();
      }
    } catch (e) {
      debugPrint('Error canceling friend request: $e');
      throw Exception('Failed to cancel friend request: $e');
    }
  }
}