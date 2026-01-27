import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContentFilterService {
  static const String _adultContentKey = 'adult_content_enabled';
  static const String _ageVerifiedKey = 'age_verified';
  
  // Singleton pattern
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();
  static ContentFilterService get instance => _instance;

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if adult content is enabled
  Future<bool> isAdultContentEnabled() async {
    await _initPrefs();
    return _prefs?.getBool(_adultContentKey) ?? false;
  }

  /// Check if user has verified their age
  Future<bool> isAgeVerified() async {
    await _initPrefs();
    return _prefs?.getBool(_ageVerifiedKey) ?? false;
  }

  /// Enable adult content (requires age verification)
  Future<bool> enableAdultContent() async {
    await _initPrefs();
    
    // Check if age is already verified
    final isVerified = await isAgeVerified();
    if (!isVerified) {
      return false; // Age verification required
    }
    
    await _prefs?.setBool(_adultContentKey, true);
    debugPrint('Adult content enabled');
    return true;
  }

  /// Disable adult content
  Future<void> disableAdultContent() async {
    await _initPrefs();
    await _prefs?.setBool(_adultContentKey, false);
    debugPrint('Adult content disabled');
  }

  /// Verify user age (18+)
  Future<void> verifyAge() async {
    await _initPrefs();
    await _prefs?.setBool(_ageVerifiedKey, true);
    debugPrint('Age verified');
  }

  /// Reset age verification (for testing or account changes)
  Future<void> resetAgeVerification() async {
    await _initPrefs();
    await _prefs?.setBool(_ageVerifiedKey, false);
    await _prefs?.setBool(_adultContentKey, false);
    debugPrint('Age verification reset');
  }

  /// Check if a game should be filtered based on content rating
  bool shouldFilterGame(Map<String, dynamic> gameData) {
    // Check ESRB rating
    final esrbRating = gameData['esrb_rating']?['name']?.toString().toLowerCase();
    if (esrbRating != null) {
      if (esrbRating.contains('adults only') || esrbRating.contains('ao')) {
        return true; // Always filter AO content
      }
      if (esrbRating.contains('mature') || esrbRating.contains('m')) {
        return true; // Filter M-rated content when adult mode is off
      }
    }

    // Check for adult tags
    final tags = gameData['tags'] as List<dynamic>? ?? [];
    for (final tag in tags) {
      final tagName = tag['name']?.toString().toLowerCase() ?? '';
      if (_isAdultTag(tagName)) {
        return true;
      }
    }

    // Check for adult genres
    final genres = gameData['genres'] as List<dynamic>? ?? [];
    for (final genre in genres) {
      final genreName = genre['name']?.toString().toLowerCase() ?? '';
      if (_isAdultGenre(genreName)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a tag indicates adult content
  bool _isAdultTag(String tagName) {
    const adultTags = [
      'nudity',
      'sexual content',
      'mature',
      'adult',
      'erotic',
      'nsfw',
      'sexual themes',
      'partial nudity',
      'strong sexual content',
      'graphic violence',
      'intense violence',
    ];
    
    return adultTags.any((tag) => tagName.contains(tag));
  }

  /// Check if a genre indicates adult content
  bool _isAdultGenre(String genreName) {
    const adultGenres = [
      'adult',
      'erotic',
      'mature',
    ];
    
    return adultGenres.any((genre) => genreName.contains(genre));
  }

  /// Get content warning for a game
  String? getContentWarning(Map<String, dynamic> gameData) {
    final esrbRating = gameData['esrb_rating']?['name']?.toString();
    if (esrbRating != null) {
      if (esrbRating.toLowerCase().contains('mature')) {
        return 'Mature 17+ - Intense Violence, Blood and Gore, Sexual Themes, Strong Language';
      }
      if (esrbRating.toLowerCase().contains('adults only')) {
        return 'Adults Only 18+ - Content suitable only for adults';
      }
    }

    // Check for specific content warnings based on tags
    final tags = gameData['tags'] as List<dynamic>? ?? [];
    final warnings = <String>[];
    
    for (final tag in tags) {
      final tagName = tag['name']?.toString().toLowerCase() ?? '';
      if (tagName.contains('nudity')) {
        warnings.add('Nudity');
      }
      if (tagName.contains('sexual')) {
        warnings.add('Sexual Content');
      }
      if (tagName.contains('violence')) {
        warnings.add('Violence');
      }
      if (tagName.contains('gore')) {
        warnings.add('Blood and Gore');
      }
    }

    return warnings.isNotEmpty ? warnings.join(', ') : null;
  }

  /// Filter games list based on adult content settings
  Future<List<T>> filterGamesList<T>(List<T> games, T Function(Map<String, dynamic>) fromMap, Map<String, dynamic> Function(T) toMap) async {
    final adultContentEnabled = await isAdultContentEnabled();
    
    if (adultContentEnabled) {
      return games; // No filtering when adult content is enabled
    }

    // Filter out adult content
    return games.where((game) {
      final gameData = toMap(game);
      return !shouldFilterGame(gameData);
    }).toList();
  }
}