# 📦 GitHub Release Setup Guide

## Creating Releases for GameLog Update System

This guide explains how to create GitHub releases that work with GameLog's in-app update system.

## Prerequisites

1. **Repository Access**: Push access to the GameLog repository
2. **APK File**: Built release APK file (`app-release.apk`)
3. **Version Information**: Semantic version number (e.g., v1.1.0)
4. **Release Notes**: Formatted changelog in Markdown

## Step-by-Step Release Process

### 1. Build Release APK

```bash
# Clean and build release APK
flutter clean
flutter pub get
flutter build apk --release

# APK will be created at: build/app/outputs/flutter-apk/app-release.apk
```

### 2. Create GitHub Release

#### Via GitHub Web Interface

1. **Navigate to Releases**
   - Go to your repository on GitHub
   - Click on "Releases" in the right sidebar
   - Click "Create a new release"

2. **Configure Release**
   - **Tag version**: `v1.1.0` (must start with 'v')
   - **Target branch**: `Update-test-branch`
   - **Release title**: `GameLog v1.1.0 - Major Update`

3. **Add Release Notes**
   ```markdown
   🚀 GameLog v1.1.0 - Major Performance & Feature Update

   ✨ New Features:
   - Complete IGDB API integration (replaced RAWG)
   - In-app update system with automatic checking
   - Google Play Store inspired homepage UI
   - Personalized game recommendations
   - Enhanced forum system with admin controls

   🔧 Performance Optimizations:
   - Fixed CategoryGamesScreen overflow issues
   - Added loading state protection
   - Updated deprecated Switch widgets
   - Font tree-shaking enabled (99.1% reduction)
   - Enhanced caching system

   🎨 UI/UX Improvements:
   - Compact homepage layout with carousel
   - Theme-aware components throughout
   - Better aspect ratios and constraints
   - Notification bell with badge

   🐛 Bug Fixes:
   - Resolved duplicate games issue
   - Fixed search functionality
   - Corrected genre names to match IGDB
   - Improved error handling

   📊 Technical Details:
   - APK size: 55.87 MB (optimized)
   - 68 Dart files, 26,218 lines of code
   - Production-ready release build
   ```

4. **Upload APK File**
   - Drag and drop `app-release.apk` into the assets section
   - Or click "Attach binaries" and select the APK file
   - File should be named exactly `app-release.apk`

5. **Publish Release**
   - Check "This is a pre-release" if it's a beta version
   - Click "Publish release"

#### Via GitHub CLI

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Create release with APK
gh release create v1.1.0 \
  --target Update-test-branch \
  --title "GameLog v1.1.0 - Major Update" \
  --notes-file RELEASE_NOTES.md \
  build/app/outputs/flutter-apk/app-release.apk
```

### 3. Verify Release

1. **Check Release Page**
   - Visit: `https://github.com/HashTito1/GameLog/releases`
   - Verify release appears with correct version
   - Confirm APK file is attached and downloadable

2. **Test API Response**
   ```bash
   # Test GitHub API endpoint
   curl -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/HashTito1/GameLog/releases
   ```

3. **Test In-App Update**
   - Open GameLog app
   - Go to Settings > About
   - Tap "Check for Updates"
   - Verify update dialog appears with correct information

## Release Notes Format

### Recommended Structure

```markdown
🚀 GameLog v1.1.0 - [Brief Description]

✨ New Features:
- Feature 1 description
- Feature 2 description
- Feature 3 description

🔧 Performance Improvements:
- Performance improvement 1
- Performance improvement 2
- Performance improvement 3

🎨 UI/UX Improvements:
- UI improvement 1
- UI improvement 2
- UI improvement 3

🐛 Bug Fixes:
- Bug fix 1
- Bug fix 2
- Bug fix 3

📊 Technical Details:
- APK size: XX.XX MB
- Lines of code: X,XXX
- Build status: Production-ready
```

### Emoji Guide

- 🚀 Major releases/launches
- ✨ New features
- 🔧 Performance improvements
- 🎨 UI/UX changes
- 🐛 Bug fixes
- 📊 Technical details
- 🔒 Security updates
- 📱 Mobile-specific changes
- 🌐 Web-specific changes
- 📚 Documentation updates

## Version Numbering

### Semantic Versioning (SemVer)

Follow semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes or major feature additions
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Examples

- `v1.0.0` - Initial release
- `v1.0.1` - Bug fix release
- `v1.1.0` - New features added
- `v2.0.0` - Major update with breaking changes

### Build Numbers

- Increment build number with each release
- Format: `version+build` (e.g., `1.1.0+4`)
- Update in `pubspec.yaml` before building

## Automation Options

### GitHub Actions Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Create Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-release:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.x'
    
    - name: Build APK
      run: |
        flutter pub get
        flutter build apk --release
    
    - name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        files: build/app/outputs/flutter-apk/app-release.apk
        body_path: RELEASE_NOTES.md
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Release Script

Create `scripts/create_release.sh`:

```bash
#!/bin/bash

# Get version from pubspec.yaml
VERSION=$(grep "version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
BUILD=$(grep "version:" pubspec.yaml | cut -d'+' -f2)

echo "Creating release for version v$VERSION (build $BUILD)"

# Build APK
echo "Building APK..."
flutter clean
flutter pub get
flutter build apk --release

# Create release
echo "Creating GitHub release..."
gh release create "v$VERSION" \
  --target Update-test-branch \
  --title "GameLog v$VERSION - Update" \
  --notes-file RELEASE_NOTES.md \
  build/app/outputs/flutter-apk/app-release.apk

echo "Release created successfully!"
```

## Best Practices

### Before Creating Release

1. **Test Thoroughly**
   - Test on multiple devices
   - Verify all features work
   - Check for crashes or major bugs

2. **Update Version**
   - Increment version in `pubspec.yaml`
   - Update build number
   - Commit version changes

3. **Prepare Release Notes**
   - Document all changes
   - Use clear, user-friendly language
   - Include technical details for developers

### Release Timing

1. **Avoid Peak Hours**
   - Don't release during high-usage times
   - Consider user time zones

2. **Test Branch First**
   - Always release to test branch first
   - Verify update system works correctly
   - Get feedback before main branch

3. **Staged Rollout**
   - Consider releasing to small group first
   - Monitor for issues before full rollout

### Post-Release

1. **Monitor Feedback**
   - Watch for user reports
   - Monitor crash analytics
   - Check download statistics

2. **Quick Fixes**
   - Be prepared for hotfix releases
   - Have rollback plan if needed
   - Communicate issues transparently

## Troubleshooting

### Common Issues

**APK Not Downloading**
- Check file size (GitHub has 2GB limit)
- Verify file is named `app-release.apk`
- Ensure file is actually attached to release

**Update Not Detected**
- Verify version number is higher than current
- Check semantic versioning format
- Confirm release targets correct branch

**API Rate Limiting**
- GitHub API has rate limits
- Use authentication for higher limits
- Consider caching responses

### Debug Commands

```bash
# Check release API response
curl -s https://api.github.com/repos/HashTito1/GameLog/releases | jq '.[0]'

# Verify APK download URL
curl -I https://github.com/HashTito1/GameLog/releases/download/v1.1.0/app-release.apk

# Test version comparison
echo "Current: 1.0.3, Remote: 1.1.0" | awk '{print ($4 > $2) ? "Update available" : "Up to date"}'
```

## Security Considerations

### APK Signing

- Always use release signing for production APKs
- Keep signing keys secure and backed up
- Consider using Play App Signing for additional security

### Download Security

- APKs are served over HTTPS from GitHub
- Users should verify app signature before installing
- Consider adding checksum verification

### Access Control

- Limit who can create releases
- Use branch protection rules
- Require reviews for release PRs

## Conclusion

Following this guide ensures that your GitHub releases work seamlessly with GameLog's in-app update system. Consistent versioning, proper APK attachment, and well-formatted release notes provide users with a smooth update experience.

Remember to test the update flow thoroughly before releasing to ensure users can successfully download and install updates.