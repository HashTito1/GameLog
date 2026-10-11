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

- **Authentication**: Firebase Auth handles all password management; passwords are never stored on devices
- **Access controls**: [firestore.rules](firestore.rules) restrict every write to the data's owner (likes, follows and reply counters are limited to the caller's own changes). Admin roles are checked server-side by user ID
- **Private emails**: email addresses are not stored on public profile documents
- **No secrets in the repo**: API keys are injected at build time (see below)

## Game Data APIs

GameLog uses **IGDB** (via a Twitch developer app) for all game data. Profile pictures and banners are stored in **Firebase Storage** (requires the Firebase Blaze plan), protected by [storage.rules](storage.rules).

## Getting Started

### Prerequisites
- Flutter SDK
- A Twitch developer app for IGDB ([IGDB docs](https://api-docs.igdb.com/#getting-started))

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Configure API keys: copy `dart_defines.example.json` to `dart_defines.json` (git-ignored) and fill in your keys.

3. Run the app:
   ```bash
   flutter run --flavor user --dart-define-from-file=dart_defines.json
   ```
   VS Code users can use the included launch configurations instead. The admin app runs via `run_admin_app.bat`.

4. Deploy the security rules whenever `firestore.rules` or `storage.rules` changes:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```

Notes:
- IGDB app access tokens expire after about 60 days. Generate a new one with your Twitch client ID and secret and update `dart_defines.json`.
- Anything compiled into an app can be extracted, so use low-privilege keys. Moving the IGDB calls behind a Cloud Function would keep them off devices entirely.

### Admin setup

See [docs/ADMIN_SETUP.md](docs/ADMIN_SETUP.md).

### Release signing

Release APKs must always be signed with the same upload key, or in-app updates will fail to install.

1. Create a keystore once and keep it safe and backed up (never commit it):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
   `storeFile` is relative to `android/app`.
3. Build with `build_admin_apk.bat`. Without `key.properties`, release builds fall back to the debug key, which is fine locally but must not be published.

### Tests

```bash
flutter test
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
- ✅ Game search and discovery via IGDB
- ✅ Community forum, rating comments and likes
- ✅ Friends, following and notifications
- ✅ Separate admin app for moderation
- ✅ Personal game library with status tracking
- ✅ Rating and review system
- ✅ User profiles with customization
- ✅ Intelligent caching for offline support

## Future Enhancements

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

- [IGDB](https://www.igdb.com/) for video game data
- [Firebase](https://firebase.google.com/) for authentication and database services
- [Flutter](https://flutter.dev/) for the amazing cross-platform framework