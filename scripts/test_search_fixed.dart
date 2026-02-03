import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to test the fixed search functionality
Future<void> main() async {
  print('🎮 Testing fixed IGDB search...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('\n🔍 Testing basic search for "mario"...');
  print('=' * 40);
  
  try {
    String searchQuery = '''
      fields name, summary, cover.url, first_release_date, rating, rating_count, 
             involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
             genres.name, platforms.name, screenshots.url;
      limit 5;
      search "mario";
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: searchQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games for "mario"');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        print('  ${i + 1}. $name (Rating: ${rating.toStringAsFixed(1)}) - ${genres.join(', ')}');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('\n🔍 Testing search with genre filter for "zelda" + "Adventure"...');
  print('=' * 40);
  
  try {
    String genreSearchQuery = '''
      fields name, summary, cover.url, first_release_date, rating, rating_count, 
             involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
             genres.name, platforms.name, screenshots.url;
      limit 5;
      search "zelda";
      where genres.name = "Adventure";
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: genreSearchQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games for "zelda" with Adventure genre');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        print('  ${i + 1}. $name (Rating: ${rating.toStringAsFixed(1)}) - ${genres.join(', ')}');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('\n🔍 Testing simple search without filters...');
  print('=' * 40);
  
  try {
    String simpleQuery = '''
      fields name, genres.name, rating;
      limit 5;
      search "pokemon";
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: simpleQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games for "pokemon"');
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        print('  ${i + 1}. $name (Rating: ${rating.toStringAsFixed(1)}) - ${genres.join(', ')}');
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