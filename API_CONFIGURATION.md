# API Configuration Guide

## Overview

GameLog is designed to work perfectly without any external API keys. The app includes comprehensive mock data that provides a full gaming experience for users.

## Default Behavior (Recommended)

By default, GameLog operates in **offline mode** using:
- 23+ curated mock games including popular titles
- Complete game details and metadata
- Search functionality across all mock data
- Genre and platform filtering
- All app features work normally

## Optional: RAWG API Integration

Developers who want to access live game data from RAWG can optionally configure an API key:

### 1. Get a Free API Key
- Visit [RAWG.io API Documentation](https://rawg.io/apidocs)
- Create a free account
- Generate your API key

### 2. Configure Environment Variable

**For Development:**
```bash
# Set environment variable before running
export RAWG_API_KEY=your_api_key_here
flutter run
```

**For Production Build:**
```bash
# Build with environment variable
flutter build apk --dart-define=RAWG_API_KEY=your_api_key_here
```

### 3. Verification

The app will automatically:
- Use live RAWG data when API key is available
- Fall back to mock data if API fails
- Cache API responses for better performance

## Security Notes

- ✅ No API keys are hardcoded in the source code
- ✅ App functions fully without any API key
- ✅ Environment variables are not committed to version control
- ✅ Mock data provides complete functionality

## Mock Data Features

The included mock data provides:
- Popular games from 2009-2026
- Diverse genres (Action, RPG, Strategy, etc.)
- Multiple platforms (PC, PlayStation, Xbox, Nintendo Switch, Mobile)
- Realistic ratings and review counts
- High-quality game descriptions
- Upcoming games for testing future features

## Troubleshooting

**Q: App shows "offline mode" or limited data**
A: This is normal behavior when no API key is configured. All features still work with mock data.

**Q: Want to use live data**
A: Follow the RAWG API integration steps above.

**Q: API key not working**
A: Verify the key is correct and check RAWG API status. App will automatically fall back to mock data.

---

**Note**: The mock data is carefully curated to provide an excellent user experience without requiring any external dependencies.