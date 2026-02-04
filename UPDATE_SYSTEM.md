# 🔄 GameLog In-App Update System

## Overview

GameLog v1.1.0 includes a comprehensive in-app update system that automatically checks for new versions from GitHub releases and provides users with a seamless update experience.

## Features

### ✨ Automatic Update Checking
- **Startup Check**: Automatically checks for updates 2 seconds after app launch
- **Interval-Based**: Checks every 6 hours to avoid excessive API calls
- **Smart Caching**: Uses SharedPreferences to track last check time
- **Non-Intrusive**: Only shows dialog when updates are actually available

### 🎨 Beautiful Update Dialog
- **Modern Design**: Animated popup with gradient backgrounds
- **Version Information**: Shows current vs. available version details
- **Release Notes**: Formatted display of what's new
- **Download Progress**: Visual progress indicator during download
- **Multiple Actions**: Download, Skip Version, View on GitHub, Later

### 📱 Manual Update Check
- **Settings Integration**: "Check for Updates" button in About screen
- **Detailed Feedback**: Different dialogs for various scenarios:
  - Update Available
  - Up to Date
  - Repository Not Configured
  - Check Failed

### 🔧 Technical Features
- **GitHub API Integration**: Fetches releases from Update-test-branch
- **APK Download**: Direct download and installation (Android)
- **Permission Handling**: Requests necessary permissions automatically
- **Error Handling**: Comprehensive fallbacks and error messages
- **Version Comparison**: Smart semantic version comparison

## How It Works

### 1. Automatic Checking Process

```dart
// On app startup (MainScreen)
WidgetsBinding.instance.addPostFrameCallback((_) {
  Future.delayed(const Duration(seconds: 2), () {
    if (mounted) {
      UpdateService.instance.checkForUpdatesAndShowDialog(context);
    }
  });
});
```

### 2. Update Detection Flow

1. **Check Interval**: Verifies if 6 hours have passed since last check
2. **GitHub API Call**: Fetches latest release from Update-test-branch
3. **Version Comparison**: Compares semantic versions (major.minor.patch)
4. **Build Number Check**: Falls back to build number if versions match
5. **Skip Check**: Respects user's "skip version" preference
6. **Dialog Display**: Shows update dialog if new version available

### 3. Download and Installation

```dart
// Download process
final success = await UpdateService.instance.downloadAndInstallUpdate(downloadUrl);

// Installation flow
1. Request storage permission
2. Download APK to external storage
3. Request install permission (Android 8.0+)
4. Install APK or open file manager
```

## Configuration

### GitHub Repository Setup

The update system is configured in `lib/services/update_service.dart`:

```dart
class UpdateService {
  // GitHub repository configuration
  static const String _githubApiUrl = 'https://api.github.com/repos';
  static const String _repoOwner = 'HashTito1';
  static const String _repoName = 'GameLog';
  static const String _branch = 'Update-test-branch';
  
  // Update check preferences
  static const Duration _updateCheckInterval = Duration(hours: 6);
}
```

### Release Requirements

For the update system to work properly, GitHub releases should:

1. **Include APK Files**: Attach `app-release.apk` to releases
2. **Proper Versioning**: Use semantic versioning (v1.1.0, v1.2.0, etc.)
3. **Release Notes**: Include formatted release notes in Markdown
4. **Target Branch**: Releases should target the Update-test-branch

## User Experience

### Update Dialog Flow

1. **Automatic Popup**: Appears 2 seconds after app launch (if update available)
2. **Version Display**: Shows current version vs. available version
3. **Release Notes**: Formatted "What's New" section with key features
4. **Action Options**:
   - **Download Update**: Downloads and installs APK
   - **View on GitHub**: Opens releases page in browser
   - **Skip This Version**: Won't show this version again
   - **Later**: Dismisses dialog, will check again in 6 hours

### Manual Check (About Screen)

1. **Check Button**: Tappable "Check for Updates" tile
2. **Loading State**: Shows spinner while checking
3. **Result Dialogs**:
   - **Update Available**: Full update dialog with download options
   - **Up to Date**: Confirmation that user has latest version
   - **Setup Required**: Instructions for repository configuration
   - **Check Failed**: Error message with troubleshooting tips

## API Integration

### GitHub Releases API

```dart
// API endpoint
GET https://api.github.com/repos/HashTito1/GameLog/releases

// Headers
Accept: application/vnd.github.v3+json
User-Agent: GameLog-App

// Response filtering
- Looks for releases from Update-test-branch
- Falls back to latest release if branch-specific not found
- Extracts download URL from assets[0].browser_download_url
```

### Version Comparison Logic

```dart
bool _isNewerVersion(String remoteVersion, String remoteBuild, 
                    String currentVersion, String currentBuild) {
  // Parse semantic versions (1.2.3 -> [1, 2, 3])
  // Compare major.minor.patch sequentially
  // Fall back to build number comparison if versions equal
  // Return true if remote version is newer
}
```

## Error Handling

### Network Issues
- **Timeout**: 10-second timeout for API calls
- **No Internet**: Graceful failure with user-friendly message
- **API Errors**: Handles 404, 403, and other HTTP errors

### Download Issues
- **Permission Denied**: Requests permissions with explanations
- **Storage Full**: Provides clear error messages
- **Download Failed**: Falls back to GitHub browser link

### Installation Issues
- **Install Permission**: Requests permission for Android 8.0+
- **APK Corruption**: Validates download before installation
- **Installation Failed**: Opens file manager as fallback

## Testing

### Demo Mode

When repository is not configured, the system shows a demo update:

```dart
UpdateInfo _createDemoUpdateInfo() {
  return UpdateInfo(
    version: '1.2.0',
    buildNumber: '5',
    downloadUrl: 'https://github.com/HashTito1/GameLog/releases/...',
    releaseNotes: '''🚀 GameLog v1.2.0 - Major Update!
    
✨ New Features:
- In-app update system with automatic checking
- Enhanced UI with better animations
...''',
    releaseDate: DateTime.now().subtract(const Duration(days: 1)),
    isUpdateAvailable: true,
  );
}
```

### Manual Testing

1. **Force Check**: Use About screen "Check for Updates" button
2. **Clear Preferences**: Reset SharedPreferences to test first-time flow
3. **Version Simulation**: Temporarily modify version comparison logic
4. **Network Simulation**: Test with airplane mode for error handling

## Security Considerations

### APK Verification
- Downloads only from configured GitHub repository
- Validates APK file integrity before installation
- Uses HTTPS for all network communications

### Permissions
- **Storage**: Required for APK download
- **Install Packages**: Required for automatic installation
- **Internet**: Required for update checking

### User Control
- **Skip Versions**: Users can permanently skip unwanted updates
- **Manual Control**: All updates require user confirmation
- **Fallback Options**: Always provides GitHub link as alternative

## Performance

### Optimization Features
- **Interval-Based Checking**: Prevents excessive API calls
- **Background Processing**: Update checks don't block UI
- **Efficient Caching**: Stores check timestamps locally
- **Progressive Loading**: Shows UI immediately, checks updates later

### Resource Usage
- **Network**: ~5KB per update check (GitHub API response)
- **Storage**: ~60MB for downloaded APK (temporary)
- **Memory**: Minimal impact with proper cleanup
- **Battery**: Negligible impact with 6-hour intervals

## Future Enhancements

### Planned Features
- **Delta Updates**: Download only changed files
- **Background Downloads**: Download updates in background
- **Update Scheduling**: Allow users to schedule update times
- **Rollback Support**: Ability to revert to previous versions
- **Multiple Channels**: Support for beta/stable release channels

### Integration Possibilities
- **Firebase Remote Config**: Dynamic update configuration
- **Analytics**: Track update adoption rates
- **Push Notifications**: Notify users of critical updates
- **In-App Purchases**: Premium features for update management

## Troubleshooting

### Common Issues

**Update Check Fails**
- Check internet connection
- Verify repository configuration
- Check GitHub API rate limits

**Download Fails**
- Ensure sufficient storage space
- Check storage permissions
- Verify download URL validity

**Installation Fails**
- Enable "Install from Unknown Sources"
- Check install permissions
- Try manual installation from file manager

**Dialog Not Showing**
- Check if version was previously skipped
- Verify 6-hour interval has passed
- Check for app context issues

### Debug Information

Enable debug logging to see detailed update process:

```dart
// In UpdateService methods
debugPrint('🔍 Checking for updates from GitHub test branch...');
debugPrint('📱 Current version: $currentVersion ($currentBuildNumber)');
debugPrint('🆕 Latest version: ${updateInfo.version} (${updateInfo.buildNumber})');
debugPrint('✅ Update available: $isUpdateAvailable');
```

## Conclusion

The GameLog in-app update system provides a seamless, user-friendly way to keep the app updated with the latest features and bug fixes. It balances automation with user control, ensuring updates are available when needed without being intrusive.

The system is production-ready and can be easily configured for any GitHub repository with proper release management.