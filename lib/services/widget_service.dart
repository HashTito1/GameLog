import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_service.dart';
import 'firebase_auth_service.dart';
import 'igdb_service.dart';

class WidgetService {
  static const String _widgetName = 'FriendReviewsWidget';
  static StreamSubscription? _reviewsSubscription;
  
  /// Update the widget with latest friend reviews
  static Future<void> updateWidget() async {
    try {
      debugPrint('🔄 Updating widget...');
      
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No user logged in, clearing widget');
        await _clearWidget();
        return;
      }

      // Get recent friend reviews
      final reviews = await RatingService.getFriendRecentRatings(
        currentUser.uid,
        limit: 5, // Show top 5 reviews in widget
      );

      debugPrint('📊 Got ${reviews.length} reviews for widget');

      if (reviews.isEmpty) {
        await _setNoReviewsState();
        return;
      }

      // Prepare data for widget with game cover images
      final reviewsData = <Map<String, dynamic>>[];
      
      for (var review in reviews) {
        String coverUrl = '';
        try {
          final game = await IGDBService.instance.getGameDetails(review.gameId);
          coverUrl = game?.coverImage ?? '';
        } catch (e) {
          debugPrint('Error fetching game cover: $e');
        }
        
        reviewsData.add({
          'username': review.displayName ?? review.username,
          'gameTitle': review.gameTitle ?? 'Unknown Game',
          'rating': review.rating,
          'likeCount': review.likeCount,
          'review': review.review ?? '',
          'gameId': review.gameId,
          'coverUrl': coverUrl,
          'profileImage': review.profileImage ?? '',
        });
      }

      // Save data to widget
      await HomeWidget.saveWidgetData<String>(
        'reviews_data',
        jsonEncode(reviewsData),
      );
      
      await HomeWidget.saveWidgetData<int>(
        'reviews_count',
        reviews.length,
      );
      
      await HomeWidget.saveWidgetData<String>('state', 'has_reviews');

      // Update widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
      );

      debugPrint('✅ Widget updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating widget: $e');
    }
  }

  /// Start listening to real-time review updates
  static Future<void> startRealtimeUpdates() async {
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) return;

      debugPrint('🔴 Starting real-time widget updates...');

      // Cancel existing subscription
      await _reviewsSubscription?.cancel();

      // Listen to ratings collection for changes
      _reviewsSubscription = FirebaseFirestore.instance
          .collection('ratings')
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        debugPrint('🔔 Reviews updated, refreshing widget...');
        updateWidget();
      });
    } catch (e) {
      debugPrint('❌ Error starting real-time updates: $e');
    }
  }

  /// Stop real-time updates
  static Future<void> stopRealtimeUpdates() async {
    await _reviewsSubscription?.cancel();
    _reviewsSubscription = null;
    debugPrint('⏹️ Stopped real-time widget updates');
  }

  /// Clear widget data
  static Future<void> _clearWidget() async {
    await HomeWidget.saveWidgetData<String>('reviews_data', '[]');
    await HomeWidget.saveWidgetData<int>('reviews_count', 0);
    await HomeWidget.saveWidgetData<String>('state', 'no_user');
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _widgetName,
    );
  }

  /// Set no reviews state
  static Future<void> _setNoReviewsState() async {
    await HomeWidget.saveWidgetData<String>('reviews_data', '[]');
    await HomeWidget.saveWidgetData<int>('reviews_count', 0);
    await HomeWidget.saveWidgetData<String>('state', 'no_reviews');
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _widgetName,
    );
  }

  /// Initialize widget (call on app start)
  static Future<void> initialize() async {
    try {
      debugPrint('🔧 Initializing widget service...');
      
      // Set up widget click handler
      HomeWidget.setAppGroupId('group.gamelog');
      
      // Register callback for widget interactions
      HomeWidget.registerInteractivityCallback(backgroundCallback);
      
      // Initial update
      await updateWidget();
      
      // Start real-time updates
      await startRealtimeUpdates();
      
      debugPrint('✅ Widget service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing widget: $e');
    }
  }

  /// Background callback for widget interactions
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    debugPrint('📱 Widget clicked: $uri');
    
    if (uri != null) {
      // Handle widget click - could open specific game or reviews
      final gameId = uri.queryParameters['gameId'];
      if (gameId != null) {
        debugPrint('🎮 Opening game: $gameId');
        // The app will handle this when it opens
      }
    }
  }
}
