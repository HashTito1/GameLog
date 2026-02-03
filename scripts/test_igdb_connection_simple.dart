import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to test IGDB API connection and credentials
Future<void> main() async {
  print('🎮 Testing IGDB API connection...');
  
  const String baseUrl = 'https://api.igdb.com/v4';
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('\n🔍 Testing API credentials...');
  print('Client ID: $clientId');
  print('Access Token: ${accessToken.substring(0, 10)}...');
  
  try {
    // Test with the simplest possible query
    String simpleQuery = '''
      fields name;
      limit 1;
    ''';

    print('\n📡 Making request to: $baseUrl/games');
    print('Query: $simpleQuery');
    
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: simpleQuery,
    );

    print('\n📊 Response Status: ${response.statusCode}');
    print('📊 Response Headers: ${response.headers}');
    print('📊 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      print('✅ API is working! Found ${games.length} games');
    } else if (response.statusCode == 401) {
      print('❌ Authentication failed - credentials may be expired');
    } else if (response.statusCode == 429) {
      print('❌ Rate limit exceeded');
    } else {
      print('❌ API error: ${response.statusCode}');
    }
    
  } catch (e) {
    print('❌ Exception: $e');
  }
  
  exit(0);
}