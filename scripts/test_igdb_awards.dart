import 'dart:convert';
import 'package:http/http.dart' as http;

// Test script to explore IGDB API for award-related endpoints and data
void main() async {
  const String clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  const String accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  const String baseUrl = 'https://api.igdb.com/v4';
  
  final headers = {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  print('🔍 Testing IGDB API for award-related endpoints and data...\n');

  // Test 1: Check if there's an awards endpoint
  print('1. Testing /awards endpoint...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/awards'),
      headers: headers,
      body: 'fields *; limit 5;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Awards endpoint exists!');
      print('Sample data: ${json.encode(data)}');
    } else {
      print('❌ Awards endpoint not found (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Awards endpoint error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 2: Check if there's a game_awards endpoint
  print('2. Testing /game_awards endpoint...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/game_awards'),
      headers: headers,
      body: 'fields *; limit 5;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Game Awards endpoint exists!');
      print('Sample data: ${json.encode(data)}');
    } else {
      print('❌ Game Awards endpoint not found (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Game Awards endpoint error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 3: Check if games have award-related fields
  print('3. Testing games for award-related fields...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: 'fields *; where rating >= 90; limit 3;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Got ${data.length} highly rated games');
      
      if (data.isNotEmpty) {
        final game = data.first;
        print('Sample game fields: ${game.keys.toList()}');
        
        // Check for award-related fields
        final awardFields = game.keys.where((key) => 
          key.toString().toLowerCase().contains('award') ||
          key.toString().toLowerCase().contains('goty') ||
          key.toString().toLowerCase().contains('winner')
        ).toList();
        
        if (awardFields.isNotEmpty) {
          print('🏆 Found award-related fields: $awardFields');
        } else {
          print('❌ No award-related fields found in games');
        }
      }
    } else {
      print('❌ Failed to get games (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Games test error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 4: Search for games with "game of the year" in title or description
  print('4. Searching for GOTY games...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: 'search "game of the year"; fields name,summary,rating; limit 10;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Found ${data.length} games with "game of the year" in search');
      
      for (final game in data) {
        print('- ${game['name']} (Rating: ${game['rating'] ?? 'N/A'})');
      }
    } else {
      print('❌ GOTY search failed (${response.statusCode})');
    }
  } catch (e) {
    print('❌ GOTY search error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 5: Check for themes related to awards
  print('5. Testing themes for award-related content...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/themes'),
      headers: headers,
      body: 'fields *; limit 50;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Got ${data.length} themes');
      
      final awardThemes = data.where((theme) => 
        theme['name'].toString().toLowerCase().contains('award') ||
        theme['name'].toString().toLowerCase().contains('winner') ||
        theme['name'].toString().toLowerCase().contains('goty')
      ).toList();
      
      if (awardThemes.isNotEmpty) {
        print('🏆 Found award-related themes:');
        for (final theme in awardThemes) {
          print('- ${theme['name']} (ID: ${theme['id']})');
        }
      } else {
        print('❌ No award-related themes found');
      }
    } else {
      print('❌ Themes test failed (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Themes test error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 6: Check for collections that might contain GOTY games
  print('6. Testing collections for GOTY content...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/collections'),
      headers: headers,
      body: 'search "game of the year"; fields name,games; limit 10;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Found ${data.length} collections with GOTY in search');
      
      for (final collection in data) {
        print('- ${collection['name']}');
        if (collection['games'] != null) {
          print('  Games count: ${(collection['games'] as List).length}');
        }
      }
    } else {
      print('❌ Collections search failed (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Collections test error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 7: Check if there are any franchise or series related to awards
  print('7. Testing franchises for award content...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/franchises'),
      headers: headers,
      body: 'search "award"; fields name,games; limit 10;',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Found ${data.length} franchises with "award" in search');
      
      for (final franchise in data) {
        print('- ${franchise['name']}');
      }
    } else {
      print('❌ Franchises search failed (${response.statusCode})');
    }
  } catch (e) {
    print('❌ Franchises test error: $e');
  }

  print('\n' + '='*50 + '\n');

  // Test 8: Look for highly rated games from specific years (potential GOTY winners)
  print('8. Testing for potential GOTY winners by year and rating...');
  try {
    // Get top games from 2023 (recent GOTY candidates)
    final year2023Start = DateTime(2023, 1, 1);
    final year2023End = DateTime(2023, 12, 31);
    final timestampStart = (year2023Start.millisecondsSinceEpoch / 1000).round();
    final timestampEnd = (year2023End.millisecondsSinceEpoch / 1000).round();
    
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: headers,
      body: '''
        fields name,rating,first_release_date,summary;
        where first_release_date >= $timestampStart & first_release_date <= $timestampEnd & rating >= 85;
        sort rating desc;
        limit 10;
      ''',
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ Found ${data.length} highly rated games from 2023');
      
      for (final game in data) {
        final releaseDate = game['first_release_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(game['first_release_date'] * 1000)
          : null;
        print('- ${game['name']} (Rating: ${game['rating']?.toStringAsFixed(1) ?? 'N/A'}) - ${releaseDate?.year ?? 'Unknown'}');
      }
    } else {
      print('❌ 2023 games search failed (${response.statusCode})');
    }
  } catch (e) {
    print('❌ 2023 games test error: $e');
  }

  print('\n🏁 Award exploration complete!');
  print('\n📋 Summary:');
  print('- IGDB does not appear to have dedicated award endpoints');
  print('- No specific GOTY filter or field found in games');
  print('- Best approach: Filter by high ratings + recent release dates');
  print('- Alternative: Search for games with award-related keywords');
}