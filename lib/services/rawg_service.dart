import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import 'cache_service.dart';
import 'content_filter_service.dart';

class RAWGService {
  static const String _baseUrl = 'https://api.rawg.io/api';
  // RAWG API key for game data
  static const String _apiKey = '4158ece2bc984544b698665ed3052464';
  
  // Check if API key is configured
  static bool get isConfigured => _apiKey.isNotEmpty;
  
  // Singleton pattern
  static final RAWGService _instance = RAWGService._internal();
  factory RAWGService() => _instance;
  RAWGService._internal();
  static RAWGService get instance => _instance;
  
  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // Create a cache key based on search parameters
      final cacheKey = 'search_$query${genres?.join(',') ?? ''}_${platforms?.join(',') ?? ''}_${ordering ?? ''}_${metacriticMin ?? 0}_${metacriticMax ?? 100}';
      
      // Try to get from cache first (shorter cache time for searches)
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      final queryParams = <String, String>{
        'key': _apiKey,
        'page_size': '40', // Fetch more to filter better results
        'search_precise': 'true', // More precise search
      };

      if (query.isNotEmpty) {
        queryParams['search'] = query;
      }

      if (genres != null && genres.isNotEmpty) {
        queryParams['genres'] = genres.join(',');
      }

      if (platforms != null && platforms.isNotEmpty) {
        queryParams['platforms'] = platforms.join(',');
      }

      if (ordering != null && ordering.isNotEmpty) {
        queryParams['ordering'] = ordering;
      } else {
        // Default to relevance for search queries
        queryParams['ordering'] = query.isNotEmpty ? '-relevance' : '-rating';
      }

      if (dates != null && dates.isNotEmpty) {
        queryParams['dates'] = dates;
      }

      if (metacriticMin != null) {
        queryParams['metacritic'] = '${metacriticMin.toInt()},${metacriticMax?.toInt() ?? 100}';
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Enhanced filtering and sorting for better search results
        List<Game> filteredGames = games;
        
        if (query.isNotEmpty) {
          // Filter out games that don't match the search query well
          final queryWords = query.toLowerCase().split(' ').where((word) => word.isNotEmpty && word.length >= 2).toList();
          final queryLower = query.toLowerCase();
          
          filteredGames = games.where((game) {
            final titleLower = game.title.toLowerCase();
            final developerLower = game.developer.toLowerCase();
            
            // First priority: exact phrase match (highest priority for multi-word searches like "Hollow Knight")
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
            
            // For multi-word searches, be much stricter - require ALL words to be present
            int titleWordMatches = 0;
            int totalWordMatches = 0;
            
            for (final word in queryWords) {
              if (titleLower.contains(word)) {
                titleWordMatches++;
                totalWordMatches++;
              } else if (developerLower.contains(word) ||
                        game.genres.any((genre) => genre.toLowerCase().contains(word))) {
                totalWordMatches++;
              }
            }
            
            // For multi-word searches, require ALL words to match somewhere
            // But heavily prefer games where all words match in the title
            if (queryWords.length >= 2) {
              // If all words match in title, definitely include
              if (titleWordMatches == queryWords.length) {
                return true;
              }
              // If all words match somewhere (title, developer, or genre), include
              if (totalWordMatches == queryWords.length) {
                return true;
              }
              // Otherwise, exclude to avoid irrelevant results
              return false;
            }
            
            return false;
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
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // For page 1, try to get from cache first
      if (page == 1) {
        final cacheKey = 'popular_games_${includeAdultContent ? 'adult' : 'safe'}';
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.length >= limit) {
          return cachedGames.take(limit).toList();
        }
      }

      final queryParams = <String, String>{
        'key': _apiKey,
        'page_size': limit.toString(),
        'page': page.toString(),
        'ordering': '-rating,-metacritic,-added', // Multiple ordering criteria for better results
        'metacritic': '70,100', // Only high-rated games for better performance
      };

      // Apply content filter
      if (!includeAdultContent) {
        queryParams['tags'] = '!adult'; // Exclude adult content
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache only the first page for performance
        if (page == 1) {
          final cacheKey = 'popular_games_${includeAdultContent ? 'adult' : 'safe'}';
          await CacheService.cacheGameList(cacheKey, games);
        }
        
        return games;
      } else {
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // For page 1, try to get from cache first
      if (page == 1) {
        final cachedGames = await CacheService.getCachedGameList(CacheService.trendingGamesKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      final dateString = '${oneMonthAgo.year}-${oneMonthAgo.month.toString().padLeft(2, '0')}-${oneMonthAgo.day.toString().padLeft(2, '0')}';
      
      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'dates': '$dateString,${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'ordering': '-added',
        'page_size': limit.toString(),
        'page': page.toString(),
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the results only for page 1
        if (page == 1) {
          await CacheService.cacheGameList(CacheService.trendingGamesKey, games);
        }
        
        // Cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return await _filterAdultContent(games, includeAdultContent);
      } else {
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting trending games: $e');
      }
      rethrow;
    }
  }

  // Get game details by ID with caching
  Future<Game?> getGameDetails(String gameId) async {
    if (!isConfigured) {
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // Try to get from cache first
      final cachedGame = await CacheService.getCachedGame(gameId);
      if (cachedGame != null) {
        return cachedGame;
      }

      final uri = Uri.parse('$_baseUrl/games/$gameId').replace(queryParameters: {
        'key': _apiKey,
      });

      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final game = _parseGameFromRAWG(data);
        
        // Cache the game
        await CacheService.cacheGame(game);
        
        return game;
      } else {
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      final cacheKey = 'genre_$genre';
      
      // For page 1, try to get from cache first
      if (page == 1) {
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'genres': genre.toLowerCase(),
        'ordering': '-rating',
        'page_size': limit.toString(),
        'page': page.toString(),
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
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
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting games by genre: $e');
      }
      rethrow;
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
    // In a real app, you'd have more sophisticated content rating data
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      final cacheKey = 'highly_rated_games';
      
      // For page 1, try to get from cache first
      if (page == 1) {
        final cachedGames = await CacheService.getCachedGameList(cacheKey);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          final filteredGames = await _filterAdultContent(cachedGames, includeAdultContent);
          return filteredGames.take(limit).toList();
        }
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'ordering': '-rating,-metacritic,-added', // Order by rating first, then metacritic, then popularity
        'metacritic': '80,100', // Only games with metacritic score 80+
        'page_size': (limit * 2).toString(), // Get more to filter by rating
        'page': page.toString(),
        'dates': '1980-01-01,${DateTime.now().year}-12-31', // Any year from 1980 to current
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results
            .map((gameData) => _parseGameFromRAWG(gameData))
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
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting highly rated games: $e');
      }
      rethrow;
    }
  }

  // Get available genres from RAWG with caching
  Future<List<String>> getGenres() async {
    if (!isConfigured) {
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // Try to get from cache first
      final cachedGenres = await CacheService.getCachedGenres();
      if (cachedGenres != null && cachedGenres.isNotEmpty) {
        return cachedGenres;
      }

      final uri = Uri.parse('$_baseUrl/genres').replace(queryParameters: {
        'key': _apiKey,
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final genres = results.map((genre) => genre['name'] as String).toList();
        
        // Cache the results
        await CacheService.cacheGenres(genres);
        
        return genres;
      } else {
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting genres: $e');
      }
      rethrow;
    }
  }

  // Get available platforms from RAWG with caching
  Future<List<Map<String, dynamic>>> getPlatforms() async {
    if (!isConfigured) {
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // Try to get from cache first
      final cachedPlatforms = await CacheService.getCachedPlatforms();
      if (cachedPlatforms != null && cachedPlatforms.isNotEmpty) {
        return cachedPlatforms;
      }

      final uri = Uri.parse('$_baseUrl/platforms').replace(queryParameters: {
        'key': _apiKey,
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final platforms = results.map((platform) => {
          'id': platform['id'].toString(),
          'name': platform['name'] as String,
        }).toList();
        
        // Cache the results
        await CacheService.cachePlatforms(platforms);
        
        return platforms;
      } else {
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
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
  static String _validateImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // Ensure HTTPS
    if (imageUrl.startsWith('http://')) {
      imageUrl = imageUrl.replaceFirst('http://', 'https://');
    }
    
    // Check for common broken image indicators
    if (imageUrl.contains('placeholder') || 
        imageUrl.contains('default') ||
        imageUrl.contains('noimage')) {
      return '';
    }
    
    return imageUrl;
  }

  Game _parseGameFromRAWG(Map<String, dynamic> data) {
    // Extract cover image URL with validation
    String coverImage = _validateImageUrl(data['background_image'] ?? '');
    String gameTitle = data['name'] ?? 'Unknown Title';
    
    // Log image URL for debugging
    logImageUrl(gameTitle, coverImage);
    
    // Extract developers
    List<dynamic> developers = data['developers'] ?? [];
    String developer = developers.isNotEmpty 
        ? developers.first['name'] ?? 'Unknown Developer'
        : 'Unknown Developer';
    
    // Extract publishers
    List<dynamic> publishers = data['publishers'] ?? [];
    String publisher = publishers.isNotEmpty 
        ? publishers.first['name'] ?? developer
        : developer;

    // Extract genres
    List<dynamic> genresList = data['genres'] ?? [];
    List<String> genres = genresList
        .map((genre) => genre['name'] as String)
        .toList();

    // Extract platforms
    List<dynamic> platformsList = data['platforms'] ?? [];
    List<String> platforms = platformsList
        .map((platform) => platform['platform']['name'] as String)
        .toList();

    // Convert release date
    String releaseDate = 'TBA';
    if (data['released'] != null) {
      try {
        final date = DateTime.parse(data['released']);
        releaseDate = date.year.toString();
      } catch (e) {
        releaseDate = data['released'].toString().split('-').first;
        // Error handled
      }
    }

    // Convert rating (RAWG uses 0-5 scale)
    double averageRating = 0.0;
    if (data['rating'] != null) {
      averageRating = (data['rating'] as num).toDouble();
    }

    // Get review count
    int totalReviews = data['reviews_count'] ?? 0;

    return Game(
      id: data['id'].toString(),
      title: gameTitle,
      developer: developer,
      publisher: publisher,
      releaseDate: releaseDate,
      platforms: platforms,
      genres: genres,
      coverImage: coverImage,
      description: data['description_raw'] ?? data['description'] ?? '',
      averageRating: averageRating,
      totalReviews: totalReviews,
    );
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
      throw Exception('RAWG API key not configured. Please set RAWG_API_KEY environment variable.');
    }

    try {
      // Create a cache key based on all search parameters
      final cacheKey = 'advanced_search_${query}_${genre ?? 'all'}_${platform ?? 'all'}_${ordering ?? 'relevance'}_${metacriticMin ?? 0}_${metacriticMax ?? 100}_${releasedAfter ?? ''}_${releasedBefore ?? ''}';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      final queryParams = <String, String>{
        'key': _apiKey,
        'page_size': '40', // Fetch more to filter better results
        'search_precise': 'true', // More precise search
      };

      if (query.isNotEmpty) {
        queryParams['search'] = query;
      }

      if (genre != null && genre != 'all') {
        queryParams['genres'] = genre;
      }

      if (platform != null && platform != 'all') {
        queryParams['platforms'] = platform;
      }

      // Enhanced ordering logic for better search results
      String finalOrdering = ordering ?? '-rating';
      if (query.isNotEmpty) {
        // For search queries, prioritize relevance
        finalOrdering = '-relevance';
      }
      queryParams['ordering'] = finalOrdering;

      if (metacriticMin != null && metacriticMax != null) {
        if (metacriticMin > 0 || metacriticMax < 100) {
          queryParams['metacritic'] = '$metacriticMin,$metacriticMax';
        }
      }

      if (releasedAfter != null && releasedAfter.isNotEmpty) {
        if (releasedBefore != null && releasedBefore.isNotEmpty) {
          queryParams['dates'] = '$releasedAfter,$releasedBefore';
        } else {
          queryParams['dates'] = '$releasedAfter,${DateTime.now().year}-12-31';
        }
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return [];
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Enhanced filtering and sorting for better search results
        List<Game> filteredGames = games;
        
        if (query.isNotEmpty) {
          // Filter out games that don't match the search query well
          final queryWords = query.toLowerCase().split(' ').where((word) => word.isNotEmpty && word.length >= 2).toList();
          final queryLower = query.toLowerCase();
          
          filteredGames = games.where((game) {
            final titleLower = game.title.toLowerCase();
            final developerLower = game.developer.toLowerCase();
            
            // First priority: exact phrase match (highest priority for multi-word searches like "Hollow Knight")
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
            
            // For multi-word searches, be much stricter - require ALL words to be present
            int titleWordMatches = 0;
            int totalWordMatches = 0;
            
            for (final word in queryWords) {
              if (titleLower.contains(word)) {
                titleWordMatches++;
                totalWordMatches++;
              } else if (developerLower.contains(word) ||
                        game.genres.any((genre) => genre.toLowerCase().contains(word))) {
                totalWordMatches++;
              }
            }
            
            // For multi-word searches, require ALL words to match somewhere
            // But heavily prefer games where all words match in the title
            if (queryWords.length >= 2) {
              // If all words match in title, definitely include
              if (titleWordMatches == queryWords.length) {
                return true;
              }
              // If all words match somewhere (title, developer, or genre), include
              if (totalWordMatches == queryWords.length) {
                return true;
              }
              // Otherwise, exclude to avoid irrelevant results
              return false;
            }
            
            return false;
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
        throw Exception('RAWG API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in advanced search: $e');
      }
      rethrow;
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
    // VERY HIGH PRIORITY: Title contains the exact phrase (critical for "Hollow Knight" searches)
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
      // Single word scoring (original logic but with higher scores)
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