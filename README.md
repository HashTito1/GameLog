# GameLog 🎮

A social platform for gamers to track, rate, and review games - like Letterboxd but for video games!

## Features

- **Game Library**: Track games you're playing, completed, or plan to play
- **Reviews & Ratings**: Write reviews and rate games with a 5-star system
- **Social Feed**: See what games your friends are playing and their reviews
- **Game Discovery**: Search and discover new games
- **Personal Stats**: Track your gaming habits and statistics

## Screens

- **Home**: Recent reviews from the community and trending games
- **Search**: Find games to add to your library
- **Library**: Manage your personal game collection with status tracking
- **Profile**: View your stats, recent activity, and favorite games

## Tech Stack

- Flutter for cross-platform mobile development
- Dart programming language
- Firebase Authentication for secure user management
- Cloud Firestore for data storage
- Material Design 3 with dark theme
- Google Fonts for typography
- Flutter Rating Bar for star ratings
- RAWG API for real game data
- Cached Network Image for optimized image loading

## Security & Privacy

GameLog prioritizes user security and data protection:

- ✅ **Secure Authentication**: Firebase Auth handles all password management
- ✅ **No Local Password Storage**: Passwords never stored on devices
- ✅ **Encrypted Data**: All communication uses HTTPS/TLS encryption
- ✅ **Access Controls**: Firestore security rules protect user data
- ✅ **Regular Updates**: Automatic security updates through GitHub releases

See [SECURITY.md](SECURITY.md) for detailed security information.

## API Integration

GameLog integrates with the **RAWG Video Games Database API** to provide:
- Real game data and metadata
- High-quality cover images
- Accurate ratings and review counts
- Developer/publisher information
- Genre and platform data
- Release dates and descriptions

The app includes intelligent caching and fallback to mock data for offline functionality.

## Getting Started

1. Make sure you have Flutter installed on your system
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/                      # Data models
│   ├── game.dart
│   ├── user.dart
│   ├── auth_user.dart
│   └── user_rating.dart
├── services/                    # Services
│   ├── rawg_service.dart        # RAWG API integration
│   ├── firebase_auth_service.dart
│   ├── rating_service.dart
│   ├── library_service.dart
│   └── cache_service.dart
├── screens/                     # App screens
│   ├── main_screen.dart
│   ├── home_screen.dart
│   ├── search_screen.dart
│   ├── library_screen.dart
│   ├── profile_screen.dart
│   ├── game_detail_screen.dart
│   └── auth/                    # Authentication screens
└── widgets/                     # Reusable widgets
    └── game_card.dart
```

## Implemented Features

- ✅ Firebase user authentication with email verification
- ✅ Game search and discovery via RAWG API
- ✅ Personal game library with status tracking
- ✅ Rating and review system
- ✅ User profiles with customization
- ✅ Intelligent caching for offline support

## Future Enhancements

- Social following system
- Game recommendations
- Achievement system
- Integration with gaming platforms (Steam, PlayStation, Xbox)
- Photo sharing for gaming moments
- Gaming lists and collections
- Push notifications for new reviews