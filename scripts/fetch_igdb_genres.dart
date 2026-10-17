// Command-line helper: printing to stdout is the point.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to fetch available genres from IGDB API
/// This will help us understand what genres are available and their exact names
Future<void> main() async {
  print('🎮 Fetching IGDB genres...');
  
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

  try {
    // Fetch all genres
    String genreQuery = '''
      fields name, slug;
      limit 50;
      sort name asc;
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/genres'),
      headers: headers,
      body: genreQuery,
    );

    if (response.statusCode == 200) {
      final List<dynamic> genres = json.decode(response.body);
      
      print('\n📋 Available IGDB Genres (${genres.length} total):');
      print('=' * 50);
      
      for (final genre in genres) {
        final name = genre['name'] ?? 'Unknown';
        final slug = genre['slug'] ?? 'unknown';
        final id = genre['id'] ?? 0;
        print('• $name (ID: $id, Slug: $slug)');
      }
      
      print('\n🎯 Recommended categories for homepage:');
      print('=' * 50);
      
      // Filter for popular/common genres that would work well as homepage categories
      final popularGenres = genres.where((genre) {
        final name = (genre['name'] as String).toLowerCase();
        return [
          'action',
          'adventure', 
          'role-playing',
          'strategy',
          'shooter',
          'indie',
          'puzzle',
          'racing',
          'sport',
          'fighting',
          'platform',
          'simulation'
        ].any((popular) => name.contains(popular));
      }).toList();
      
      for (final genre in popularGenres) {
        final name = genre['name'] ?? 'Unknown';
        final id = genre['id'] ?? 0;
        print('✅ $name (ID: $id)');
      }
      
      print('\n💡 Suggested homepage categories:');
      print('=' * 50);
      final suggestions = popularGenres.take(6).map((g) => g['name']).toList();
      for (int i = 0; i < suggestions.length; i++) {
        print('${i + 1}. ${suggestions[i]}');
      }
      
    } else {
      print('❌ Error fetching genres: ${response.statusCode}');
      print('Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
  
  exit(0);
}