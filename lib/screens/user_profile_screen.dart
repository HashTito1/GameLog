import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/igdb_service.dart';
import '../services/library_service.dart';
import '../services/friends_service.dart';
import '../services/follow_service.dart';
import '../services/rating_service.dart';
import '../models/user_rating.dart';
import '../utils/date_format.dart';
import '../widgets/chat_list.dart';
import 'game_detail_screen.dart';
import '../models/game.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  Game? _favoriteGame;
  List<Map<String, dynamic>> _userPlaylists = [];
  List<UserRating> _ratings = [];
  bool _ratingsLoaded = false;
  int _userRatingsCount = 0;
  double _userAverageRating = 0.0;
  bool _isCurrentUser = false;
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  bool _isLoadingAction = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  
  // Real-time social data
  int _realTimeFollowers = 0;
  int _realTimeFollowing = 0;
  StreamSubscription? _followersSubscription;
  StreamSubscription? _followingSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeListeners() {
    // Listen to followers count changes
    _followersSubscription = UserDataService.getUserFollowersStream(widget.userId).listen((followers) {
      if (mounted) {
        setState(() {
          _realTimeFollowers = followers.length;
        });
      }
    });

    // Listen to following count changes
    _followingSubscription = UserDataService.getUserFollowingStream(widget.userId).listen((following) {
      if (mounted) {
        setState(() {
          _realTimeFollowing = following.length;
        });
      }
    });
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        // Check if this is the current user's profile
        _isCurrentUser = currentUser.uid == widget.userId;
        
        debugPrint('Loading user profile for userId: ${widget.userId}');
        final userData = await UserDataService.getUserProfile(widget.userId);
        debugPrint('Raw user data from Firestore: $userData');
        
        if (userData == null) {
          debugPrint('User data is null, user might not exist in Firestore');
          // Try to get user data from Firebase Auth if it's the current user
          if (_isCurrentUser) {
            debugPrint('This is current user, creating profile from Firebase Auth data');
            final firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser != null) {
              // Create user profile in Firestore from Firebase Auth data
              final profileData = {
                'id': firebaseUser.uid,
                'username': firebaseUser.email?.split('@')[0] ?? 'user',
                'displayName': firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
                'email': firebaseUser.email ?? '',
                'bio': '',
                'profileImage': '',
                'bannerImage': '',
                'gamesPlayed': 0,
                'reviewsWritten': 0,
                'followers': 0,
                'following': 0,
                'joinDate': firebaseUser.metadata.creationTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
                'createdAt': firebaseUser.metadata.creationTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
                'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
                'isOnline': true,
              };
              
              await UserDataService.saveUserProfile(firebaseUser.uid, profileData);
              setState(() {
                _userData = profileData;
              });
              debugPrint('Created new user profile: $profileData');
            }
          }
        } else {
          setState(() {
            _userData = userData;
            // Initialize real-time counters with current data
            _realTimeFollowers = userData['followers'] ?? 0;
            _realTimeFollowing = userData['following'] ?? 0;
          });
          debugPrint('User data loaded successfully');
          debugPrint('Display name: ${userData['displayName']}');
          debugPrint('Username: ${userData['username']}');
        }

        // Load favorite game if exists
        if (_userData != null && _userData!['favoriteGame'] != null) {
          final favoriteGameData = _userData!['favoriteGame'] as Map<String, dynamic>;
          final gameId = favoriteGameData['gameId']?.toString();
          if (gameId != null) {
            try {
              final game = await IGDBService.instance.getGameDetails(gameId);
              setState(() {
                _favoriteGame = game;
              });
            } catch (e) {
              debugPrint('Error loading favorite game: $e');
            }
          }
        }

        // Load user playlists
        if (_userData != null) {
          final currentUser = FirebaseAuthService().currentUser;
          final playlists = await UserDataService.getUserPlaylistsWithGamesFiltered(
            widget.userId, 
            currentUserId: currentUser?.uid,
          );
          setState(() {
            _userPlaylists = playlists;
          });
        }

        // Ratings feed the Recommends and Recent reviews sections.
        _loadRatings();

        // Load user rating stats
        await _loadUserRatingStats(widget.userId);

        // Load friendship status if not current user
        if (!_isCurrentUser) {
          final friendshipStatus = await FriendsService.getFriendshipStatus(currentUser.uid, widget.userId);
          final isFollowing = await FollowService.isFollowing(widget.userId);
          setState(() {
            _friendshipStatus = friendshipStatus;
            _isFollowing = isFollowing;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRatings() async {
    final ratings = await RatingService.getUserRecentRatings(widget.userId, limit: 200);
    if (!mounted) return;
    setState(() {
      _ratings = ratings;
      _ratingsLoaded = true;
      // Someone else's library is private, so their library stats come back
      // empty; ratings are public, so count and average those instead.
      if (!_isCurrentUser && ratings.isNotEmpty) {
        _userRatingsCount = ratings.length;
        _userAverageRating = ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;
        final libraryStats = (_userData?['stats'] as Map?)?['library'] as Map?;
        final logged = (libraryStats?['totalGames'] as num?)?.toInt() ?? 0;
        if (_userData != null) {
          _userData!['gamesPlayed'] = logged > ratings.length ? logged : ratings.length;
        }
      }
    });
  }

  Future<void> _loadUserRatingStats(String userId) async {
    try {
      // Another user's library is private; their ratings fill the stats in
      // instead (see _loadRatings).
      if (!_isCurrentUser) return;
      final stats = await LibraryService.instance.getUserLibraryStats(userId);
      
      setState(() {
        // Update the user data with stats from library service
        if (_userData != null) {
          _userData!['gamesPlayed'] = stats['totalGames'] ?? 0;
        }
        _userRatingsCount = stats['ratedGames'] ?? 0;
        _userAverageRating = (stats['averageRating'] ?? 0.0).toDouble();
      });
    } catch (e) {
      debugPrint('Error loading user rating stats: $e');
      setState(() {
        _userRatingsCount = 0;
        _userAverageRating = 0.0;
      });
    }
  }

  void _showPlaylistOptions(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    playlist['name'] ?? 'Untitled Playlist',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                playlist['isPublic'] == true ? Icons.lock : Icons.public,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                playlist['isPublic'] == true ? 'Make Private' : 'Make Public',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                playlist['isPublic'] == true 
                    ? 'Only you will be able to see this playlist'
                    : 'Others will be able to see this playlist on your profile',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () => _togglePlaylistPrivacy(playlist),
            ),
            ListTile(
              leading: Icon(
                Icons.visibility,
                color: theme.colorScheme.secondary,
              ),
              title: const Text(
                'View Playlist',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistDialog(playlist);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlaylistPrivacy(Map<String, dynamic> playlist) async {
    try {
      Navigator.pop(context); // Close bottom sheet
      
      final newPrivacy = !(playlist['isPublic'] == true);
      
      await UserDataService.updatePlaylistPrivacy(
        widget.userId,
        playlist['id'],
        newPrivacy,
      );
      
      if (!mounted) return;
      // Update local state
      setState(() {
        playlist['isPublic'] = newPrivacy;
      });
      
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPrivacy 
                ? 'Playlist is now public' 
                : 'Playlist is now private',
          ),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update playlist privacy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPlaylistDialog(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      color: theme.colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist['name'] ?? 'Untitled Playlist',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (playlist['description'] != null && playlist['description'].toString().isNotEmpty)
                            Text(
                              playlist['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Games list
              Expanded(
                child: _buildPlaylistGames(playlist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistGames(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
    
    if (games.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_remove,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'This playlist is empty',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop(); // Close dialog first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameDetailScreen(
                    gameId: game['gameId'] ?? game['id'] ?? '',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: game['coverImage'] != null && game['coverImage'].toString().isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: game['coverImage'],
                            width: 50,
                            height: 66,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 50,
                              height: 66,
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 50,
                              height: 66,
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                              child: Icon(
                                Icons.videogame_asset,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 66,
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            child: Icon(
                              Icons.videogame_asset,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game['title'] ?? game['name'] ?? 'Unknown Game',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (game['developer'] != null && game['developer'].toString().isNotEmpty)
                          Text(
                            game['developer'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        if (game['releaseDate'] != null && game['releaseDate'].toString().isNotEmpty)
                          Text(
                            game['releaseDate'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'User Profile',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'User Profile',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'User not found',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
          ),
        ),
      );
    }

    // Extract user data with better fallback logic
    final username = _userData?['username'] ?? _userData?['email']?.split('@')[0] ?? 'user';
    final displayName = _userData?['displayName'] ?? 
                       _userData?['username'] ?? 
                       _userData?['email']?.split('@')[0] ?? 
                       'User';
    final profileImage = _userData?['profileImage'] ?? '';
    final bannerImage = _userData?['bannerImage'] ?? '';
    final gamesPlayed = _userData?['gamesPlayed'] ?? 0;
    final followers = _realTimeFollowers; // Use real-time data instead of static data
    final following = _realTimeFollowing; // Use real-time data instead of static data

    debugPrint('Displaying user profile:');
    debugPrint('Username: $username');
    debugPrint('Display Name: $displayName');
    debugPrint('Profile Image: $profileImage');
    debugPrint('Banner Image: $bannerImage');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(bannerImage, profileImage, displayName, username),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIdentity(followers, following),
                if (!_isCurrentUser) _buildActionRow(),
                const SizedBox(height: 20),
                _buildStatsSection(gamesPlayed, _userRatingsCount, _userAverageRating),
                const SizedBox(height: 24),
                if (_isCurrentUser || _favoriteGame != null) ...[
                  _buildFavoriteGameSection(),
                  const SizedBox(height: 24),
                ],
                _buildRecommendsSection(),
                const SizedBox(height: 24),
                _buildPlaylistsSection(),
                const SizedBox(height: 24),
                _buildRecentReviewsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String bannerImage, String profileImage, String displayName, String username) {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner Background
            Container(
              decoration: BoxDecoration(
                gradient: (bannerImage.isEmpty)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.tertiary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                image: bannerImage.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(bannerImage),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          debugPrint('Error loading banner image: $exception');
                        },
                      )
                    : null,
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Profile content
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Profile Picture - Full circle, not cropped
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profileImage.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: profileImage,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              errorWidget: (context, url, error) => _buildDefaultAvatar(displayName),
                            )
                          : _buildDefaultAvatar(displayName),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name and username
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildDefaultAvatar(String displayName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(int gamesPlayed, int reviewsWritten, double averageRating) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$gamesPlayed', 'Games', Icons.sports_esports),
          _buildStatDivider(),
          _buildStatItem('$reviewsWritten', 'Rated', Icons.star),
          _buildStatDivider(),
          _buildStatItem(averageRating.toStringAsFixed(1), 'Avg Rating', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    final theme = Theme.of(context);
    
    return Container(
      height: 32,
      width: 1,
      color: theme.colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  Widget _buildFavoriteGameSection() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.favorite,
                color: Color(0xFFEC4899),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Favorite Game',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_favoriteGame != null) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameDetailScreen(
                      gameId: _favoriteGame!.id,
                      initialGame: _favoriteGame,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _favoriteGame!.coverImage,
                        width: 50,
                        height: 66,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 66,
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          child: Icon(
                            Icons.videogame_asset,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _favoriteGame!.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (_favoriteGame!.releaseDate.isNotEmpty)
                            Text(
                              _favoriteGame!.releaseDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFBBF24),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _favoriteGame!.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.videogame_asset,
                    color: Colors.grey,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No favorite game selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile body sections
  // ---------------------------------------------------------------------------

  final Map<String, Future<Game?>> _gameLookups = {};

  Future<Game?> _gameFor(String gameId) => _gameLookups.putIfAbsent(gameId, () async {
        try {
          return await IGDBService.instance.getGameDetails(gameId);
        } catch (e) {
          return null;
        }
      });

  /// Highest-rated games, best first (what this player recommends).
  List<UserRating> get _recommendations {
    final top = _ratings.where((r) => r.rating >= 4.0).toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : b.updatedAt.compareTo(a.updatedAt);
      });
    return top.take(12).toList();
  }

  List<UserRating> get _writtenReviews =>
      _ratings.where((r) => (r.review ?? '').trim().isNotEmpty).take(5).toList();

  void _openGame(String gameId, [Game? game]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: gameId, initialGame: game)),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, {String? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _emptyNote(String text, IconData icon) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: muted, fontSize: 13.5))),
        ],
      ),
    );
  }

  /// Bio, join date and follower counts under the banner.
  Widget _buildIdentity(int followers, int following) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final bio = (_userData?['bio'] ?? '').toString().trim();
    final joinedMs = _userData?['joinDate'] ?? _userData?['createdAt'];
    final joined = joinedMs is int ? DateTime.fromMillisecondsSinceEpoch(joinedMs) : null;

    Widget count(int value, String label) => Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
            ),
            TextSpan(text: label),
          ]),
          style: TextStyle(fontSize: 14, color: muted),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          if (bio.isNotEmpty) ...[
            Text(
              bio,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              count(followers, followers == 1 ? 'follower' : 'followers'),
              count(following, 'following'),
              if (joined != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 15, color: muted),
                    const SizedBox(width: 4),
                    Text('Joined ${_monthYear(joined)}', style: TextStyle(fontSize: 14, color: muted)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _monthYear(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  /// Follow / friend / message buttons for someone else's profile.
  Widget _buildActionRow() {
    final theme = Theme.of(context);
    final friends = _friendshipStatus == FriendshipStatus.friends;

    final follow = _isFollowing
        ? OutlinedButton.icon(
            onPressed: _isLoadingFollow ? null : _toggleFollow,
            icon: const Icon(Icons.how_to_reg_rounded, size: 18),
            label: const Text('Following'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF5B83D),
              side: const BorderSide(color: Color(0xFFF5B83D)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        : FilledButton.icon(
            onPressed: _isLoadingFollow ? null : _toggleFollow,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Follow'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

    final (IconData friendIcon, String friendLabel, VoidCallback? friendAction) = switch (_friendshipStatus) {
      FriendshipStatus.none => (Icons.group_add_outlined, 'Add friend', _sendFriendRequest),
      FriendshipStatus.requestSent => (Icons.schedule, 'Requested', null),
      FriendshipStatus.requestReceived => (Icons.check, 'Accept', _acceptFriendRequest),
      FriendshipStatus.friends => (Icons.people_alt_rounded, 'Friends', _confirmRemoveFriend),
      FriendshipStatus.self => (Icons.person, '', null),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(child: follow),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoadingAction ? null : friendAction,
              icon: Icon(friendIcon, size: 18),
              label: Text(friendLabel, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (friends) ...[
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => openChatWith(context, widget.userId, _userData),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Message',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemoveFriend() async {
    final name = (_userData?['displayName'] ?? _userData?['username'] ?? 'this user').toString();
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('You and $name will no longer be friends.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) await _removeFriend();
  }

  /// Horizontal row of the player's top-rated games.
  Widget _buildRecommendsSection() {
    final theme = Theme.of(context);
    final picks = _recommendations;
    final name = _isCurrentUser ? 'You' : (_userData?['displayName'] ?? _userData?['username'] ?? 'They').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recommends', Icons.thumb_up_alt_rounded, const Color(0xFF10B981),
            trailing: picks.isEmpty ? null : '${picks.length}'),
        if (!_ratingsLoaded)
          const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()))
        else if (picks.isEmpty)
          _emptyNote(
            _isCurrentUser
                ? 'Games you rate 4★ or higher show up here as your recommendations.'
                : "$name hasn't rated anything 4★ or higher yet.",
            Icons.thumb_up_off_alt,
          )
        else
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final pick = picks[i];
                return FutureBuilder<Game?>(
                  future: _gameFor(pick.gameId),
                  builder: (context, snapshot) {
                    final game = snapshot.data;
                    final cover = game?.coverImage ?? '';
                    final title = game?.title ?? pick.gameTitle ?? '';
                    return GestureDetector(
                      onTap: () => _openGame(pick.gameId, game),
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 100,
                                    height: 133,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                    child: cover.isEmpty
                                        ? Icon(Icons.videogame_asset,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3))
                                        : AppNetworkImage(imageUrl: cover, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 2),
                                        Text(
                                          pick.rating.toStringAsFixed(pick.rating % 1 == 0 ? 0 : 1),
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// The player's latest written reviews.
  Widget _buildRecentReviewsSection() {
    final theme = Theme.of(context);
    final reviews = _writtenReviews;
    if (_ratingsLoaded && reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent reviews', Icons.rate_review_rounded, theme.colorScheme.primary),
        if (!_ratingsLoaded)
          const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
        else
          for (final review in reviews)
            FutureBuilder<Game?>(
              future: _gameFor(review.gameId),
              builder: (context, snapshot) {
                final game = snapshot.data;
                final cover = game?.coverImage ?? '';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openGame(review.gameId, game),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 52,
                                height: 70,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                child: cover.isEmpty
                                    ? null
                                    : AppNetworkImage(imageUrl: cover, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game?.title ?? review.gameTitle ?? 'Game',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      for (var s = 1; s <= 5; s++)
                                        Icon(
                                          review.rating >= s
                                              ? Icons.star_rounded
                                              : review.rating >= s - 0.5
                                                  ? Icons.star_half_rounded
                                                  : Icons.star_outline_rounded,
                                          size: 15,
                                          color: const Color(0xFFFBBF24),
                                        ),
                                      const SizedBox(width: 6),
                                      Text(
                                        formatShortDate(review.updatedAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    review.review!.trim(),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }

  /// Public playlists as cards with a 2x2 cover mosaic.
  Widget _buildPlaylistsSection() {
    final theme = Theme.of(context);
    final name = (_userData?['displayName'] ?? _userData?['username'] ?? 'This player').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_isCurrentUser ? 'Playlists' : 'Public playlists', Icons.playlist_play_rounded,
            theme.colorScheme.secondary,
            trailing: _userPlaylists.isEmpty ? null : '${_userPlaylists.length}'),
        if (_userPlaylists.isEmpty)
          _emptyNote(
            _isCurrentUser
                ? 'Create playlists in your Library and make them public to share recommendations here.'
                : "$name hasn't shared any playlists yet.",
            Icons.queue_music_rounded,
          )
        else ...[
          SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _userPlaylists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildPlaylistCard(_userPlaylists[i]),
            ),
          ),
          if (_isCurrentUser)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                'Long-press a playlist to make it public or private.',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? const []);
    final covers = games
        .map((g) => (g['gameCoverImage'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .take(4)
        .toList();
    final isPublic = playlist['isPublic'] == true;

    Widget tile(int i) => i < covers.length
        ? AppNetworkImage(imageUrl: covers[i], fit: BoxFit.cover)
        : Container(color: theme.colorScheme.onSurface.withValues(alpha: 0.06));

    return GestureDetector(
      onTap: () => _showPlaylistDialog(playlist),
      onLongPress: _isCurrentUser ? () => _showPlaylistOptions(playlist) : null,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 150,
                height: 150,
                child: covers.isEmpty
                    ? Container(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        child: Icon(Icons.queue_music_rounded, size: 44, color: theme.colorScheme.secondary),
                      )
                    : covers.length < 4
                        ? AppNetworkImage(imageUrl: covers.first, fit: BoxFit.cover)
                        : Column(
                            children: [
                              Expanded(child: Row(children: [Expanded(child: tile(0)), const SizedBox(width: 2), Expanded(child: tile(1))])),
                              const SizedBox(height: 2),
                              Expanded(child: Row(children: [Expanded(child: tile(2)), const SizedBox(width: 2), Expanded(child: tile(3))])),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    (playlist['name'] ?? 'Untitled').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                  ),
                ),
                if (_isCurrentUser)
                  Icon(isPublic ? Icons.public : Icons.lock_outline,
                      size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
            Text(
              '${games.length} ${games.length == 1 ? 'game' : 'games'}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    setState(() => _isLoadingAction = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await FriendsService.sendFriendRequest(currentUser.uid, widget.userId);
        setState(() {
          _friendshipStatus = FriendshipStatus.requestSent;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _acceptFriendRequest() async {
    setState(() => _isLoadingAction = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await FriendsService.acceptFriendRequest(widget.userId, currentUser.uid);
        setState(() {
          _friendshipStatus = FriendshipStatus.friends;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request accepted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _removeFriend() async {
    setState(() => _isLoadingAction = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await FriendsService.removeFriend(currentUser.uid, widget.userId);
        setState(() {
          _friendshipStatus = FriendshipStatus.none;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend removed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove friend: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoadingFollow = true);
    
    try {
      if (_isFollowing) {
        await FollowService.unfollowUser(widget.userId);
        setState(() => _isFollowing = false);
        // Update real-time counter immediately for better UX
        setState(() => _realTimeFollowers = _realTimeFollowers - 1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unfollowed successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await FollowService.followUser(widget.userId);
        setState(() => _isFollowing = true);
        // Update real-time counter immediately for better UX
        setState(() => _realTimeFollowers = _realTimeFollowers + 1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Following successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Revert the optimistic update on error
      if (_isFollowing) {
        setState(() => _realTimeFollowers = _realTimeFollowers + 1);
      } else {
        setState(() => _realTimeFollowers = _realTimeFollowers - 1);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFollow = false);
    }
  }
}