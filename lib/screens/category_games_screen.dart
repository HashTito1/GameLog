import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
import 'game_detail_screen.dart';

class CategoryGamesScreen extends StatefulWidget {
  final String categoryTitle;
  final String categoryType; // 'trending', 'popular', 'action', 'rpg', 'indie'
  
  const CategoryGamesScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryType,
  });

  @override
  State<CategoryGamesScreen> createState() => _CategoryGamesScreenState();
}

class _CategoryGamesScreenState extends State<CategoryGamesScreen> {
  List<Game> _games = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGames();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        _loadMoreGames();
      }
    }
  }

  Future<void> _loadGames() async {
    try {
      setState(() => _isLoading = true);
      
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      List<Game> games;
      switch (widget.categoryType) {
        case 'trending':
          games = await IGDBService.instance.getTrendingGames(
            limit: _pageSize, 
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'popular':
          games = await IGDBService.instance.getPopularGames(
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'shooter':
          games = await IGDBService.instance.getGamesByGenre(
            'Shooter', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'action':
          // Fallback for old action category - use Shooter
          games = await IGDBService.instance.getGamesByGenre(
            'Shooter', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'rpg':
          games = await IGDBService.instance.getGamesByGenre(
            'Role-playing (RPG)', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'indie':
          games = await IGDBService.instance.getGamesByGenre(
            'Indie', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'adventure':
          games = await IGDBService.instance.getGamesByGenre(
            'Adventure', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'strategy':
          games = await IGDBService.instance.getGamesByGenre(
            'Strategy', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'goty':
          games = await IGDBService.instance.getGOTYCandidates(
            year: DateTime.now().year - 1,
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        default:
          games = await IGDBService.instance.getPopularGames(
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
      }
      
      setState(() {
        _games = games;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreGames() async {
    if (_isLoadingMore) return;
    
    try {
      setState(() => _isLoadingMore = true);
      _currentPage++;
      
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      List<Game> moreGames;
      switch (widget.categoryType) {
        case 'trending':
          moreGames = await IGDBService.instance.getTrendingGames(
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'popular':
          moreGames = await IGDBService.instance.getPopularGames(
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'shooter':
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Shooter',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'action':
          // Fallback for old action category - use Shooter
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Shooter',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'rpg':
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Role-playing (RPG)',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'indie':
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Indie',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'adventure':
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Adventure',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'strategy':
          moreGames = await IGDBService.instance.getGamesByGenre(
            'Strategy',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'goty':
          // GOTY games don't support pagination in the same way, so return empty
          moreGames = [];
          break;
        default:
          moreGames = await IGDBService.instance.getPopularGames(
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
      }
      
      setState(() {
        _games.addAll(moreGames);
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        ),
        title: Text(
          widget.categoryTitle,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Add search functionality
            },
            icon: Icon(Icons.search, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : _games.isEmpty
              ? _buildEmptyState(theme)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${_games.length} games found',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          // TODO: Add sort/filter options
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75, // Adjusted for better proportions
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _games.length + (_isLoadingMore ? 2 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _games.length) {
                            return _buildLoadingCard();
                          }
                          
                          final game = _games[index];
                          return _buildGameCard(game);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGameCard(Game game) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(
              gameId: game.id,
              initialGame: game,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - fixed height to prevent overflow
            AspectRatio(
              aspectRatio: 1.4, // Slightly wider than square for better proportions
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: game.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game.coverImage,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.videogame_asset,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.videogame_asset,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.videogame_asset,
                                color: Colors.white54,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  if (game.averageRating > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              game.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content section - flexible but constrained
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title - constrained height
                    Text(
                      game.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Release date - single line
                    if (game.releaseDate.isNotEmpty)
                      Text(
                        game.releaseDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Genres - constrained to prevent overflow
                    if (game.genres.isNotEmpty)
                      Flexible(
                        child: Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: game.genres.take(2).map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.games_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No games found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or check back later',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}