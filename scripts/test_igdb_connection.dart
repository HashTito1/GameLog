import 'dart:io';
import '../lib/services/igdb_service.dart';

/// Simple script to test IGDB API connection
/// Run with: dart run scripts/test_igdb_connection.dart
void main() async {
  print('🎮 Testing IGDB API Connection...\n');
  
  final igdbService = IGDBService.instance;
  
  // Check if credentials are configured
  if (!IGDBService.isConfigured) {
    print('❌ IGDB API credentials not configured!');
    print('Please update lib/services/igdb_service.dart with your Twitch credentials.');
    print('See IGDB_SETUP.md for instructions.\n');
    exit(1);
  }
  
  print('✅ Credentials configured');
  
  try {
    // Test basic connection
    print('🔍 Testing connection...');
    final isConnected = await igdbService.testConnection();
    
    if (!isConnected) {
      print('❌ Connection failed!');
      print('Check your credentials and internet connection.');
      exit(1);
    }
    
    print('✅ Connection successful!');
    
    // Test search functionality
    print('\n🔍 Testing search functionality...');
    final searchResults = await igdbService.searchGames('Hollow Knight', limit: 3);
    
    if (searchResults.isEmpty) {
      print('⚠️  No search results found');
    } else {
      print('✅ Search working! Found ${searchResults.length} games:');
      for (final game in searchResults) {
        print('  - ${game.title} (${game.releaseDate})');
      }
    }
    
    // Test popular games
    print('\n🔥 Testing popular games...');
    final popularGames = await igdbService.getPopularGames(limit: 3);
    
    if (popularGames.isEmpty) {
      print('⚠️  No popular games found');
    } else {
      print('✅ Popular games working! Found ${popularGames.length} games:');
      for (final game in popularGames) {
        print('  - ${game.title} (Rating: ${game.averageRating.toStringAsFixed(1)})');
      }
    }
    
    // Test genres
    print('\n🎯 Testing genres...');
    final genres = await igdbService.getGenres();
    
    if (genres.isEmpty) {
      print('⚠️  No genres found');
    } else {
      print('✅ Genres working! Found ${genres.length} genres:');
      print('  First 10: ${genres.take(10).join(', ')}');
    }
    
    print('\n🎉 All tests passed! IGDB integration is working correctly.');
    
  } catch (e) {
    print('❌ Error during testing: $e');
    print('\nTroubleshooting tips:');
    print('1. Check your internet connection');
    print('2. Verify your Twitch Client ID and Access Token');
    print('3. Make sure your access token hasn\'t expired');
    print('4. Check IGDB_SETUP.md for setup instructions');
    exit(1);
  }
}