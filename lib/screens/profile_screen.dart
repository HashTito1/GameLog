import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/rawg_service.dart';
import '../models/game.dart';
import 'user_profile_screen.dart';
import 'search_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  Game? _favoriteGame;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        final userData = await UserDataService.getUserProfile(currentUser.uid);
        
        // If user data exists but username/displayName are missing, update them
        if (userData != null && (userData['username'] == null || userData['displayName'] == null)) {
          debugPrint('Updating missing user profile fields...');
          
          // Generate username and displayName from email if missing
          final email = currentUser.email ?? '';
          final username = userData['username'] ?? email.split('@')[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final displayName = userData['displayName'] ?? currentUser.displayName ?? email.split('@')[0];
          
          // Update Firestore with missing fields
          await UserDataService.saveUserProfile(currentUser.uid, {
            'username': username,
            'displayName': displayName,
          });
          
          // Reload data after update
          final updatedUserData = await UserDataService.getUserProfile(currentUser.uid);
          setState(() {
            _userData = updatedUserData;
          });
        } else {
          setState(() {
            _userData = userData;
          });
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
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectFavoriteGame() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(isSelectingFavorite: true),
      ),
    );
    
    if (result != null && result is Game) {
      await _setFavoriteGame(result);
    }
  }

  Future<void> _setFavoriteGame(Game game) async {
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await UserDataService.saveUserProfile(currentUser.uid, {
          'favoriteGame': {
            'gameId': game.id,
            'gameName': game.title,
            'gameImage': game.coverImage,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        });
        
        setState(() {
          _favoriteGame = game;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${game.title} set as favorite game!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set favorite game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuthService.instance.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(
          child: Text(
            'No user logged in',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Extract user data
    final username = _userData?['username'] ?? currentUser.email?.split('@')[0] ?? 'user';
    final displayName = _userData?['displayName'] ?? currentUser.displayName ?? username;
    final profileImage = _userData?['profileImage'] ?? '';
    final bannerImage = _userData?['bannerImage'] ?? '';
    final gamesPlayed = _userData?['gamesPlayed'] ?? 0;
    final reviewsWritten = _userData?['reviewsWritten'] ?? 0;
    final followers = _userData?['followers'] ?? 0;
    final following = _userData?['following'] ?? 0;
    final averageRating = 0.0; // Calculate from ratings if needed

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(bannerImage, profileImage, displayName, username),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatsSection(gamesPlayed, reviewsWritten, averageRating),
                const SizedBox(height: 24),
                _buildFavoriteGameSection(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 24),
                _buildFriendsSection(followers, following),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String bannerImage, String profileImage, String displayName, String username) {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E293B),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner Background
            Container(
              decoration: BoxDecoration(
                gradient: bannerImage.isEmpty || bannerImage.startsWith('file://')
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
                image: bannerImage.isNotEmpty && !bannerImage.startsWith('file://')
                    ? DecorationImage(
                        image: NetworkImage(bannerImage),
                        fit: BoxFit.cover,
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
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            // Profile content
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Profile Picture - Full circle, not cropped
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profileImage.isNotEmpty && !profileImage.startsWith('file://')
                          ? Image.network(
                              profileImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(displayName),
                            )
                          : _buildDefaultAvatar(displayName),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name and username
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 28,
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
                      fontSize: 16,
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
            // Edit Profile Button
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () {
                    // Navigate to edit profile
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            // Show menu options
          },
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: const Color(0xFF374151),
    );
  }

  Widget _buildFavoriteGameSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Color(0xFFEC4899),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Favorite Game',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectFavoriteGame,
                child: Text(
                  _favoriteGame == null ? 'Set Favorite' : 'Change',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_favoriteGame != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _favoriteGame!.coverImage,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 80,
                        color: const Color(0xFF6B7280),
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _favoriteGame!.title,
                          style: const TextStyle(
                            fontSize: 16,
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
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _favoriteGame!.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.videogame_asset,
                    color: Colors.grey,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No favorite game selected',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Set Favorite" to choose your favorite game',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Set Favorite',
                  Icons.star,
                  const Color(0xFFFBBF24),
                  _selectFavoriteGame,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Create Playlist',
                  Icons.playlist_add,
                  const Color(0xFF10B981),
                  () {
                    // Navigate to create playlist
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              'Friends',
              Icons.people,
              const Color(0xFF6366F1),
              () {
                // Navigate to friends screen
                Navigator.of(context).pushNamed('/friends');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildFriendsSection(int followers, int following) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Social',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSocialStat('Followers', followers),
              ),
              Container(
                height: 40,
                width: 1,
                color: const Color(0xFF374151),
              ),
              Expanded(
                child: _buildSocialStat('Following', following),
              ),
            ],
          ),
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}