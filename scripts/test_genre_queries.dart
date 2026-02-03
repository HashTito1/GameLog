import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to test IGDB genre queries with the exact genre names we're using
Future<void> main() async {
  print('🎮 Testing IGDB genre queries...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  // Test the genres we're using in the app
  final genresToTest = [
    'Shooter',
    'Role-playing (RPG)',
    'Indie',
    'Adventure',
    'Strategy',
  ];

  for (final genre in genresToTest) {
    print('\n🔍 Testing genre: $genre');
    print('=' * 40);
    
    try {
      String query = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit 5;
        where category = 0 & genres.name = "$genre";
        sort rating desc;
      ''';

      final response = await http.post(
        Uri.parse('$baseUrl/games'),
        headers: headers,
        body: query,
      );

      if (response.statusCode == 200) {
        final List<dynamic> games = json.decode(response.body);
        print('✅ Found ${games.length} games for "$genre"');
        
        for (int i = 0; i < games.length && i < 3; i++) {
          final game = games[i];
          final name = game['name'] ?? 'Unknown';
          final rating = game['rating'] ?? 0;
          final genres = (game['genres'] as List?)?.map((g) => g['name']).join(', ') ?? 'No genres';
          print('  ${i + 1}. $name (Rating: ${rating.toStringAsFixed(1)}) - Genres: $genres');
        }
      } else {
        print('❌ Error for "$genre": ${response.statusCode}');
        print('   Response: ${response.body}');
      }
      
    } catch (e) {
      print('❌ Exception for "$genre": $e');
    }
    
    // Small delay between requests
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  print('\n🎯 Testing trending games query...');
  print('=' * 40);
  
  try {
    final now = DateTime.now();
    final twoYearsAgo = now.subtract(const Duration(days: 730));
    final timestampTwoYearsAgo = (twoYearsAgo.millisecondsSinceEpoch / 1000).round();
    final timestampNow = (now.millisecondsSinceEpoch / 1000).round();
    
    String trendingQuery = '''
      fields name, summary, cover.url, first_release_date, rating, rating_count, 
             involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
             genres.name, platforms.name, screenshots.url;
      limit 5;
      where category = 0 & first_release_date >= $timestampTwoYearsAgo & first_release_date <= $timestampNow;
      sort first_release_date desc;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: trendingQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ Found ${games.length} trending games');
      
      for (int i = 0; i < games.length && i < 3; i++) {
        final game = games[i];
        final name = game['name'] ?? 'Unknown';
        final releaseDate = game['first_release_date'];
        final dateStr = releaseDate != null 
            ? DateTime.fromMillisecondsSinceEpoch(releaseDate * 1000).toString().split(' ')[0]
            : 'Unknown';
        print('  ${i + 1}. $name (Released: $dateStr)');
      }
    } else {
      print('❌ Error for trending games: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Exception for trending games: $e');
  }
  
  exit(0);
}