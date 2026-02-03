import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to test simple IGDB queries to understand the data structure
Future<void> main() async {
  print('🎮 Testing simple IGDB queries...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('\n🔍 Testing basic games query...');
  print('=' * 40);
  
  try {
    String basicQuery = '''
      fields name, genres.name;
      limit 10;
      where category = 0;
      sort rating desc;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: basicQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final genres = (game['genres'] as List?)?.map((g) => g['name']).toList() ?? [];
        print('  ${i + 1}. $name - Genres: ${genres.join(', ')}');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('\n🔍 Testing popular games query (like the working one)...');
  print('=' * 40);
  
  try {
    String popularQuery = '''
      fields name, summary, cover.url, first_release_date, rating, rating_count, 
             involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
             genres.name, platforms.name, screenshots.url;
      limit 5;
      where category = 0 & rating >= 70 & rating_count >= 10;
      sort rating desc;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: popularQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} popular games');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name']).toList() ?? [];
        print('  ${i + 1}. $name (Rating: ${rating.toStringAsFixed(1)}) - Genres: ${genres.join(', ')}');
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