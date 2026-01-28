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
- ✅ **No Hardcoded API Keys**: All external API keys via environment variables only
- ✅ **Offline-First Design**: Full functionality without external dependencies
- ✅ **Regular Updates**: Automatic security updates through GitHub releases

See [SECURITY.md](SECURITY.md) for detailed security information.

## API Integration

GameLog is designed with an **offline-first approach**:

- **Works Without API Keys**: Complete functionality using curated mock data
- **Optional RAWG Integration**: Developers can optionally add RAWG API key for live data
- **Intelligent Fallbacks**: Automatic fallback to mock data if API is unavailable
- **Comprehensive Mock Data**: 23+ games covering all genres and platforms
- **No Hardcoded Keys**: All API keys must be provided via environment variables

See [API_CONFIGURATION.md](API_CONFIGURATION.md) for setup instructions.

### Mock Data Features
- Popular games from 2009-2026 (including upcoming titles)
- Diverse genres: Action, RPG, Strategy, Horror, Indie, and more
- Multiple platforms: PC, PlayStation, Xbox, Nintendo Switch, Mobile
- Realistic ratings, reviews, and metadata
- High-quality descriptions and game details

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