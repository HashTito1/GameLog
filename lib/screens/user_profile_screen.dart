import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/rawg_service.dart';
import '../services/library_service.dart';
import '../services/friends_service.dart';
import '../services/follow_service.dart';
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
              final game = await RAWGService.instance.getGameDetails(gameId);
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

  Future<void> _loadUserRatingStats(String userId) async {
    try {
      // Use the same stats loading logic as library screen
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
                  color: const Color(0xFF10B981),
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
                color: const Color(0xFF6366F1),
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
              leading: const Icon(
                Icons.visibility,
                color: Color(0xFF10B981),
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
      
      // Update local state
      setState(() {
        playlist['isPublic'] = newPrivacy;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPrivacy 
                ? 'Playlist is now public' 
                : 'Playlist is now private',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update playlist privacy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPlaylistDialog(Map<String, dynamic> playlist) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF374151)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF374151),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.playlist_play,
                      color: Color(0xFF10B981),
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
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: game['coverImage'] != null && game['coverImage'].toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game['coverImage'],
                            width: 50,
                            height: 66,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 50,
                              height: 66,
                              color: const Color(0xFF6B7280),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 50,
                              height: 66,
                              color: const Color(0xFF6B7280),
                              child: const Icon(
                                Icons.videogame_asset,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 66,
                            color: const Color(0xFF6B7280),
                            child: const Icon(
                              Icons.videogame_asset,
                              color: Colors.white54,
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Text(
            'User Profile',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Text(
            'User Profile',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
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
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(bannerImage, profileImage, displayName, username),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildStatsSection(gamesPlayed, _userRatingsCount, _userAverageRating),
                const SizedBox(height: 16),
                _buildFavoriteGameSection(),
                const SizedBox(height: 16),
                if (_userPlaylists.isNotEmpty) ...[
                  _buildPlaylistsSection(),
                  const SizedBox(height: 16),
                ],
                if (!_isCurrentUser) _buildFriendActions(),
                const SizedBox(height: 16),
                _buildFriendsSection(followers, following),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String bannerImage, String profileImage, String displayName, String username) {
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E293B),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner Background
            Container(
              decoration: BoxDecoration(
                gradient: (bannerImage.isEmpty)
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                          Color(0xFFEC4899),
                          Color(0xFFF59E0B),
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
                          ? CachedNetworkImage(
                              imageUrl: profileImage,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
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
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF6366F1),
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
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFF374151),
    );
  }

  Widget _buildFavoriteGameSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
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
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4B5563)),
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
                          color: const Color(0xFF6B7280),
                          child: const Icon(
                            Icons.videogame_asset,
                            color: Colors.white54,
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
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4B5563)),
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

  Widget _buildPlaylistsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
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
          Row(
            children: [
              const Icon(
                Icons.playlist_play,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Playlists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${_userPlaylists.length}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100, // Increased from 80 to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _userPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = _userPlaylists[index];
                return GestureDetector(
                  onTap: () => _showPlaylistDialog(playlist),
                  onLongPress: _isCurrentUser ? () => _showPlaylistOptions(playlist) : null,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10), // Reduced padding from 12 to 10
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4B5563)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                      children: [
                        Row(
                          children: [
                            Flexible( // Wrapped in Flexible to prevent overflow
                              child: Text(
                                playlist['name'] ?? 'Untitled',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2, // Increased from 1 to 2 for better text display
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Icon(
                                playlist['isPublic'] == true ? Icons.public : Icons.lock,
                                size: 12,
                                color: playlist['isPublic'] == true ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(playlist['games'] as List?)?.length ?? 0} games',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        if (_isCurrentUser && playlist['isPublic'] != true)
                          const Text(
                            'Private',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.playlist_play,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendActions() {
    if (_isCurrentUser) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: _buildFriendshipButton(),
      ),
    );
  }

  Widget _buildFriendshipButton() {
    switch (_friendshipStatus) {
      case FriendshipStatus.none:
        return ElevatedButton.icon(
          onPressed: _isLoadingAction ? null : _sendFriendRequest,
          icon: _isLoadingAction
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.person_add, size: 18),
          label: const Text('Send Friend Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            elevation: 0,
          ),
        );
      case FriendshipStatus.requestSent:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('Request Sent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            foregroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            elevation: 0,
          ),
        );
      case FriendshipStatus.requestReceived:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingAction ? null : _acceptFriendRequest,
                icon: _isLoadingAction
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingAction ? null : _declineFriendRequest,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Decline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        );
      case FriendshipStatus.friends:
        return ElevatedButton.icon(
          onPressed: _isLoadingAction ? null : _removeFriend,
          icon: _isLoadingAction
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.person_remove, size: 18),
          label: const Text('Remove Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            elevation: 0,
          ),
        );
      case FriendshipStatus.self:
        return const SizedBox.shrink();
    }
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

  Future<void> _declineFriendRequest() async {
    setState(() => _isLoadingAction = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await FriendsService.declineFriendRequest(widget.userId, currentUser.uid);
        setState(() {
          _friendshipStatus = FriendshipStatus.none;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request declined'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline friend request: $e'),
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

  Widget _buildFriendsSection(int followers, int following) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
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
                Icons.people,
                color: Color(0xFF6366F1),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Social',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSocialStat('Followers', followers),
              ),
              Container(
                height: 32,
                width: 1,
                color: const Color(0xFF374151),
              ),
              Expanded(
                child: _buildSocialStat('Following', following),
              ),
            ],
          ),
          if (!_isCurrentUser) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingFollow ? null : _toggleFollow,
                icon: _isLoadingFollow
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey[700] : const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18, // Reduced from 20
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
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