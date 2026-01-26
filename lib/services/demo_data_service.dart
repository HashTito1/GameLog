import '../models/auth_user.dart';
import '../services/storage_service.dart';

class DemoDataService {
  static Future<void> setupDemoUser() async {
    // Create demo user
    final demoUser = AuthUser(
      id: 'demo_user_123',
      email: 'demo@gamelog.com',
      username: 'demo_gamer',
      displayName: 'Demo Gamer',
      bio: 'RPG enthusiast | Indie game lover | Currently playing Baldur\'s Gate 3',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastLoginAt: DateTime.now(),
      isEmailVerified: true,
      preferences: UserPreferences(
        favoriteGenres: ['RPG', 'Action', 'Adventure'],
      ),
    );

    // Save demo user
    await StorageService.saveUser(demoUser);
    await StorageService.savePassword('demo@gamelog.com', 'demo123');

    // Create demo library
    final demoLibrary = [
      {
        'id': '1',
        'gameId': 'bg3',
        'title': 'Baldur\'s Gate 3',
        'status': 'playing',
        'rating': null,
        'hoursPlayed': 45,
        'dateAdded': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': '2',
        'gameId': 'witcher3',
        'title': 'The Witcher 3: Wild Hunt',
        'status': 'completed',
        'rating': 5.0,
        'hoursPlayed': 120,
        'dateAdded': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
        'dateCompleted': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      },
      {
        'id': '3',
        'gameId': 'elden_ring',
        'title': 'Elden Ring',
        'status': 'plan-to-play',
        'dateAdded': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];

    await StorageService.saveUserLibrary(demoUser.id, demoLibrary);

    // Create demo reviews
    final demoReviews = [
      {
        'id': '1',
        'gameId': 'witcher3',
        'gameTitle': 'The Witcher 3: Wild Hunt',
        'rating': 5.0,
        'reviewText': 'An absolute masterpiece! The storytelling, world-building, and character development are unparalleled. Geralt\'s journey is both epic and deeply personal.',
        'dateReviewed': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'likes': 24,
        'isLiked': false,
      },
      {
        'id': '2',
        'gameId': 'hades',
        'gameTitle': 'Hades',
        'rating': 4.5,
        'reviewText': 'Incredible roguelike with perfect gameplay loop. The story unfolds beautifully with each run, and the art style is stunning.',
        'dateReviewed': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
        'likes': 18,
        'isLiked': false,
      },
    ];

    await StorageService.saveUserReviews(demoUser.id, demoReviews);
  }

  static Future<bool> isDemoUserSetup() async {
    final user = await StorageService.getUserByEmail('demo@gamelog.com');
    return user != null;
  }

  static Future<void> setupDemoUserIfNeeded() async {
    if (!(await isDemoUserSetup())) {
      await setupDemoUser();
    }
  }
}


