import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to test IGDB without any filters
Future<void> main() async {
  print('🎮 Testing IGDB without filters...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('\n🔍 Getting any games without filters...');
  print('=' * 40);
  
  try {
    String query = '''
      fields name, genres.name, rating, category;
      limit 10;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: query,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final category = game['category'] ?? 'Unknown';
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        
        print('  ${i + 1}. $name (Rating: $rating, Category: $category) - ${genres.join(', ')}');
      }
      
    } else {
      print('❌ Error: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('\n🔍 Testing with just category = 0...');
  print('=' * 40);
  
  try {
    String query = '''
      fields name, genres.name, rating;
      limit 5;
      where category = 0;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: query,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games with category = 0');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        
        print('  ${i + 1}. $name (Rating: $rating) - ${genres.join(', ')}');
      }
      
    } else {
      print('❌ Error: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }
  
  exit(0);
}