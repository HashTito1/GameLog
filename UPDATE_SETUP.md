# Update Service Setup Guide

This guide explains how to set up the automatic update functionality for GameLog.

## Overview

The update service allows users to check for and install updates directly from the app by connecting to your GitHub repository's test branch.

## Setup Steps

### 1. Configure Repository Information

Edit `lib/services/update_service.dart` and replace the placeholder values:

```dart
static const String _repoOwner = 'YOUR_GITHUB_USERNAME'; // Replace with your GitHub username
static const String _repoName = 'YOUR_REPO_NAME'; // Replace with your repository name
static const String _branch = 'test'; // The branch to check for updates
```

**Example:**
```dart
static const String _repoOwner = 'johndoe';
static const String _repoName = 'gamelog-app';
static const String _branch = 'test';
```

### 2. Create GitHub Releases

To make updates available:

1. **Create a test branch** in your repository (if not already exists)
   ```bash
   git checkout -b Update-test-branch
   git push origin Update-test-branch
   ```

2. **Create releases** on GitHub with the following requirements:

   **Tag Format (REQUIRED):**
   - Use semantic versioning: `v1.0.1`, `v1.1.0`, `v2.0.0`
   - Must start with `v` followed by version numbers
   - Examples: `v1.0.1`, `v1.2.0`, `v2.0.0`

   **Release Creation Steps:**
   1. Go to your GitHub repository
   2. Click "Releases" → "Create a new release"
   3. **Tag version**: Enter a valid tag (e.g., `v1.0.1`)
   4. **Target**: Select `Update-test-branch` 
   5. **Release title**: Enter a descriptive title (e.g., "GameLog v1.0.1")
   6. **Description**: Add release notes describing changes
   7. **Attach APK**: Upload your built APK file
   8. **Pre-release**: Check this box for test releases
   9. Click "Publish release"

   **Valid Tag Examples:**
   ```
   ✅ v1.0.1    (Correct format)
   ✅ v1.2.0    (Correct format)  
   ✅ v2.0.0    (Correct format)
   ❌ 1.0.1     (Missing 'v' prefix)
   ❌ v1.0      (Incomplete version)
   ❌ release1  (Not semantic versioning)
   ```

### 3. Release Naming Convention

For proper version comparison, use semantic versioning:

**Version Format Requirements:**
- **Tag format**: `v1.0.0` (major.minor.patch with 'v' prefix)
- **Build number**: Increment for each build (1, 2, 3, etc.)
- **Target branch**: `Update-test-branch` (or mark as pre-release)

**Version Examples:**
```
v1.0.0  → Initial release
v1.0.1  → Bug fix update  
v1.1.0  → New features
v2.0.0  → Major update
```

**GitHub Release Settings:**
- ✅ Tag version: `v1.0.1`
- ✅ Target: `Update-test-branch`
- ✅ Pre-release: Checked (for test releases)
- ✅ Release title: "GameLog v1.0.1"
- ✅ APK attached as asset

### 4. APK Upload and Build Process

**Building the APK:**
```bash
# Build release APK
flutter build apk --release

# APK will be created at:
# build/app/outputs/flutter-apk/app-release.apk
```

**Upload to GitHub Release:**
1. Build your APK using the command above
2. Go to your GitHub release page
3. Click "Attach binaries by dropping them here or selecting them"
4. Upload the `app-release.apk` file
5. The update service will automatically detect and download this file

**File Naming:**
- Keep the default name `app-release.apk` or use descriptive names
- The update service will use the first APK asset found in the release

### 5. Testing the Update System

1. **Lower your app version** temporarily in `pubspec.yaml`
2. **Create a test release** with a higher version number
3. **Test the update flow** in the About screen

## How It Works

### Update Check Process

1. User taps "Check for Updates" in About screen
2. App queries GitHub API for latest releases
3. Compares current version with latest release version
4. Shows update dialog if newer version is available

### Update Installation Process

1. User chooses to update
2. App downloads APK from GitHub release assets
3. App requests install permissions
4. System installer opens to install the update

## Permissions Required

The following permissions are automatically added to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

## Platform Support

- ✅ **Android**: Full support with automatic APK installation
- ❌ **iOS**: Not supported (App Store restrictions)
- ⚠️ **Web**: Redirects to GitHub releases page

## Security Considerations

1. **HTTPS Only**: All downloads use HTTPS
2. **Permission Requests**: Users must grant install permissions
3. **Manual Verification**: Users can verify APK before installing
4. **Fallback**: If auto-install fails, opens file manager for manual install

## Troubleshooting

### Common Issues

1. **"Tag name can't be blank" or "tag name is not well-formed"**
   - ✅ Use format: `v1.0.1` (with 'v' prefix)
   - ✅ Use three numbers: major.minor.patch
   - ❌ Don't use: `1.0.1`, `v1.0`, `release1`
   - ❌ Don't leave tag field empty

2. **"No releases found"**
   - Check repository name and owner are correct
   - Ensure releases exist on GitHub
   - Verify internet connection

3. **"Download failed"**
   - Check APK file is uploaded to release
   - Verify file is accessible (not private repository)
   - Check device storage space

4. **"Install permission denied"**
   - User needs to enable "Install from unknown sources"
   - Grant install permissions when prompted

### Testing Without GitHub

For testing, you can temporarily modify the update service to use a local server or different API endpoint.

## Example Release Workflow

1. **Develop features** on main branch
2. **Merge to test branch** when ready for testing
3. **Create GitHub release** targeting test branch
4. **Upload APK** as release asset
5. **Users check for updates** in app
6. **Users install update** directly from app

## API Rate Limits

GitHub API has rate limits:
- **Unauthenticated**: 60 requests per hour per IP
- **Authenticated**: 5000 requests per hour (if you add GitHub token)

For production apps with many users, consider implementing GitHub authentication or caching.