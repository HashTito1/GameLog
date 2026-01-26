import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/auth_user.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/event_bus.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  GameStatus? _selectedFilter;
  List<Map<String, dynamic>> _libraryGames = [];
  Map<String, dynamic> _libraryStats = {};
  bool _isLoading = true;
  StreamSubscription<LibraryUpdatedEvent>? _libraryUpdateSubscription;
  StreamSubscription<RatingSubmittedEvent>? _ratingSubmittedSubscription;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedFilter = null; // Show all games by default
    _tabController = TabController(length: 2, vsync: this);
    _loadLibrary();
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _libraryUpdateSubscription = EventBus().on<LibraryUpdatedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && event.userId == currentUser.id) {
                // Force refresh with loading state
        setState(() => _isLoading = true);
        _loadLibrary();
      }
    });
    
    _ratingSubmittedSubscription = EventBus().on<RatingSubmittedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
                // Force refresh with loading state
        setState(() => _isLoading = true);
        _loadLibrary();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _libraryUpdateSubscription?.cancel();
    _ratingSubmittedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final authService = FirebaseAuthService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final library = await LibraryService.instance.getUserLibrary(currentUser.id);
      final stats = await LibraryService.instance.getUserLibraryStats(currentUser.id);
      
      // Debug: Print each game's status
      for (final _ in library) {
        // Debug logging can be added here if needed
      }
      
      setState(() {
        _libraryGames = library;
        _libraryStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading library: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_libraryStats.isNotEmpty) _buildStats(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6366F1)),
                      ),
                    )
                  : _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          const Text(
            'My Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Games'),
          Tab(text: 'Playlists'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGamesTab(),
        _buildPlaylistsTab(),
      ],
    );
  }

  Widget _buildGamesTab() {
    return Column(
      children: [
        if (_libraryGames.isNotEmpty) _buildFilters(),
        Expanded(
          child: _libraryGames.isEmpty
              ? _buildEmptyState()
              : _buildGamesList(),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab() {
    final user = FirebaseAuthService().currentUser;
    final playlists = user?.playlists ?? [];
    
    if (playlists.isEmpty) {
      return _buildEmptyPlaylistsState();
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _buildPlaylistItem(playlist);
      },
    );
  }

  Widget _buildEmptyPlaylistsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play_outlined,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No Playlists Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create playlists to organize your games\ninto custom collections',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to profile to create playlist
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Go to Profile tab to create playlists!'),
                  backgroundColor: const Color(0xFF6366F1),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(GamePlaylist playlist) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.playlist_play,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (playlist.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(playlist.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${playlist.games.length} games',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (playlist.games.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlist.games.length,
                itemBuilder: (context, index) {
                  // Placeholder for game thumbnail
                  return Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.videogame_asset,
                      color: Colors.white54,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50, // Reduced height
      padding: EdgeInsets.symmetric(vertical: 8), // Reduced padding
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12), // Reduced padding
        children: [
          _buildFilterChip('All', null),
          ...GameStatus.values.map((status) => _buildFilterChip(status.displayName, status)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, GameStatus? status) {
    final isSelected = _selectedFilter == status;
    return Container(
      margin: const EdgeInsets.only(right: 8), // Reduced margin
      child: FilterChip(
        label: Text(label,
          style: TextStyle(
            fontSize: 12, // Smaller text
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? status : null;
          });
        },
        backgroundColor: const Color(0xFF1F2937),
        selectedColor: const Color(0xFF6366F1),
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
      ),
    );
  }

  Widget _buildStats() {
    final totalGames = _libraryStats['totalGames'] ?? 0;
    final averageRating = (_libraryStats['averageRating'] ?? 0.0).toDouble();
    final ratedGames = _libraryStats['ratedGames'] ?? 0;
    final backlogGames = _libraryStats['backlogGames'] ?? 0;

    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(number: totalGames.toString(), label: 'Games'),
          _StatItem(number: ratedGames.toString(), label: 'Rated'),
          _StatItem(number: backlogGames.toString(), label: 'Backlog'),
          _StatItem(number: averageRating.toStringAsFixed(1), label: 'Avg Rating'),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
            final filteredGames = _selectedFilter == null 
        ? _libraryGames 
        : _libraryGames.where((game) {
            final statusStr = game['status'] as String?;
            final userRating = (game['userRating'] ?? 0.0).toDouble();
            
                        // Handle different status types
            if (_selectedFilter == GameStatus.backlog) {
              return statusStr == 'backlog';
            } else if (_selectedFilter == GameStatus.completed) {
              return statusStr == 'completed';
            } else if (_selectedFilter == GameStatus.rated) {
              // Show ALL games that have a rating > 0, regardless of status
              final hasRating = userRating > 0;
                            return hasRating;
            } else if (_selectedFilter == GameStatus.playing) {
              return statusStr == 'playing';
            } else if (_selectedFilter == GameStatus.dropped) {
              return statusStr == 'dropped';
            } else if (_selectedFilter == GameStatus.planToPlay) {
              return statusStr == 'planToPlay';
            }
            // Match stored status string with enum name
            return statusStr == _selectedFilter!.name;
          }).toList();

        // Debug: Print filtered games
    for (final _ in filteredGames) {
          }

    if (filteredGames.isEmpty) {
      return _buildEmptyState(isFilterEmpty: true);
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredGames.length,
      itemBuilder: (context, index) {
        final gameData = filteredGames[index];
        return _buildGameItem(gameData);
      },
    );
  }

  Widget _buildGameItem(Map<String, dynamic> gameData) {
    final gameTitle = gameData['gameTitle'] ?? 'Unknown Game';
    final gameCoverImage = gameData['gameCoverImage'] ?? '';
    final gameDeveloper = gameData['gameDeveloper'] ?? 'Unknown Developer';
    final userRating = (gameData['userRating'] ?? 0.0).toDouble();
    final userReview = gameData['userReview'];
    final gameId = gameData['gameId'] ?? '';
    final status = gameData['status'] ?? 'rated';

    return GestureDetector(
      onTap: () {
        if (gameId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: gameId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: gameCoverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gameCoverImage,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.videogame_asset,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.videogame_asset,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameDeveloper,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show rating for rated games, status for others
                  if (status == 'backlog') ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark,
                            color: const Color(0xFF6366F1),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Backlog',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (userRating > 0) ...[
                    // Show rating for both 'rated' and 'completed' games
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < userRating ? Icons.star : Icons.star_border,
                            color: Color(0xFFFBBF24),
                            size: 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          userRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (status == 'completed') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (status != 'backlog' && userRating == 0) ...[
                    // Show status for other non-rated games
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        GameStatus.values
                            .firstWhere((s) => s.name == status, orElse: () => GameStatus.planToPlay)
                            .displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (userReview != null && userReview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userReview,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isFilterEmpty = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFilterEmpty ? Icons.filter_list_off : Icons.library_books_outlined,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            isFilterEmpty ? 'No games found' : 'Your library is empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFilterEmpty 
                ? 'Try selecting a different filter' 
                : 'Add games from the search tab to build your library',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String number;
  final String label;

  const _StatItem({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 18, // Smaller text
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, // Smaller text
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}


