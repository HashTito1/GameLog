import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';

class CacheService {
  static const String _gamesPrefix = 'games_';
  static const String _genresKey = 'genres';
  static const String _platformsKey = 'platforms';
  static const String _trendingKey = 'trending_games';
  static const String _popularKey = 'popular_games';
  static const String _actionKey = 'action_games';
  static const String _rpgKey = 'rpg_games';
  static const String _indieKey = 'indie_games';
  
  // Cache duration in minutes
  static const int _cacheDuration = 30;

  static Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // Generic cache methods
  static Future<void> _setCacheData(String key, String data) async {
    final prefs = await _prefs;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheData = {
      'data': data,
      'timestamp': timestamp,
    };
    await prefs.setString(key, jsonEncode(cacheData));
  }

  static Future<String?> _getCacheData(String key) async {
    final prefs = await _prefs;
    final cacheString = prefs.getString(key);
    
    if (cacheString == null) {
      return null;
    }
    
    try {
      final cacheData = jsonDecode(cacheString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is still valid (within cache duration)
      if (now - timestamp < _cacheDuration * 60 * 1000) {
        return cacheData['data'] as String;
      } else {
        // Cache expired, remove it
        await prefs.remove(key);
        return null;
      }
    } catch (e) {
      // Invalid cache data, remove it
      await prefs.remove(key);
      return null;
      // Error handled
    }
  }

  // Game list caching
  static Future<void> cacheGameList(String key, List<Game> games) async {
    final gamesJson = games.map((game) => game.toJson()).toList();
    await _setCacheData(key, jsonEncode(gamesJson));
  }

  static Future<List<Game>?> getCachedGameList(String key) async {
    final cachedData = await _getCacheData(key);
    if (cachedData == null) {
      return null;
    }
    
    try {
      final gamesJson = jsonDecode(cachedData) as List<dynamic>;
      return gamesJson.map((json) => Game.fromJson(json)).toList();
    } catch (e) {
      return null;
      // Error handled
    }
  }

  // Individual game caching
  static Future<void> cacheGame(Game game) async {
    await _setCacheData('$_gamesPrefix${game.id}', jsonEncode(game.toJson()));
  }

  static Future<Game?> getCachedGame(String gameId) async {
    final cachedData = await _getCacheData('$_gamesPrefix$gameId');
    if (cachedData == null) {
      return null;
    }
    
    try {
      return Game.fromJson(jsonDecode(cachedData));
    } catch (e) {
      return null;
      // Error handled
    }
  }

  // Genres caching
  static Future<void> cacheGenres(List<String> genres) async {
    await _setCacheData(_genresKey, jsonEncode(genres));
  }

  static Future<List<String>?> getCachedGenres() async {
    final cachedData = await _getCacheData(_genresKey);
    if (cachedData == null) {
      return null;
    }
    
    try {
      return List<String>.from(jsonDecode(cachedData));
    } catch (e) {
      return null;
      // Error handled
    }
  }

  // Platforms caching
  static Future<void> cachePlatforms(List<Map<String, dynamic>> platforms) async {
    await _setCacheData(_platformsKey, jsonEncode(platforms));
  }

  static Future<List<Map<String, dynamic>>?> getCachedPlatforms() async {
    final cachedData = await _getCacheData(_platformsKey);
    if (cachedData == null) {
      return null;
    }
    
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
    } catch (e) {
      return null;
      // Error handled
    }
  }

  // Specific game category cache keys
  static String get trendingGamesKey => _trendingKey;
  static String get popularGamesKey => _popularKey;
  static String get actionGamesKey => _actionKey;
  static String get rpgGamesKey => _rpgKey;
  static String get indieGamesKey => _indieKey;

  // Clear all cache
  static Future<void> clearAllCache() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((key) => 
      key.startsWith(_gamesPrefix) || 
      key == _genresKey || 
      key == _platformsKey ||
      key == _trendingKey ||
      key == _popularKey ||
      key == _actionKey ||
      key == _rpgKey ||
      key == _indieKey
    ).toList();
    
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Clear expired cache
  static Future<void> clearExpiredCache() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final key in keys) {
      final cacheString = prefs.getString(key);
      if (cacheString != null) {
        try {
          final cacheData = jsonDecode(cacheString);
          final timestamp = cacheData['timestamp'] as int;
          
          if (now - timestamp >= _cacheDuration * 60 * 1000) {
            await prefs.remove(key);
          }
        } catch (e) {
          // Invalid cache data, remove it
          await prefs.remove(key);
          // Error handled
    }
      }
    }
  }
}


