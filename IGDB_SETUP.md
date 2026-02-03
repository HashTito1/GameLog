# IGDB API Setup Guide

This app now uses IGDB (Internet Game Database) instead of RAWG for game data. IGDB provides more comprehensive and reliable game information.

## Getting IGDB API Credentials

1. **Create a Twitch Developer Account**
   - Go to [Twitch Developer Console](https://dev.twitch.tv/console)
   - Log in with your Twitch account (create one if needed)

2. **Register Your Application**
   - Click "Register Your Application"
   - Fill in the required fields:
     - **Name**: Your app name (e.g., "GameLog App")
     - **OAuth Redirect URLs**: 
       - Development: `http://localhost`
       - Production: `https://yourdomain.com/auth/callback` (if you have a web version)
       - Mobile: Not needed for Client Credentials Flow
     - **Category**: Choose "Game Integration" or "Application Integration"
   - Click "Create"

3. **Get Your Credentials**
   - After creating the app, you'll see your **Client ID** - copy this
   - **For Public Clients**: You don't need a Client Secret (which is perfect for mobile apps!)
   - **For Confidential Clients**: You would need to click "New Secret" to generate a Client Secret

4. **Get Access Token**
   Since you chose "Public" client type, you only need the Client ID:

   **Method 1: Using curl (Command Line)**
   ```bash
   curl -X POST 'https://id.twitch.tv/oauth2/token' \
   -H 'Content-Type: application/x-www-form-urlencoded' \
   -d 'client_id=YOUR_CLIENT_ID&grant_type=client_credentials'
   ```

   **Method 2: Using Postman or similar tool**
   - URL: `https://id.twitch.tv/oauth2/token`
   - Method: POST
   - Headers: `Content-Type: application/x-www-form-urlencoded`
   - Body (form-data):
     - `client_id`: YOUR_CLIENT_ID
     - `grant_type`: client_credentials

   **Method 3: Using PowerShell (Windows)**
   ```powershell
   $body = @{
       client_id = "YOUR_CLIENT_ID"
       grant_type = "client_credentials"
   }
   Invoke-RestMethod -Uri "https://id.twitch.tv/oauth2/token" -Method Post -Body $body
   ```

   The response will contain an `access_token` - this is what you need for IGDB!

## Configuring the App

1. **Update the IGDB Service**
   - Open `lib/services/igdb_service.dart`
   - Replace the placeholder values:
     ```dart
     static const String _clientId = 'YOUR_TWITCH_CLIENT_ID';
     static const String _accessToken = 'YOUR_TWITCH_ACCESS_TOKEN';
     ```

2. **Alternative: Environment Variables (Recommended)**
   - Instead of hardcoding credentials, you can use environment variables
   - Update the service to read from environment:
     ```dart
     static const String _clientId = String.fromEnvironment('TWITCH_CLIENT_ID', defaultValue: '');
     static const String _accessToken = String.fromEnvironment('TWITCH_ACCESS_TOKEN', defaultValue: '');
     ```

## Important Notes

- **OAuth Redirect**: For mobile apps using Client Credentials Flow, the redirect URL is not used
- **Production URLs**: Only needed if you implement user authentication or web deployment
- **Access Token Expiry**: Twitch access tokens expire. You'll need to refresh them periodically
- **Rate Limits**: IGDB has rate limits (4 requests per second for free tier)
- **Security**: Never commit your credentials to version control
- **Production**: For production apps, implement proper token refresh logic

## Benefits of IGDB over RAWG

- More comprehensive game database
- Better image quality and availability
- More accurate game metadata
- Active maintenance and updates
- Better search functionality
- More detailed game information

## Troubleshooting

- **401 Unauthorized**: Check your Client ID and Access Token
- **403 Forbidden**: Your access token may have expired
- **429 Too Many Requests**: You're hitting rate limits, implement request throttling
- **Empty Results**: IGDB uses different genre names than RAWG, check genre mappings

For more information, visit the [IGDB API Documentation](https://api-docs.igdb.com/).