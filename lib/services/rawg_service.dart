import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import 'cache_service.dart';

class RAWGService {
  static const String _baseUrl = 'https://api.rawg.io/api';
  static const String _apiKey = '4158ece2bc984544b698665ed3052464';
  
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
        'page_size': (limit * 2).toString(), // Fetch more for better caching
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
          final mockResults = _getMockGames().where((game) => 
            game.title.toLowerCase().contains(query.toLowerCase()) ||
            game.developer.toLowerCase().contains(query.toLowerCase()) ||
            game.genres.any((genre) => genre.toLowerCase().contains(query.toLowerCase()))
          ).take(limit).toList();
          
          // Cache mock results with shorter duration
          await CacheService.cacheGameList(cacheKey, mockResults);
          return mockResults;
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the search results
        await CacheService.cacheGameList(cacheKey, games);
        
        // Also cache individual games
        for (final game in games.take(10)) { // Only cache first 10 to avoid too many individual cache entries
          await CacheService.cacheGame(game);
        }
        
        return games.take(limit).toList();
      } else {
        if (kDebugMode) {
                  }
        final mockResults = _getMockGames().where((game) => 
          game.title.toLowerCase().contains(query.toLowerCase()) ||
          game.developer.toLowerCase().contains(query.toLowerCase()) ||
          game.genres.any((genre) => genre.toLowerCase().contains(query.toLowerCase()))
        ).take(limit).toList();
        
        await CacheService.cacheGameList(cacheKey, mockResults);
        return mockResults;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching games: $e');
      }
      final mockResults = _getMockGames().where((game) => 
        game.title.toLowerCase().contains(query.toLowerCase()) ||
        game.developer.toLowerCase().contains(query.toLowerCase()) ||
        game.genres.any((genre) => genre.toLowerCase().contains(query.toLowerCase()))
      ).take(limit).toList();
      return mockResults;
    }
  }

  // Get popular games with caching
  Future<List<Game>> getPopularGames({int limit = 20}) async {
    try {
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(CacheService.popularGamesKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'ordering': '-rating',
        'page_size': '40', // Fetch more to cache
        'metacritic': '80,100',
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          final mockGames = _getMockGames().take(limit).toList();
          await CacheService.cacheGameList(CacheService.popularGamesKey, mockGames);
          return mockGames;
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the results
        await CacheService.cacheGameList(CacheService.popularGamesKey, games);
        
        // Also cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return games.take(limit).toList();
      } else {
                final mockGames = _getMockGames().take(limit).toList();
        await CacheService.cacheGameList(CacheService.popularGamesKey, mockGames);
        return mockGames;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular games: $e');
      }
      final mockGames = _getMockGames().take(limit).toList();
      await CacheService.cacheGameList(CacheService.popularGamesKey, mockGames);
      return mockGames;
    }
  }

  // Get trending games with caching
  Future<List<Game>> getTrendingGames({int limit = 20}) async {
    try {
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(CacheService.trendingGamesKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      final dateString = '${oneMonthAgo.year}-${oneMonthAgo.month.toString().padLeft(2, '0')}-${oneMonthAgo.day.toString().padLeft(2, '0')}';
      
      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'dates': '$dateString,${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'ordering': '-added',
        'page_size': '40', // Fetch more to cache
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        if (results.isEmpty) {
          final mockGames = _getMockGames().take(limit).toList();
          await CacheService.cacheGameList(CacheService.trendingGamesKey, mockGames);
          return mockGames;
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the results
        await CacheService.cacheGameList(CacheService.trendingGamesKey, games);
        
        // Also cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return games.take(limit).toList();
      } else {
        if (kDebugMode) {
                  }
        final mockGames = _getMockGames().take(limit).toList();
        await CacheService.cacheGameList(CacheService.trendingGamesKey, mockGames);
        return mockGames;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting trending games: $e');
      }
      final mockGames = _getMockGames().take(limit).toList();
      await CacheService.cacheGameList(CacheService.trendingGamesKey, mockGames);
      return mockGames;
    }
  }

  // Get game details by ID with caching
  Future<Game?> getGameDetails(String gameId) async {
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
        // Return mock game if API fails
        final mockGames = _getMockGames();
        final mockGame = mockGames.firstWhere(
          (game) => game.id == gameId,
          orElse: () => mockGames.first,
        );
        await CacheService.cacheGame(mockGame);
        return mockGame;
      }
    } catch (e) {
      // Return mock game on error
      final mockGames = _getMockGames();
      final mockGame = mockGames.firstWhere(
        (game) => game.id == gameId,
        orElse: () => mockGames.first,
      );
      await CacheService.cacheGame(mockGame);
      return mockGame;
    }
  }

  // Get games by genre with caching
  Future<List<Game>> getGamesByGenre(String genre, {int limit = 20}) async {
    try {
      final cacheKey = 'genre_$genre';
      
      // Try to get from cache first
      final cachedGames = await CacheService.getCachedGameList(cacheKey);
      if (cachedGames != null && cachedGames.isNotEmpty) {
        return cachedGames.take(limit).toList();
      }

      final uri = Uri.parse('$_baseUrl/games').replace(queryParameters: {
        'key': _apiKey,
        'genres': genre.toLowerCase(),
        'ordering': '-rating',
        'page_size': '30', // Fetch more to cache
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the results
        await CacheService.cacheGameList(cacheKey, games);
        
        // Also cache individual games
        for (final game in games) {
          await CacheService.cacheGame(game);
        }
        
        return games.take(limit).toList();
      } else {
                // Fallback to mock data
        final mockGames = _getMockGames();
        final filteredGames = mockGames.where((game) => 
          game.genres.any((g) => g.toLowerCase().contains(genre.toLowerCase()))
        ).take(limit).toList();
        
        await CacheService.cacheGameList(cacheKey, filteredGames);
        return filteredGames;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting games by genre: $e');
      }
      return [];
    }
  }

  // Get available genres from RAWG with caching
  Future<List<String>> getGenres() async {
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
                final defaultGenres = _getDefaultGenres();
        await CacheService.cacheGenres(defaultGenres);
        return defaultGenres;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting genres: $e');
      }
      final defaultGenres = _getDefaultGenres();
      await CacheService.cacheGenres(defaultGenres);
      return defaultGenres;
    }
  }

  // Get available platforms from RAWG with caching
  Future<List<Map<String, dynamic>>> getPlatforms() async {
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
                final defaultPlatforms = _getDefaultPlatforms();
        await CacheService.cachePlatforms(defaultPlatforms);
        return defaultPlatforms;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting platforms: $e');
      }
      final defaultPlatforms = _getDefaultPlatforms();
      await CacheService.cachePlatforms(defaultPlatforms);
      return defaultPlatforms;
    }
  }

  // Parse RAWG response to Game model
  Game _parseGameFromRAWG(Map<String, dynamic> data) {
    // Extract cover image URL
    String coverImage = data['background_image'] ?? '';
    
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
      title: data['name'] ?? 'Unknown Title',
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

  // Default genres fallback
  static List<String> _getDefaultGenres() {
    return [
      'Action', 'Adventure', 'RPG', 'Strategy', 'Shooter', 'Puzzle',
      'Racing', 'Sports', 'Simulation', 'Platformer', 'Fighting',
      'Horror', 'Indie', 'Casual', 'Family', 'Educational'
    ];
  }

  // Default platforms fallback
  static List<Map<String, dynamic>> _getDefaultPlatforms() {
    return [
      {'id': '4', 'name': 'PC'},
      {'id': '187', 'name': 'PlayStation 5'},
      {'id': '1', 'name': 'Xbox One'},
      {'id': '18', 'name': 'PlayStation 4'},
      {'id': '186', 'name': 'Xbox Series S/X'},
      {'id': '7', 'name': 'Nintendo Switch'},
      {'id': '3', 'name': 'iOS'},
      {'id': '21', 'name': 'Android'},
    ];
  }

  // Check if service is available
  static bool get isConfigured => true;

  // Test API connection
  Future<bool> testConnection() async {
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

  // Advanced search with comprehensive filters
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
        'page_size': (limit * 2).toString(),
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

      if (ordering != null && ordering != 'relevance') {
        queryParams['ordering'] = ordering;
      }

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
          // Fallback to filtered mock data
          final mockResults = _getFilteredMockGames(
            query: query,
            genre: genre,
            platform: platform,
            metacriticMin: metacriticMin,
            metacriticMax: metacriticMax,
            limit: limit,
          );
          
          await CacheService.cacheGameList(cacheKey, mockResults);
          return mockResults;
        }
        
        final games = results.map((gameData) => _parseGameFromRAWG(gameData)).toList();
        
        // Cache the search results
        await CacheService.cacheGameList(cacheKey, games);
        
        // Also cache individual games
        for (final game in games.take(10)) {
          await CacheService.cacheGame(game);
        }
        
        return games.take(limit).toList();
      } else {
        if (kDebugMode) {
          print('RAWG API error: ${response.statusCode}');
        }
        final mockResults = _getFilteredMockGames(
          query: query,
          genre: genre,
          platform: platform,
          metacriticMin: metacriticMin,
          metacriticMax: metacriticMax,
          limit: limit,
        );
        
        await CacheService.cacheGameList(cacheKey, mockResults);
        return mockResults;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in advanced search: $e');
      }
      final mockResults = _getFilteredMockGames(
        query: query,
        genre: genre,
        platform: platform,
        metacriticMin: metacriticMin,
        metacriticMax: metacriticMax,
        limit: limit,
      );
      return mockResults;
    }
  }

  // Helper method to filter mock games based on search criteria
  List<Game> _getFilteredMockGames({
    required String query,
    String? genre,
    String? platform,
    int? metacriticMin,
    int? metacriticMax,
    required int limit,
  }) {
    List<Game> filteredGames = _getMockGames();

    // Filter by search query
    if (query.isNotEmpty) {
      filteredGames = filteredGames.where((game) =>
        game.title.toLowerCase().contains(query.toLowerCase()) ||
        game.developer.toLowerCase().contains(query.toLowerCase()) ||
        game.genres.any((g) => g.toLowerCase().contains(query.toLowerCase()))
      ).toList();
    }

    // Filter by genre
    if (genre != null && genre != 'all') {
      filteredGames = filteredGames.where((game) =>
        game.genres.any((g) => g.toLowerCase().contains(genre.toLowerCase()))
      ).toList();
    }

    // Filter by platform
    if (platform != null && platform != 'all') {
      final platformNames = {
        '4': 'pc',
        '187': 'playstation',
        '18': 'playstation',
        '186': 'xbox',
        '1': 'xbox',
        '7': 'nintendo',
        '3': 'ios',
        '21': 'android',
      };
      
      final platformName = platformNames[platform] ?? platform.toLowerCase();
      filteredGames = filteredGames.where((game) =>
        game.platforms.any((p) => p.toLowerCase().contains(platformName))
      ).toList();
    }

    // Filter by metacritic score (using averageRating as proxy)
    if (metacriticMin != null && metacriticMax != null) {
      final minRating = metacriticMin / 20.0; // Convert 0-100 to 0-5 scale
      final maxRating = metacriticMax / 20.0;
      filteredGames = filteredGames.where((game) =>
        game.averageRating >= minRating && game.averageRating <= maxRating
      ).toList();
    }

    return filteredGames.take(limit).toList();
  }
}



// Mock data for fallback when API is unavailable
List<Game> _getMockGames() {
  return [
    Game(
      id: '1',
      title: 'The Legend of Zelda: Tears of the Kingdom',
      developer: 'Nintendo',
      publisher: 'Nintendo',
      releaseDate: '2023',
      platforms: ['Nintendo Switch'],
      genres: ['Action', 'Adventure', 'Open World'],
      coverImage: 'https://media.rawg.io/media/games/2fe/2feec1ba840f467a2280061b9ad6a86e.jpg',
      description: 'An epic adventure in Hyrule continues with new abilities and mysteries to uncover. Build, explore, and discover in this groundbreaking sequel.',
      averageRating: 4.8,
      totalReviews: 1250,
    ),
    Game(
      id: '2',
      title: 'Baldur\'s Gate 3',
      developer: 'Larian Studios',
      publisher: 'Larian Studios',
      releaseDate: '2023',
      platforms: ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      genres: ['RPG', 'Strategy', 'Turn-Based'],
      coverImage: 'https://media.rawg.io/media/games/699/69907ecf13f172e9e144069769c3be73.jpg',
      description: 'A story-rich, party-based RPG set in the universe of Dungeons & Dragons. Make choices that will determine the fate of the Forgotten Realms.',
      averageRating: 4.9,
      totalReviews: 2100,
    ),
    Game(
      id: '3',
      title: 'Spider-Man 2',
      developer: 'Insomniac Games',
      publisher: 'Sony Interactive Entertainment',
      releaseDate: '2023',
      platforms: ['PlayStation 5'],
      genres: ['Action', 'Adventure', 'Superhero'],
      coverImage: 'https://media.rawg.io/media/games/ed5/ed5b55b2c1e5a5e2e3b7d8b7b5b5b5b5.jpg',
      description: 'Be Greater. Together. Spider-Men Peter Parker and Miles Morales face the ultimate test of strength inside and outside the mask.',
      averageRating: 4.7,
      totalReviews: 890,
    ),
    Game(
      id: '4',
      title: 'Hogwarts Legacy',
      developer: 'Avalanche Software',
      publisher: 'Warner Bros. Games',
      releaseDate: '2023',
      platforms: ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      genres: ['Action', 'RPG', 'Open World'],
      coverImage: 'https://media.rawg.io/media/games/b29/b294fdd866dcdb643e7bab370a552855.jpg',
      description: 'Experience Hogwarts in the 1800s. Your character is a student who holds the key to an ancient secret that threatens to tear the wizarding world apart.',
      averageRating: 4.5,
      totalReviews: 1580,
    ),
    Game(
      id: '5',
      title: 'Starfield',
      developer: 'Bethesda Game Studios',
      publisher: 'Bethesda Softworks',
      releaseDate: '2023',
      platforms: ['PC', 'Xbox Series X/S'],
      genres: ['RPG', 'Space', 'Exploration'],
      coverImage: 'https://media.rawg.io/media/games/b34/b3419c2706f8f8dbe40d08e23642ad06.jpg',
      description: 'Starfield is the first new universe in 25 years from Bethesda Game Studios. Create any character you want and explore with unparalleled freedom.',
      averageRating: 4.2,
      totalReviews: 2340,
    ),
    Game(
      id: '6',
      title: 'Super Mario Bros. Wonder',
      developer: 'Nintendo',
      publisher: 'Nintendo',
      releaseDate: '2023',
      platforms: ['Nintendo Switch'],
      genres: ['Platformer', 'Adventure'],
      coverImage: 'https://media.rawg.io/media/games/a9c/a9c789951de65da545d51f664b4f2ce0.jpg',
      description: 'Mario and friends\' next adventure has them traveling to the Flower Kingdom where they discover Wonder Flowers that cause surprising transformations.',
      averageRating: 4.6,
      totalReviews: 980,
    ),
    Game(
      id: '7',
      title: 'Alan Wake 2',
      developer: 'Remedy Entertainment',
      publisher: 'Epic Games Publishing',
      releaseDate: '2023',
      platforms: ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      genres: ['Horror', 'Thriller', 'Action'],
      coverImage: 'https://media.rawg.io/media/games/b45/b45575f34285f2c4479c9a5f719d972e.jpg',
      description: 'A sequel 13 years in the making. Alan Wake 2 is a survival horror game with an intense atmosphere and a layered, psychological story.',
      averageRating: 4.4,
      totalReviews: 756,
    ),
    Game(
      id: '8',
      title: 'Cyberpunk 2077: Phantom Liberty',
      developer: 'CD Projekt RED',
      publisher: 'CD Projekt',
      releaseDate: '2023',
      platforms: ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      genres: ['RPG', 'Action', 'Cyberpunk'],
      coverImage: 'https://media.rawg.io/media/games/26d/26d4437715bee60138dab4a7c8c59c92.jpg',
      description: 'Return to Night City in Phantom Liberty, a spy-thriller expansion for Cyberpunk 2077. Become a cyberpunk and live by the code of the street.',
      averageRating: 4.3,
      totalReviews: 1120,
    ),
    Game(
      id: '9',
      title: 'Elden Ring',
      developer: 'FromSoftware',
      publisher: 'Bandai Namco Entertainment',
      releaseDate: '2022',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S'],
      genres: ['Action', 'RPG', 'Souls-like'],
      coverImage: 'https://media.rawg.io/media/games/5ec/5ecac5cb026ec26a56efcc546364e348.jpg',
      description: 'A new fantasy action RPG. Rise, Tarnished, and be guided by grace to brandish the power of the Elden Ring and become an Elden Lord in the Lands Between.',
      averageRating: 4.8,
      totalReviews: 3200,
    ),
    Game(
      id: '10',
      title: 'God of War Ragnarök',
      developer: 'Santa Monica Studio',
      publisher: 'Sony Interactive Entertainment',
      releaseDate: '2022',
      platforms: ['PlayStation 4', 'PlayStation 5'],
      genres: ['Action', 'Adventure', 'Mythology'],
      coverImage: 'https://media.rawg.io/media/games/4be/4be6a6ad0364751a96229c56bf69be59.jpg',
      description: 'Embark on an epic and heartfelt journey as Kratos and Atreus struggle with holding on and letting go.',
      averageRating: 4.7,
      totalReviews: 2800,
    ),
    Game(
      id: '11',
      title: 'The Witcher 3: Wild Hunt',
      developer: 'CD Projekt RED',
      publisher: 'CD Projekt',
      releaseDate: '2015',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S', 'Nintendo Switch'],
      genres: ['RPG', 'Open World', 'Fantasy'],
      coverImage: 'https://media.rawg.io/media/games/618/618c2031a07bbff6b4f611f10b6bcdbc.jpg',
      description: 'As war rages on throughout the Northern Realms, you take on the greatest contract of your life — tracking down the Child of Prophecy.',
      averageRating: 4.9,
      totalReviews: 4500,
    ),
    Game(
      id: '12',
      title: 'Grand Theft Auto V',
      developer: 'Rockstar North',
      publisher: 'Rockstar Games',
      releaseDate: '2013',
      platforms: ['PC', 'PlayStation 3', 'PlayStation 4', 'PlayStation 5', 'Xbox 360', 'Xbox One', 'Xbox Series X/S'],
      genres: ['Action', 'Adventure', 'Open World'],
      coverImage: 'https://media.rawg.io/media/games/20a/20aa03a10cda45239fe22d035c0ebe64.jpg',
      description: 'When a young street hustler, a retired bank robber and a terrifying psychopath find themselves entangled with some of the most frightening and deranged elements of the criminal underworld.',
      averageRating: 4.6,
      totalReviews: 5200,
    ),
    Game(
      id: '13',
      title: 'Red Dead Redemption 2',
      developer: 'Rockstar Studios',
      publisher: 'Rockstar Games',
      releaseDate: '2018',
      platforms: ['PC', 'PlayStation 4', 'Xbox One'],
      genres: ['Action', 'Adventure', 'Western'],
      coverImage: 'https://media.rawg.io/media/games/511/5118aff5091cb3efec399c808f8c598f.jpg',
      description: 'America, 1899. The end of the wild west era has begun as lawmen hunt down the last remaining outlaw gangs.',
      averageRating: 4.8,
      totalReviews: 3800,
    ),
    Game(
      id: '14',
      title: 'Minecraft',
      developer: 'Mojang Studios',
      publisher: 'Microsoft Studios',
      releaseDate: '2011',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S', 'Nintendo Switch', 'Mobile'],
      genres: ['Sandbox', 'Survival', 'Creative'],
      coverImage: 'https://media.rawg.io/media/games/b4e/b4e4c73d5aa4ec66bbf75375c4847a2b.jpg',
      description: 'Minecraft is a game made up of blocks, creatures, and community. You can survive the night or build a work of art – the choice is all yours.',
      averageRating: 4.4,
      totalReviews: 6700,
    ),
    Game(
      id: '15',
      title: 'Call of Duty: Modern Warfare II',
      developer: 'Infinity Ward',
      publisher: 'Activision',
      releaseDate: '2022',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S'],
      genres: ['FPS', 'Action', 'Military'],
      coverImage: 'https://media.rawg.io/media/games/d82/d82990b9c67ba0d2d09d4e6fa88885a7.jpg',
      description: 'Call of Duty: Modern Warfare II drops players into an unprecedented global conflict that features the return of the iconic Operators of Task Force 141.',
      averageRating: 4.1,
      totalReviews: 2900,
    ),
    Game(
      id: '16',
      title: 'Fortnite',
      developer: 'Epic Games',
      publisher: 'Epic Games',
      releaseDate: '2017',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S', 'Nintendo Switch', 'Mobile'],
      genres: ['Battle Royale', 'Action', 'Shooter'],
      coverImage: 'https://media.rawg.io/media/games/73e/73eecb8909e0c39fb246f457b5d6cbbe.jpg',
      description: 'Fortnite is the completely free multiplayer game where you and your friends can jump into Battle Royale or Fortnite Creative.',
      averageRating: 4.0,
      totalReviews: 8900,
    ),
    Game(
      id: '17',
      title: 'Apex Legends',
      developer: 'Respawn Entertainment',
      publisher: 'Electronic Arts',
      releaseDate: '2019',
      platforms: ['PC', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X/S', 'Nintendo Switch'],
      genres: ['Battle Royale', 'FPS', 'Action'],
      coverImage: 'https://media.rawg.io/media/games/b72/b7233d5d5b1e75e86bb860ccc7aeca85.jpg',
      description: 'Conquer with character in Apex Legends, a free-to-play Battle Royale shooter where legendary characters with powerful abilities team up to battle for fame & fortune.',
      averageRating: 4.2,
      totalReviews: 4100,
    ),
    Game(
      id: '18',
      title: 'Valorant',
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseDate: '2020',
      platforms: ['PC'],
      genres: ['FPS', 'Tactical', 'Competitive'],
      coverImage: 'https://media.rawg.io/media/games/737/737ea5662211d2e0bbd6f5989189e4f1.jpg',
      description: 'Blend your style and experience on a global, competitive stage. You have 13 rounds to attack and defend your side using sharp gunplay and tactical abilities.',
      averageRating: 4.3,
      totalReviews: 3600,
    ),
    Game(
      id: '19',
      title: 'League of Legends',
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseDate: '2009',
      platforms: ['PC'],
      genres: ['MOBA', 'Strategy', 'Competitive'],
      coverImage: 'https://media.rawg.io/media/games/78d/78dfae12fb8c5b16cd78648553071e0a.jpg',
      description: 'League of Legends is a team-based game with over 140 champions to make epic plays with. Play now for free.',
      averageRating: 4.1,
      totalReviews: 7800,
    ),
    Game(
      id: '20',
      title: 'Counter-Strike 2',
      developer: 'Valve',
      publisher: 'Valve',
      releaseDate: '2023',
      platforms: ['PC'],
      genres: ['FPS', 'Tactical', 'Competitive'],
      coverImage: 'https://media.rawg.io/media/games/736/73619bd336c894d6941d926bfd563946.jpg',
      description: 'For over two decades, Counter-Strike has offered an elite competitive experience, one shaped by millions of players from across the globe.',
      averageRating: 4.4,
      totalReviews: 5400,
    ),
  ];
}