import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to check what genres are actually used in IGDB games
Future<void> main() async {
  print('🎮 Checking actual genres used in IGDB games...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  final clientId = Platform.environment['IGDB_CLIENT_ID'] ?? '';
  final accessToken = Platform.environment['IGDB_ACCESS_TOKEN'] ?? '';
  if (clientId.isEmpty || accessToken.isEmpty) {
    print('Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN environment variables first.');
    exit(1);
  }
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('\n🔍 Getting games with genres...');
  print('=' * 40);
  
  try {
    // Get games that have high ratings (like our popular games query)
    String query = '''
      fields name, genres.name, rating;
      limit 20;
      where category = 0 & rating >= 70 & rating_count >= 10;
      sort rating desc;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: query,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} games with genres');
      
      Set<String> allGenres = {};
      
      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final rating = game['rating'] ?? 0;
        final genres = (game['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [];
        
        allGenres.addAll(genres);
        
        print('  ${i + 1}. $name (${rating.toStringAsFixed(1)}) - ${genres.join(', ')}');
      }
      
      print('\n📋 All unique genres found:');
      print('=' * 40);
      final sortedGenres = allGenres.toList()..sort();
      for (final genre in sortedGenres) {
        print('• $genre');
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