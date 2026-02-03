import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import 'cache_service.dart';
import 'content_filter_service.dart';

class IGDBService {
  static const String _baseUrl = 'https://api.igdb.com/v4';
  
  // IGDB API credentials - you'll need to get these from Twitch Developer Console
  // Instructions: https://api-docs.igdb.com/#getting-started
  static const String _clientId = 'g02kfdnlja8rywkbbf28o9ckdkta08';
  static const String _accessToken = 'zj6yugrrn92j3ftza3h4z2xx7xsx88';
  
  // Check if API credentials are configured
  static bool get isConfigured => _clientId.isNotEmpty && _accessToken.isNotEmpty && 
                                  _clientId != 'YOUR_TWITCH_CLIENT_ID' && 
                                  _accessToken != 'YOUR_TWITCH_ACCESS_TOKEN';
  
  // Singleton pattern
  static final IGDBService _instance = IGDBService._internal();
  factory IGDBService() => _instance;
  IGDBService._internal();
  static IGDBService get instance => _instance;
  
  static Map<String, String> get _headers => {
    'Client-ID': _clientId,
    'Authorization': 'Bearer $_accessToken',
    'Accept': 'application/json',
    'Content-Type': 'text/plain',
  };

  // Search games with filters and caching
  Future<List<Game>> searchGames(
    String query, {
    int limit = 20,
    List<String>? genres,
    List<String>? platforms,
    String? ordering,
    String? dates,
    double? metacriticMin,
    double? metacriticMax,
  }) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // Create a cache key based on search parameters
      final cacheKey = 'igdb_search_$query${genres?.join(',') ?? ''}_${platforms?.join(',') ?? ''}_${ordering ?? ''}_${metacriticMin ?? 0}_${metacriticMax ?? 100}';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      // Build IGDB query - start with basic structure
      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
      ''';

      // Add search if query is provided
      if (query.isNotEmpty) {
        igdbQuery += 'search "$query"; ';
      }

      // Build where clause components
      List<String> whereConditions = [];

      // Add genre filter
      if (genres != null && genres.isNotEmpty) {
        final genreNames = genres.map((g) => '"$g"').join(',');
        whereConditions.add('genres.name = ($genreNames)');
      }

      // Add platform filter
      if (platforms != null && platforms.isNotEmpty) {
        final platformNames = platforms.map((p) => '"$p"').join(',');
        whereConditions.add('platforms.name = ($platformNames)');
      }

      // Add rating filter (IGDB uses 0-100 scale)
      if (metacriticMin != null && metacriticMax != null) {
        final minRating = (metacriticMin * 10).toInt(); // Convert to IGDB scale
        final maxRating = (metacriticMax * 10).toInt();
        whereConditions.add('rating >= $minRating & rating <= $maxRating');
      }

      // Combine where conditions
      if (whereConditions.isNotEmpty) {
        igdbQuery += 'where ${whereConditions.join(' & ')}; ';
      }

      // Add ordering (only if not using search)
      if (query.isEmpty) {
        if (ordering != null && ordering.isNotEmpty) {
          switch (ordering) {
            case '-rating':
              igdbQuery += 'sort rating desc; ';
              break;
            case 'rating':
              igdbQuery += 'sort rating asc; ';
              break;
            case '-release_date':
              igdbQuery += 'sort first_release_date desc; ';
              break;
            case 'release_date':
              igdbQuery += 'sort first_release_date asc; ';
              break;
            default:
              igdbQuery += 'sort rating desc; ';
          }
        } else {
          igdbQuery += 'sort rating desc; ';
        }
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Filter and deduplicate games for better quality first
        final deduplicatedGames = _filterAndDeduplicateGames(games);
        
        // Enhanced filtering and sorting for better search results
        List<Game> filteredGames = deduplicatedGames;
        
        if (query.isNotEmpty) {
          // Filter and sort by relevance
          filteredGames = deduplicatedGames.where((game) {
            return _isRelevantGame(game, query);
          }).toList();
          
          // Sort by relevance
          filteredGames.sort((a, b) {
            final aRelevance = _calculateRelevanceScore(a, query);
            final bRelevance = _calculateRelevanceScore(b, query);
            return bRelevance.compareTo(aRelevance);
          });
        }
        
        // Take only the most relevant results
        final finalResults = filteredGames.take(limit).toList();
        
        // Cache the search results
        await CacheService.cacheGameList(cacheKey, finalResults);
        
        // Also cache individual games
        for (final game in finalResults.take(10)) {
          await CacheService.cacheGame(game);
        }
        
        return finalResults;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching games: $e');
      }
      rethrow;
    }
  }

  // Get popular games with caching and pagination
  Future<List<Game>> getPopularGames({int limit = 20, int page = 1, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // For page 1, try to get from cache first
      if (page == 1) {
        final currentYear = DateTime.now().year;
        final cacheKey = 'igdb_popular_games_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.length >= limit) {
          return cachedGames.take(limit).toList();
        }
      }

      final offset = (page - 1) * limit;
      
      // Get recent popular games (last 3 years with good ratings)
      final now = DateTime.now();
      final threeYearsAgo = now.subtract(const Duration(days: 1095)); // 3 years
      final timestampThreeYearsAgo = (threeYearsAgo.millisecondsSinceEpoch / 1000).round();
      final timestampNow = (now.millisecondsSinceEpoch / 1000).round();
      
      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
        offset $offset;
        where rating >= 75 & rating_count >= 5 & first_release_date >= $timestampThreeYearsAgo & first_release_date <= $timestampNow;
        sort rating desc;
      ''';

      // Apply content filter
      if (!includeAdultContent) {
        igdbQuery += 'where themes != (42); '; // Exclude adult themes
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Filter and deduplicate games for better quality
        final filteredGames = _filterAndDeduplicateGames(games);
        
        // Cache only the first page for performance
        if (page == 1) {
          final currentYear = DateTime.now().year;
          final cacheKey = 'igdb_popular_games_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
          await CacheService.cacheGameList(cacheKey, filteredGames);
        }
        
        return filteredGames;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching popular games: $e');
      }
      rethrow;
    }
  }

  // Get trending games with caching and pagination
  Future<List<Game>> getTrendingGames({int limit = 20, int page = 1, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // For page 1, try to get from cache first
      if (page == 1) {
        final currentYear = DateTime.now().year;
        final cacheKey = 'igdb_trending_games_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final offset = (page - 1) * limit;
      final now = DateTime.now();
      // Use a much broader timeframe - 2 years for trending games
      final twoYearsAgo = now.subtract(const Duration(days: 730));
      final timestampTwoYearsAgo = (twoYearsAgo.millisecondsSinceEpoch / 1000).round();
      final timestampNow = (now.millisecondsSinceEpoch / 1000).round();
      
      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
        offset $offset;
        where first_release_date >= $timestampTwoYearsAgo & first_release_date <= $timestampNow;
        sort first_release_date desc;
      ''';

      if (kDebugMode) {
        print('🔍 IGDB Trending Query: $igdbQuery');
        print('📅 Date range: ${DateTime.fromMillisecondsSinceEpoch(timestampTwoYearsAgo * 1000)} to ${DateTime.fromMillisecondsSinceEpoch(timestampNow * 1000)}');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          // Try a broader query with just recent games (no rating requirement)
          String fallbackQuery = '''
            fields name, summary, cover.url, first_release_date, rating, rating_count, 
                   involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
                   genres.name, platforms.name, screenshots.url;
            limit $limit;
            offset $offset;
            where first_release_date >= $timestampTwoYearsAgo;
            sort first_release_date desc;
          ''';
          
          final fallbackResponse = await http.post(
            Uri.parse('$_baseUrl/games'),
            headers: _headers,
            body: fallbackQuery,
          );
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackResults = json.decode(fallbackResponse.body) as List<dynamic>;
            if (fallbackResults.isNotEmpty) {
              final games = fallbackResults.map((gameData) => _parseGameFromIGDB(gameData)).toList();
              
              // Filter and deduplicate games for better quality
              final filteredGames = _filterAndDeduplicateGames(games);
              
              // Cache the results only for page 1
              if (page == 1) {
                final currentYear = DateTime.now().year;
                final cacheKey = 'igdb_trending_games_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
                await CacheService.cacheGameList(cacheKey, filteredGames);
              }
              
              // Cache individual games
              for (final game in filteredGames) {
                await CacheService.cacheGame(game);
              }
              
              return await _filterAdultContent(filteredGames, includeAdultContent);
            }
          }
          
          // If still no results, return empty list
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Filter and deduplicate games for better quality
        final filteredGames = _filterAndDeduplicateGames(games);
        
        // Cache the results only for page 1
        if (page == 1) {
          final currentYear = DateTime.now().year;
          final cacheKey = 'igdb_trending_games_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
          await CacheService.cacheGameList(cacheKey, filteredGames);
        }
        
        // Cache individual games
        for (final game in filteredGames) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(filteredGames, includeAdultContent);
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to popular games on error
      return await getPopularGames(limit: limit, page: page, includeAdultContent: includeAdultContent);
    }
  }

  // Get game details by ID with caching
  Future<Game?> getGameDetails(String gameId) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // Try to get from cache first
      final cachedGame = await CacheService.getCachedGame(gameId);
      if (cachedGame != null) {
        return cachedGame;
      }

      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        where id = $gameId;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          return null;
        }
        
        final game = _parseGameFromIGDB(results.first, useHighestQuality: true);
        
        // Cache the game
        await CacheService.cacheGame(game);
        
        return game;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching game details: $e');
      }
      rethrow;
    }
  }

  // Get games by genre with caching and pagination
  Future<List<Game>> getGamesByGenre(String genre, {int limit = 20, int page = 1, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      final currentYear = DateTime.now().year;
      final cacheKey = 'igdb_genre_${genre}_${currentYear}_${includeAdultContent ? 'adult' : 'safe'}';
      
      // For page 1, try to get from cache first
      if (page == 1) {
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final offset = (page - 1) * limit;

      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
        offset $offset;
        where genres.name = "$genre";
        sort rating desc;
      ''';

      if (kDebugMode) {
        print('🔍 IGDB Genre Query for "$genre": $igdbQuery');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          // Try alternative genre names for better compatibility
          String alternativeGenre = genre;
          switch (genre.toLowerCase()) {
            case 'action':
              alternativeGenre = 'Shooter'; // Try Shooter as alternative
              break;
            case 'role-playing (rpg)':
              alternativeGenre = 'RPG'; // Try shorter RPG name
              break;
            case 'indie':
              alternativeGenre = 'Independent'; // Try full name
              break;
          }
          
          if (alternativeGenre != genre) {
            // Try with alternative genre name
            String alternativeQuery = '''
              fields name, summary, cover.url, first_release_date, rating, rating_count, 
                     involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
                     genres.name, platforms.name, screenshots.url;
              limit $limit;
              offset $offset;
              where genres.name = "$alternativeGenre";
              sort rating desc;
            ''';
            
            final alternativeResponse = await http.post(
              Uri.parse('$_baseUrl/games'),
              headers: _headers,
              body: alternativeQuery,
            );
            
            if (alternativeResponse.statusCode == 200) {
              final alternativeResults = json.decode(alternativeResponse.body) as List<dynamic>;
              if (alternativeResults.isNotEmpty) {
                final games = alternativeResults.map((gameData) => _parseGameFromIGDB(gameData)).toList();
                
                // Cache the results only for page 1
                if (page == 1) {
                  await CacheService.cacheGameList(cacheKey, games);
                }
                
                // Cache individual games
                for (final game in games) {
                  await CacheService.cacheGame(game);
                }
                
                return await _filterAdultContent(games, includeAdultContent);
              }
            }
          }
          
          // Try a broader search without rating requirement
          String broadQuery = '''
            fields name, summary, cover.url, first_release_date, rating, rating_count, 
                   involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
                   genres.name, platforms.name, screenshots.url;
            limit $limit;
            offset $offset;
            where genres.name = "$genre";
            sort rating desc;
          ''';
          
          final broadResponse = await http.post(
            Uri.parse('$_baseUrl/games'),
            headers: _headers,
            body: broadQuery,
          );
          
          if (broadResponse.statusCode == 200) {
            final broadResults = json.decode(broadResponse.body) as List<dynamic>;
            if (broadResults.isNotEmpty) {
              final games = broadResults.map((gameData) => _parseGameFromIGDB(gameData)).toList();
              
              // Cache the results only for page 1
              if (page == 1) {
                await CacheService.cacheGameList(cacheKey, games);
              }
              
              // Cache individual games
              for (final game in games) {
                await CacheService.cacheGame(game);
              }
              
              return await _filterAdultContent(games, includeAdultContent);
            }
          }
          
          // Final fallback - return empty list
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Cache the results only for page 1
        if (page == 1) {
          await CacheService.cacheGameList(cacheKey, games);
        }
        
        // Cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(games, includeAdultContent);
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to popular games on error
      return await getPopularGames(limit: limit, page: page, includeAdultContent: includeAdultContent);
    }
  }

  /// Filter adult content based on user preferences
  Future<List<Game>> _filterAdultContent(List<Game> games, bool includeAdultContent) async {
    if (includeAdultContent) {
      return games; // No filtering when adult content is explicitly requested
    }

    final adultContentEnabled = await ContentFilterService.instance.isAdultContentEnabled();
    if (adultContentEnabled) {
      return games; // No filtering when user has enabled adult content
    }

    // Filter out adult content - this is a basic implementation
    return games.where((game) {
      // Basic filtering based on game title and description
      final title = game.title.toLowerCase();
      final description = game.description.toLowerCase();
      
      // Filter out games with explicit adult keywords
      const adultKeywords = [
        'adult',
        'erotic',
        'nsfw',
        'mature',
        'sexual',
        'nude',
        'xxx',
        '18+',
        'hentai',
      ];
      
      for (final keyword in adultKeywords) {
        if (title.contains(keyword) || description.contains(keyword)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  // Get highly rated games from any year with caching and pagination
  Future<List<Game>> getHighlyRatedGames({int limit = 20, int page = 1, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      final currentYear = DateTime.now().year;
      final cacheKey = 'igdb_highly_rated_games_$currentYear';
      
      // For page 1, try to get from cache first
      if (page == 1) {
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final offset = (page - 1) * limit;

      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
        offset $offset;
        where rating >= 70;
        sort rating desc;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          // Try with lower rating threshold
          String fallbackQuery = '''
            fields name, summary, cover.url, first_release_date, rating, rating_count, 
                   involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
                   genres.name, platforms.name, screenshots.url;
            limit $limit;
            offset $offset;
            where rating >= 65;
            sort rating desc;
          ''';
          
          final fallbackResponse = await http.post(
            Uri.parse('$_baseUrl/games'),
            headers: _headers,
            body: fallbackQuery,
          );
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackResults = json.decode(fallbackResponse.body) as List<dynamic>;
            if (fallbackResults.isNotEmpty) {
              final games = fallbackResults
                  .map((gameData) => _parseGameFromIGDB(gameData))
                  .where((game) => game.averageRating >= 3.0) // Only games with 3.0+ rating
                  .take(limit)
                  .toList();
              
              // Cache the results only for page 1
              if (page == 1) {
                await CacheService.cacheGameList(cacheKey, games);
              }
              
              // Cache individual games
              for (final game in games) {
                await CacheService.cacheGame(game);
              }
              
              return await _filterAdultContent(games, includeAdultContent);
            }
          }
          
          // Final fallback - return empty list
          return [];
        }
        
        final games = results
            .map((gameData) => _parseGameFromIGDB(gameData))
            .where((game) => game.averageRating >= 4.0) // Only games with 4.0+ rating
            .take(limit)
            .toList();
        
        // Cache the results only for page 1
        if (page == 1) {
          await CacheService.cacheGameList(cacheKey, games);
        }
        
        // Cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(games, includeAdultContent);
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to popular games on error
      return await getPopularGames(limit: limit, page: page, includeAdultContent: includeAdultContent);
    }
  }

  // Get available genres from IGDB with caching
  Future<List<String>> getGenres() async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // Try to get from cache first
      final cachedGenres = await CacheService.getCachedGenres();
      if (cachedGenres != null && cachedGenres.isNotEmpty) {
        return cachedGenres;
      }

      String igdbQuery = '''
        fields name;
        limit 50;
        sort name asc;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/genres'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        final genres = results.map((genre) => genre['name'] as String).toList();
        
        // Cache the results
        await CacheService.cacheGenres(genres);
        
        return genres;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting genres: $e');
      }
      rethrow;
    }
  }

  // Get available platforms from IGDB with caching
  Future<List<Map<String, dynamic>>> getPlatforms() async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // Try to get from cache first
      final cachedPlatforms = await CacheService.getCachedPlatforms();
      if (cachedPlatforms != null && cachedPlatforms.isNotEmpty) {
        return cachedPlatforms;
      }

      String igdbQuery = '''
        fields name;
        limit 100;
        sort name asc;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/platforms'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        final platforms = results.map((platform) => {
          'id': platform['id'].toString(),
          'name': platform['name'] as String,
        }).toList();
        
        // Cache the results
        await CacheService.cachePlatforms(platforms);
        
        return platforms;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting platforms: $e');
      }
      rethrow;
    }
  }

  // Debug method to log image URLs for troubleshooting
  static void logImageUrl(String gameTitle, String imageUrl) {
    if (kDebugMode) {
      if (imageUrl.isEmpty) {
        debugPrint('⚠️ Empty image URL for game: $gameTitle');
      } else if (!imageUrl.startsWith('https://')) {
        debugPrint('⚠️ Non-HTTPS image URL for $gameTitle: $imageUrl');
      } else {
        debugPrint('✅ Valid image URL for $gameTitle: $imageUrl');
      }
    }
  }

  // Validate image URL and provide fallback
  static String _validateImageUrl(String imageUrl, {bool useHighestQuality = false}) {
    if (imageUrl.isEmpty) return '';
    
    // IGDB images come as //images.igdb.com/... format, need to add https:
    if (imageUrl.startsWith('//')) {
      imageUrl = 'https:$imageUrl';
    }
    
    // Ensure HTTPS
    if (imageUrl.startsWith('http://')) {
      imageUrl = imageUrl.replaceFirst('http://', 'https://');
    }
    
    // Replace image size with higher resolution for better quality
    // IGDB image sizes: t_thumb (90x128), t_cover_small (264x374), t_cover_big (512x725), t_1080p (1920x1080)
    if (imageUrl.contains('/t_thumb/')) {
      imageUrl = imageUrl.replaceAll('/t_thumb/', useHighestQuality ? '/t_1080p/' : '/t_cover_big/');
    } else if (imageUrl.contains('/t_cover_small/')) {
      imageUrl = imageUrl.replaceAll('/t_cover_small/', useHighestQuality ? '/t_1080p/' : '/t_cover_big/');
    } else if (imageUrl.contains('/t_cover_big/') && useHighestQuality) {
      imageUrl = imageUrl.replaceAll('/t_cover_big/', '/t_1080p/');
    }
    
    // For very large displays or detailed views, we could use t_1080p, but t_cover_big is usually sufficient
    
    return imageUrl;
  }

  Game _parseGameFromIGDB(Map<String, dynamic> data, {bool useHighestQuality = false}) {
    // Extract cover image URL with validation
    String coverImage = '';
    if (data['cover'] != null && data['cover']['url'] != null) {
      coverImage = _validateImageUrl(data['cover']['url'], useHighestQuality: useHighestQuality);
    }
    
    String gameTitle = data['name'] ?? 'Unknown Title';
    
    // Extract developers and publishers
    String developer = 'Unknown Developer';
    String publisher = 'Unknown Publisher';
    
    if (data['involved_companies'] != null) {
      final companies = data['involved_companies'] as List;
      for (final companyData in companies) {
        if (companyData['company'] != null && companyData['company']['name'] != null) {
          final companyName = companyData['company']['name'] as String;
          if (companyData['developer'] == true && developer == 'Unknown Developer') {
            developer = companyName;
          }
          if (companyData['publisher'] == true && publisher == 'Unknown Publisher') {
            publisher = companyName;
          }
        }
      }
    }
    
    // If no publisher found, use developer
    if (publisher == 'Unknown Publisher' && developer != 'Unknown Developer') {
      publisher = developer;
    }

    // Extract genres
    List<String> genres = [];
    if (data['genres'] != null) {
      final genresList = data['genres'] as List;
      genres = genresList
          .map((genre) => genre['name'] as String)
          .toList();
    }

    // Extract platforms
    List<String> platforms = [];
    if (data['platforms'] != null) {
      final platformsList = data['platforms'] as List;
      platforms = platformsList
          .map((platform) => platform['name'] as String)
          .toList();
    }

    // Convert release date
    String releaseDate = 'TBA';
    if (data['first_release_date'] != null) {
      try {
        final timestamp = data['first_release_date'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        releaseDate = date.year.toString();
      } catch (e) {
        releaseDate = 'TBA';
      }
    }

    // Convert rating (IGDB uses 0-100 scale, convert to 0-5)
    double averageRating = 0.0;
    if (data['rating'] != null) {
      averageRating = (data['rating'] as num).toDouble() / 20.0; // Convert to 0-5 scale
    }

    // Get review count
    int totalReviews = data['rating_count'] ?? 0;

    return Game(
      id: data['id'].toString(),
      title: gameTitle,
      developer: developer,
      publisher: publisher,
      releaseDate: releaseDate,
      platforms: platforms,
      genres: genres,
      coverImage: coverImage,
      description: data['summary'] ?? '',
      averageRating: averageRating,
      totalReviews: totalReviews,
    );
  }

  // Filter and deduplicate games to improve quality
  List<Game> _filterAndDeduplicateGames(List<Game> games) {
    // Remove games with poor data quality
    final filteredGames = games.where((game) {
      // Skip games with no cover image AND no developer info
      if (game.coverImage.isEmpty && game.developer == 'Unknown Developer') {
        return false;
      }
      
      // Skip games with generic or placeholder titles
      final title = game.title.toLowerCase();
      if (title.contains('untitled') || 
          title.contains('placeholder') || 
          title.contains('test game') ||
          title == 'unknown title') {
        return false;
      }
      
      return true;
    }).toList();
    
    // Deduplicate by title (keep the one with better data)
    final Map<String, Game> uniqueGames = {};
    
    for (final game in filteredGames) {
      final normalizedTitle = game.title.toLowerCase().trim();
      
      if (!uniqueGames.containsKey(normalizedTitle)) {
        uniqueGames[normalizedTitle] = game;
      } else {
        // Keep the game with better data quality
        final existing = uniqueGames[normalizedTitle]!;
        final current = game;
        
        // Scoring system for data quality
        int existingScore = _calculateGameQualityScore(existing);
        int currentScore = _calculateGameQualityScore(current);
        
        if (currentScore > existingScore) {
          uniqueGames[normalizedTitle] = current;
        }
      }
    }
    
    return uniqueGames.values.toList();
  }
  
  // Calculate quality score for a game (higher is better)
  int _calculateGameQualityScore(Game game) {
    int score = 0;
    
    // Has cover image
    if (game.coverImage.isNotEmpty) score += 3;
    
    // Has developer info
    if (game.developer != 'Unknown Developer') score += 2;
    
    // Has rating
    if (game.averageRating > 0) score += 2;
    
    // Has review count
    if (game.totalReviews > 0) score += 1;
    
    // Has genres
    if (game.genres.isNotEmpty) score += 1;
    
    // Has platforms
    if (game.platforms.isNotEmpty) score += 1;
    
    // Has description
    if (game.description.isNotEmpty) score += 1;
    
    // Has release date
    if (game.releaseDate != 'TBA') score += 1;
    
    return score;
  }

  // Test API connection
  Future<bool> testConnection() async {
    if (!isConfigured) {
      return false;
    }
    
    try {
      final games = await searchGames('test', limit: 1);
      return games.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking API availability: $e');
      }
      return false;
    }
  }

  // Advanced search with comprehensive filters and enhanced prioritization
  Future<List<Game>> searchGamesWithFilters({
    required String query,
    String? genre,
    String? platform,
    String? ordering,
    int? metacriticMin,
    int? metacriticMax,
    String? releasedAfter,
    String? releasedBefore,
    int limit = 20,
  }) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      // Create a cache key based on all search parameters
      final cacheKey = 'igdb_advanced_search_${query}_${genre ?? 'all'}_${platform ?? 'all'}_${ordering ?? 'relevance'}_${metacriticMin ?? 0}_${metacriticMax ?? 100}_${releasedAfter ?? ''}_${releasedBefore ?? ''}';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      // Build IGDB query - start with basic structure
      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
      ''';

      // Add search if query is provided
      if (query.isNotEmpty) {
        igdbQuery += 'search "$query"; ';
      }

      // Build where clause components
      List<String> whereConditions = [];

      if (genre != null && genre != 'all') {
        whereConditions.add('genres.name = "$genre"');
      }

      if (platform != null && platform != 'all') {
        whereConditions.add('platforms.name = "$platform"');
      }

      if (metacriticMin != null && metacriticMax != null) {
        if (metacriticMin > 0 || metacriticMax < 100) {
          final minRating = (metacriticMin * 10).toInt(); // Convert to IGDB scale
          final maxRating = (metacriticMax * 10).toInt();
          whereConditions.add('rating >= $minRating & rating <= $maxRating');
        }
      }

      // Combine where conditions
      if (whereConditions.isNotEmpty) {
        igdbQuery += 'where ${whereConditions.join(' & ')}; ';
      }

      // Add ordering (only if not using search)
      if (query.isEmpty) {
        String finalOrdering = ordering ?? 'rating desc';
        igdbQuery += 'sort $finalOrdering; ';
      }

      if (releasedAfter != null && releasedAfter.isNotEmpty) {
        try {
          final afterDate = DateTime.parse('$releasedAfter-01-01');
          final afterTimestamp = (afterDate.millisecondsSinceEpoch / 1000).round();
          
          if (releasedBefore != null && releasedBefore.isNotEmpty) {
            final beforeDate = DateTime.parse('$releasedBefore-12-31');
            final beforeTimestamp = (beforeDate.millisecondsSinceEpoch / 1000).round();
            igdbQuery += 'where first_release_date >= $afterTimestamp & first_release_date <= $beforeTimestamp; ';
          } else {
            igdbQuery += 'where first_release_date >= $afterTimestamp; ';
          }
        } catch (e) {
          // Invalid date format, ignore
        }
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Enhanced filtering and sorting for better search results
        List<Game> filteredGames = games;
        
        if (query.isNotEmpty) {
          // Filter out games that don't match the search query well
          filteredGames = games.where((game) {
            return _isRelevantGame(game, query);
          }).toList();
        }
        
        // Enhanced sorting for better search results
        filteredGames.sort((a, b) {
          // If it's a search query, prioritize title relevance first
          if (query.isNotEmpty) {
            final aRelevance = _calculateRelevanceScore(a, query);
            final bRelevance = _calculateRelevanceScore(b, query);
            if (aRelevance != bRelevance) {
              return bRelevance.compareTo(aRelevance);
            }
          }
          
          // Then sort by rating (popularity)
          final ratingDiff = b.averageRating.compareTo(a.averageRating);
          if (ratingDiff != 0) return ratingDiff;
          
          // Then by release year (recency)
          final yearA = int.tryParse(a.releaseDate) ?? 0;
          final yearB = int.tryParse(b.releaseDate) ?? 0;
          return yearB.compareTo(yearA);
        });
        
        // Take only the most relevant results
        final finalResults = filteredGames.take(limit).toList();
        
        // Cache the search results
        await CacheService.cacheGameList(cacheKey, finalResults);
        
        // Also cache individual games
        for (final game in finalResults.take(10)) {
          await CacheService.cacheGame(game);
        }
        
        return finalResults;
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in advanced search: $e');
      }
      rethrow;
    }
  }

  // Check if a game is relevant to the search query
  bool _isRelevantGame(Game game, String query) {
    final queryWords = query.toLowerCase().split(' ').where((word) => word.isNotEmpty && word.length >= 2).toList();
    final queryLower = query.toLowerCase();
    final titleLower = game.title.toLowerCase();
    final developerLower = game.developer.toLowerCase();
    
    // First priority: exact phrase match
    if (titleLower.contains(queryLower)) {
      return true;
    }
    
    // Second priority: exact phrase match without punctuation
    final cleanTitle = titleLower.replaceAll(RegExp(r'[^\w\s]'), '');
    final cleanQuery = queryLower.replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanTitle.contains(cleanQuery)) {
      return true;
    }
    
    // For single word searches, be more lenient
    if (queryWords.length == 1) {
      return titleLower.contains(queryLower) || 
             developerLower.contains(queryLower) ||
             game.genres.any((genre) => genre.toLowerCase().contains(queryLower));
    }
    
    // For multi-word searches, be stricter - require ALL words to be present
    int totalWordMatches = 0;
    
    for (final word in queryWords) {
      if (titleLower.contains(word) || 
          developerLower.contains(word) ||
          game.genres.any((genre) => genre.toLowerCase().contains(word))) {
        totalWordMatches++;
      }
    }
    
    // For multi-word searches, require ALL words to match somewhere
    return totalWordMatches == queryWords.length;
  }

  // Get potential Game of the Year winners by year and rating
  Future<List<Game>> getGOTYCandidates({int? year, int limit = 20, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      final targetYear = year ?? DateTime.now().year - 1; // Default to last year
      final cacheKey = 'igdb_goty_candidates_$targetYear';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      // Calculate year timestamps
      final yearStart = DateTime(targetYear, 1, 1);
      final yearEnd = DateTime(targetYear, 12, 31);
      final timestampStart = (yearStart.millisecondsSinceEpoch / 1000).round();
      final timestampEnd = (yearEnd.millisecondsSinceEpoch / 1000).round();
      
      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        limit $limit;
        where first_release_date >= $timestampStart & first_release_date <= $timestampEnd & rating >= 85 & rating_count >= 10;
        sort rating desc;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Filter and deduplicate games for better quality
        final filteredGames = _filterAndDeduplicateGames(games);
        
        // Cache the results
        await CacheService.cacheGameList(cacheKey, filteredGames);
        
        // Cache individual games
        for (final game in filteredGames) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(filteredGames, includeAdultContent);
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching GOTY candidates: $e');
      }
      // Fallback to highly rated games
      return await getHighlyRatedGames(limit: limit, includeAdultContent: includeAdultContent);
    }
  }

  // Get Game of the Year Edition games (games with GOTY in title)
  Future<List<Game>> getGOTYEditions({int limit = 20, bool includeAdultContent = false}) async {
    if (!isConfigured) {
      throw Exception('IGDB API credentials not configured. Please set your Twitch Client ID and Access Token.');
    }

    try {
      final cacheKey = 'igdb_goty_editions';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      String igdbQuery = '''
        fields name, summary, cover.url, first_release_date, rating, rating_count, 
               involved_companies.company.name, involved_companies.developer, involved_companies.publisher,
               genres.name, platforms.name, screenshots.url;
        search "Game of the Year Edition";
        limit $limit;
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: _headers,
        body: igdbQuery,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        final games = results.map((gameData) => _parseGameFromIGDB(gameData)).toList();
        
        // Filter for actual GOTY editions (not joke games)
        final gotyGames = games.where((game) {
          final title = game.title.toLowerCase();
          return title.contains('game of the year') && 
                 !title.contains('420') && 
                 !title.contains('wacky') &&
                 game.averageRating > 0;
        }).toList();
        
        // Sort by rating
        gotyGames.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        
        // Cache the results
        await CacheService.cacheGameList(cacheKey, gotyGames);
        
        // Cache individual games
        for (final game in gotyGames) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(gotyGames, includeAdultContent);
      } else {
        throw Exception('IGDB API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching GOTY editions: $e');
      }
      return [];
    }
  }

  // Calculate relevance score for search results
  int _calculateRelevanceScore(Game game, String query) {
    final queryLower = query.toLowerCase().trim();
    final titleLower = game.title.toLowerCase();
    final developerLower = game.developer.toLowerCase();
    
    int score = 0;
    
    // Handle multi-word queries
    final queryWords = queryLower.split(' ').where((word) => word.isNotEmpty).toList();
    
    // HIGHEST PRIORITY: Exact full phrase match
    if (titleLower == queryLower) {
      score += 10000; // Massive boost for exact title match
    }
    // VERY HIGH PRIORITY: Title contains the exact phrase
    else if (titleLower.contains(queryLower)) {
      score += 8000; // Very high score for exact phrase in title
    }
    // HIGH PRIORITY: Title starts with the exact phrase
    else if (titleLower.startsWith(queryLower)) {
      score += 7000;
    }
    // MEDIUM-HIGH PRIORITY: Remove punctuation and check again
    else {
      final cleanTitle = titleLower.replaceAll(RegExp(r'[^\w\s]'), '');
      final cleanQuery = queryLower.replaceAll(RegExp(r'[^\w\s]'), '');
      if (cleanTitle.contains(cleanQuery)) {
        score += 6000;
      }
    }
    
    // Multi-word scoring (only if no exact phrase match found)
    if (score < 6000 && queryWords.length > 1) {
      int wordMatches = 0;
      int wordScore = 0;
      int titleWordMatches = 0; // Count matches specifically in title
      
      for (final word in queryWords) {
        if (word.length < 2) continue; // Skip very short words
        
        if (titleLower.contains(word)) {
          wordMatches++;
          titleWordMatches++;
          
          // Higher score for longer words
          if (word.length >= 5) {
            wordScore += 300;
          } else if (word.length >= 4) {
            wordScore += 200;
          } else {
            wordScore += 100;
          }
          
          // Bonus if word appears at start of title or after space
          if (titleLower.startsWith(word) || titleLower.contains(' $word')) {
            wordScore += 150;
          }
        } else if (developerLower.contains(word)) {
          wordMatches++;
          wordScore += 50; // Less points for developer matches
        }
      }
      
      // CRITICAL: Heavy bonus for matching ALL words in title
      if (titleWordMatches == queryWords.length) {
        score += wordScore * 4; // Quadruple the score if all words match in title
      } else if (wordMatches == queryWords.length) {
        score += wordScore * 2; // Double if all words match somewhere
      } else {
        score += wordScore;
      }
      
      // CRITICAL: Heavy penalty for missing words in multi-word search
      final missingWords = queryWords.length - wordMatches;
      score -= missingWords * 1000; // Very heavy penalty for missing words
      
    } else if (queryWords.length == 1) {
      // Single word scoring
      final singleWord = queryWords.isNotEmpty ? queryWords.first : queryLower;
      
      if (titleLower.startsWith(singleWord)) {
        score += 3000;
      } else if (titleLower.contains(' $singleWord')) {
        score += 2000;
      } else if (titleLower.contains(singleWord)) {
        score += 1500;
      }
    }
    
    // Developer scoring (much less important)
    if (developerLower == queryLower) {
      score += 200;
    } else if (developerLower.contains(queryLower)) {
      score += 100;
    }
    
    // Genre matching (least important)
    for (final genre in game.genres) {
      final genreLower = genre.toLowerCase();
      if (genreLower == queryLower) {
        score += 150;
        break;
      } else if (genreLower.contains(queryLower)) {
        score += 75;
        break;
      }
    }
    
    // Boost score based on rating (but much less important than relevance)
    score += (game.averageRating * 2).round();
    
    // Boost score for games with more reviews (popularity indicator)
    if (game.totalReviews > 1000) {
      score += 10;
    } else if (game.totalReviews > 100) {
      score += 5;
    }
    
    // Slight boost for recent games
    final year = int.tryParse(game.releaseDate) ?? 0;
    final currentYear = DateTime.now().year;
    if (year >= currentYear - 2) {
      score += 5;
    }
    
    return score;
  }
}