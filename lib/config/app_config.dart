/// Build-time configuration for third-party API credentials.
///
/// Values are injected at build time and are never committed to the repo:
///
///   flutter run --dart-define-from-file=dart_defines.json
///
/// Copy `dart_defines.example.json` to `dart_defines.json` (git-ignored) and
/// fill in your own keys. Anything shipped inside an app binary can still be
/// extracted by a determined user, so keep these keys low-privilege and
/// rotate them if they leak.
class AppConfig {
  AppConfig._();

  static const String igdbClientId = String.fromEnvironment('IGDB_CLIENT_ID');
  static const String igdbAccessToken = String.fromEnvironment('IGDB_ACCESS_TOKEN');
  static const String rawgApiKey = String.fromEnvironment('RAWG_API_KEY');
  static const String imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
}
