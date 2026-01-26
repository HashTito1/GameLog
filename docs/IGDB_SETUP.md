# IGDB API Setup Guide

This guide will help you set up the IGDB (Internet Game Database) API integration for GameLog.

## Prerequisites

1. A Twitch account (IGDB uses Twitch authentication)
2. Flutter development environment set up

## Step 1: Create a Twitch Application

1. Go to [Twitch Developer Console](https://dev.twitch.tv/console/apps)
2. Click "Register Your Application"
3. Fill in the application details:
   - **Name**: GameLog (or your preferred app name)
   - **OAuth Redirect URLs**: `http://localhost` (for development)
   - **Category**: Game Integration
4. Click "Create"
5. Note down your **Client ID** and **Client Secret**

## Step 2: Get Access Token

You need to get an access token using the client credentials flow. You can do this in several ways:

### Option A: Using curl (Command Line)
```bash
curl -X POST 'https://id.twitch.tv/oauth2/token' \
-H 'Content-Type: application/x-www-form-urlencoded' \
-d 'client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&grant_type=client_credentials'
```

### Option B: Using Postman or similar tool
- **Method**: POST
- **URL**: `https://id.twitch.tv/oauth2/token`
- **Headers**: `Content-Type: application/x-www-form-urlencoded`
- **Body** (form-urlencoded):
  - `client_id`: YOUR_CLIENT_ID
  - `client_secret`: YOUR_CLIENT_SECRET
  - `grant_type`: client_credentials

### Option C: Using the app's built-in method
The app includes an `IGDBAuth.getAccessToken()` method that you can call programmatically.

## Step 3: Configure the App

1. Open `lib/config/api_config.dart`
2. Replace the placeholder values:
   ```dart
   static const String igdbClientId = 'YOUR_ACTUAL_CLIENT_ID';
   static const String igdbClientSecret = 'YOUR_ACTUAL_CLIENT_SECRET';
   static const String igdbAccessToken = 'YOUR_ACTUAL_ACCESS_TOKEN';
   ```

## Step 4: Test the Integration

1. Run the app: `flutter run`
2. Navigate to the Search screen
3. Try searching for a game
4. Check the Home screen for trending games

## Important Notes

- **Access Token Expiration**: Access tokens expire after approximately 60 days
- **Rate Limits**: IGDB has rate limits (4 requests per second)
- **Security**: Never commit your actual credentials to version control
- **Production**: Consider using environment variables or secure storage for credentials

## Troubleshooting

### Common Issues:

1. **401 Unauthorized**: Check your Client ID and Access Token
2. **403 Forbidden**: Your access token might be expired
3. **429 Too Many Requests**: You're hitting rate limits, implement request throttling
4. **Network errors**: Check your internet connection and API endpoints

### Fallback Behavior:

The app is designed to fall back to mock data if the IGDB API is unavailable, so it will still function during development even without proper API setup.

## API Documentation

- [IGDB API Documentation](https://api-docs.igdb.com/)
- [Twitch Authentication](https://dev.twitch.tv/docs/authentication/)

## Example API Response

When properly configured, you'll see real game data with:
- Actual game titles and cover images
- Real ratings and review counts
- Proper developer/publisher information
- Genre and platform data
- Release dates

The app will automatically display cover images, ratings, and other metadata from the IGDB database.