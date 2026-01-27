# Firebase Database Structure - Comprehensive Update

## Overview

This document outlines the updated Firebase Firestore database structure that consolidates all user data including profiles, game libraries, ratings, and statistics into a comprehensive, scalable system.

## Database Collections

### 1. `users` Collection
**Primary user profiles with all associated data**

```
users/{userId}
├── id: string                    // User ID (same as document ID)
├── username: string              // Unique username
├── displayName: string           // Display name for UI
├── email: string                 // User email
├── bio: string                   // User biography
├── profileImage: string          // Profile picture URL
├── bannerImage: string           // Banner image URL
├── favoriteGame: object          // Favorite game data
│   ├── gameId: string
│   ├── gameName: string
│   ├── gameImage: string
│   └── updatedAt: timestamp
├── playlists: array              // User-created playlists
│   └── [playlist objects]
├── preferences: object           // User preferences
├── stats: object                 // Computed statistics
│   ├── library: object
│   │   ├── totalGames: number
│   │   ├── wantToPlay: number
│   │   ├── playing: number
│   │   ├── completed: number
│   │   ├── dropped: number
│   │   ├── onHold: number
│   │   ├── totalHoursPlayed: number
│   │   └── favoriteGenres: object
│   ├── ratings: object
│   │   ├── totalRatings: number
│   │   ├── averageRating: number
│   │   ├── ratingDistribution: object
│   │   └── recommendedGames: number
│   └── lastUpdated: timestamp
├── followers: number             // Follower count
├── following: number             // Following count
├── joinDate: timestamp           // Account creation date
├── createdAt: timestamp          // Profile creation
├── updatedAt: timestamp          // Last profile update
├── lastActiveAt: timestamp       // Last activity
└── isOnline: boolean             // Online status

// Subcollections:
├── library/{gameId}              // User's game library
└── ratings/{gameId}              // User's game ratings
```

### 2. `users/{userId}/library` Subcollection
**Individual game entries in user's library**

```
users/{userId}/library/{gameId}
├── id: string                    // Entry ID (userId_gameId)
├── userId: string                // User ID
├── gameId: string                // Game ID
├── gameTitle: string             // Game title
├── gameCoverImage: string        // Game cover image URL
├── gameDeveloper: string         // Game developer
├── gameReleaseDate: string       // Game release date
├── gameGenres: array<string>     // Game genres
├── gamePlatforms: array<string>  // Game platforms
├── status: string                // want_to_play, playing, completed, dropped, on_hold
├── userRating: number            // User's rating (0-5)
├── userReview: string            // User's review text
├── hoursPlayed: number           // Hours played
├── startedDate: timestamp        // Date started playing
├── completedDate: timestamp      // Date completed
├── customData: object            // Custom user data
├── dateAdded: timestamp          // Date added to library
├── dateUpdated: timestamp        // Last update
└── lastModified: timestamp       // Last modification
```

### 3. `users/{userId}/ratings` Subcollection
**Individual game ratings by user**

```
users/{userId}/ratings/{gameId}
├── id: string                    // Rating ID (userId_gameId)
├── userId: string                // User ID
├── gameId: string                // Game ID
├── gameTitle: string             // Game title
├── rating: number                // Rating (0-5, supports 0.5 increments)
├── review: string                // Review text
├── tags: array<string>           // User-defined tags
├── isRecommended: boolean        // Whether user recommends
├── containsSpoilers: boolean     // Whether review contains spoilers
├── customData: object            // Custom rating data
├── createdAt: timestamp          // Rating creation
├── updatedAt: timestamp          // Last update
└── lastModified: timestamp       // Last modification
```

### 4. `user_library` Collection (Global)
**Global library entries for easier querying**

```
user_library/{userId_gameId}
// Same structure as users/{userId}/library/{gameId}
// Used for cross-user queries and analytics
```

### 5. `user_ratings` Collection (Global)
**Global rating entries for easier querying**

```
user_ratings/{userId_gameId}
// Same structure as users/{userId}/ratings/{gameId}
// Used for cross-user queries and game statistics
```

## Key Features

### 1. **Hierarchical Data Structure**
- User data is organized hierarchically with subcollections
- Enables efficient queries and data organization
- Supports both user-specific and global queries

### 2. **Comprehensive Game Library**
- Multiple status types: want_to_play, playing, completed, dropped, on_hold
- Detailed tracking: hours played, start/completion dates
- Custom data support for extensibility

### 3. **Advanced Rating System**
- Half-star ratings (0.5 increments)
- Review system with spoiler warnings
- Recommendation tracking
- User-defined tags

### 4. **Real-time Statistics**
- Automatically computed user statistics
- Library statistics (games by status, hours played, favorite genres)
- Rating statistics (average rating, distribution, recommendations)
- Cached for performance

### 5. **Profile Management**
- Complete user profiles with images
- Social features (followers, following)
- Favorite games and playlists
- User preferences

## API Methods

### User Profile Management
```dart
// Create or update user profile
await UserDataService.createOrUpdateUserProfile(
  userId: userId,
  username: 'username',
  displayName: 'Display Name',
  profileImageUrl: 'https://...',
  bannerImageUrl: 'https://...',
);

// Get complete user profile with stats
final profile = await UserDataService.getCompleteUserProfile(userId);
```

### Library Management
```dart
// Add/update game in library
await UserDataService.updateUserLibraryEntry(
  userId: userId,
  gameId: gameId,
  gameTitle: 'Game Title',
  status: 'playing',
  rating: 4.5,
  hoursPlayed: 25,
);

// Get user's library with filtering
final library = await UserDataService.getUserLibrary(
  userId,
  status: 'completed',
  orderBy: 'completedDate',
);
```

### Rating Management
```dart
// Submit rating
await UserDataService.submitUserRating(
  userId: userId,
  gameId: gameId,
  gameTitle: 'Game Title',
  rating: 4.5,
  review: 'Great game!',
  isRecommended: true,
);

// Get user's ratings
final ratings = await UserDataService.getUserRatings(userId);
```

## Migration

### Automatic Migration
The system includes automatic migration from the old database structure:

```dart
// Migrate single user
await DatabaseMigrationService.migrateUserData(userId);

// Migrate all users
await DatabaseMigrationService.migrateAllUsers();

// Verify migration
final report = await DatabaseMigrationService.verifyMigration(userId);
```

### Migration Process
1. **Profile Migration**: Updates user profiles to new structure
2. **Library Migration**: Converts old library entries to new format
3. **Rating Migration**: Migrates ratings with enhanced metadata
4. **Statistics Generation**: Computes initial statistics
5. **Verification**: Validates migration integrity

## Performance Optimizations

### 1. **Subcollections**
- User data is organized in subcollections for better performance
- Enables efficient pagination and filtering
- Reduces document size limits

### 2. **Dual Storage**
- Data stored in both user subcollections and global collections
- User subcollections for user-specific queries
- Global collections for cross-user analytics

### 3. **Computed Statistics**
- Statistics are pre-computed and cached
- Updated automatically when data changes
- Reduces real-time computation overhead

### 4. **Efficient Queries**
- Indexed fields for common queries
- Optimized query patterns
- Minimal data transfer

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Users can read their own library and ratings
      match /library/{gameId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /ratings/{gameId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Global collections - read access for all authenticated users
    match /user_library/{entryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    match /user_ratings/{ratingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}
```

## Benefits

### 1. **Scalability**
- Hierarchical structure supports millions of users
- Efficient querying and indexing
- Subcollections prevent document size limits

### 2. **Flexibility**
- Extensible data structure
- Custom data fields for future features
- Multiple status types and metadata

### 3. **Performance**
- Pre-computed statistics
- Efficient query patterns
- Optimized data access

### 4. **Data Integrity**
- Consistent data structure
- Automatic validation
- Migration tools for data consistency

### 5. **User Experience**
- Rich user profiles
- Comprehensive game tracking
- Advanced rating system
- Real-time statistics

## Implementation Status

- ✅ Enhanced UserDataService with new methods
- ✅ Database migration service
- ✅ Comprehensive data structure
- ✅ Statistics computation
- ✅ Legacy compatibility methods
- 🔄 UI updates to use new methods (in progress)
- 🔄 Security rules implementation (pending)
- 🔄 Performance monitoring (pending)

This new database structure provides a solid foundation for the gaming app with comprehensive user data management, efficient querying, and room for future enhancements.