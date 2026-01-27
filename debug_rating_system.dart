// Debug script to test rating system
import 'package:flutter/material.dart';
import 'lib/services/user_data_service.dart';
import 'lib/services/rating_service.dart';
import 'lib/services/firebase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Testing Rating System...');
  
  // Test 1: Check if user is authenticated
  final authService = FirebaseAuthService();
  final currentUser = authService.currentUser;
  
  if (currentUser == null) {
    print('❌ No user authenticated. Please log in first.');
    return;
  }
  
  print('✅ User authenticated: ${currentUser.id} (${currentUser.email})');
  
  // Test 2: Try to submit a test rating
  const testGameId = 'test_game_123';
  const testGameTitle = 'Test Game';
  const testRating = 4.5;
  const testReview = 'This is a test review';
  
  try {
    print('📝 Submitting test rating...');
    
    await UserDataService.submitUserRating(
      userId: currentUser.uid,
      gameId: testGameId,
      gameTitle: testGameTitle,
      rating: testRating,
      review: testReview,
    );
    
    print('✅ UserDataService rating submitted successfully');
    
    // Also test old rating service
    await RatingService.instance.submitRating(
      gameId: testGameId,
      userId: currentUser.uid,
      username: currentUser.email?.split('@')[0] ?? 'user',
      rating: testRating,
      review: testReview,
    );
    
    print('✅ RatingService rating submitted successfully');
    
    // Test 3: Try to retrieve the rating
    print('🔍 Retrieving ratings...');
    
    final userRatings = await UserDataService.getUserRatings(currentUser.uid);
    print('📊 User ratings count: ${userRatings.length}');
    
    final testRatingData = userRatings.firstWhere(
      (rating) => rating['gameId'] == testGameId,
      orElse: () => <String, dynamic>{},
    );
    
    if (testRatingData.isNotEmpty) {
      print('✅ Test rating found: $testRatingData');
    } else {
      print('❌ Test rating not found in user ratings');
    }
    
    // Test old rating service retrieval
    final oldRating = await RatingService.instance.getUserRating(currentUser.uid, testGameId);
    if (oldRating != null) {
      print('✅ Old rating service found rating: ${oldRating.rating}');
    } else {
      print('❌ Old rating service did not find rating');
    }
    
    print('🎉 Rating system test completed');
    
  } catch (e) {
    print('❌ Error during rating test: $e');
  }
}