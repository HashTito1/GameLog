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
- IGDB API for comprehensive game data
- Cached Network Image for optimized image loading

## Security & Privacy

GameLog prioritizes user security and data protection:

- ✅ **Secure Authentication**: Firebase Auth handles all password management
- ✅ **No Local Password Storage**: Passwords never stored on devices
- ✅ **Encrypted Data**: All communication uses HTTPS/TLS encryption
- ✅ **Access Controls**: Firestore security rules protect user data
- ✅ **Secure API Integration**: IGDB credentials properly managed
- ✅ **Offline-First Design**: Full functionality without external dependencies
- ✅ **Regular Updates**: Automatic security updates through GitHub releases

See [SECURITY.md](SECURITY.md) for detailed security information.

## API Integration

GameLog uses the **IGDB API** (Internet Game Database) for comprehensive game data:

- **Setup Required**: You'll need to configure IGDB API credentials
- **Better Data**: More accurate and comprehensive game information than RAWG
- **Higher Quality Images**: Better cover art and screenshots
- **Real Game Data**: Fetches live game information, ratings, and metadata
- **Comprehensive Database**: Access to 500,000+ games from IGDB
- **Automatic Caching**: Intelligent caching for better performance

## Getting Started

### Prerequisites
- Flutter SDK installed on your system
- Twitch Developer Account (for IGDB API access)

### Setup Instructions

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure IGDB API** (Required):
   - Follow the detailed setup guide in [IGDB_SETUP.md](IGDB_SETUP.md)
   - Get your Twitch Client ID and Access Token
   - Update `lib/services/igdb_service.dart` with your credentials

3. **Test IGDB Connection**:
   ```bash
   dart run scripts/test_igdb_connection.dart
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

### Important Notes
- The app requires IGDB API credentials to fetch game data
- Without proper API setup, the app will show configuration errors
- See [IGDB_SETUP.md](IGDB_SETUP.md) for detailed setup instructions

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
│   ├── igdb_service.dart        # IGDB API integration
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

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

**Why GPL v3?** We chose GPL v3 to encourage collaborative development and ensure GameLog remains free and open source. This means:
- ✅ Anyone can use and modify the code
- ✅ All improvements must be shared back with the community
- ✅ No one can create proprietary versions
- ✅ The project stays open source forever

## Contributing

We **strongly encourage contributions** to the main GameLog project! Here's how:

1. **Fork** the repository on GitHub
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Contribution Guidelines
- Follow Flutter/Dart best practices
- Write clear commit messages
- Test your changes thoroughly
- Update documentation as needed
- Be respectful and collaborative

### Types of Contributions Welcome
- 🐛 Bug fixes
- ✨ New features
- 📚 Documentation improvements
- 🎨 UI/UX enhancements
- 🔧 Performance optimizations
- 🌐 Translations/Localization

## Acknowledgments

- [RAWG.io](https://rawg.io/) for providing the video game database API
- [Firebase](https://firebase.google.com/) for authentication and database services
- [Flutter](https://flutter.dev/) for the amazing cross-platform framework