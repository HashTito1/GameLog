import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
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
          games = await RAWGService.instance.getTrendingGames(
            limit: _pageSize, 
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'popular':
          games = await RAWGService.instance.getPopularGames(
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'action':
          games = await RAWGService.instance.getGamesByGenre(
            'action', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'rpg':
          games = await RAWGService.instance.getGamesByGenre(
            'role-playing-games-rpg', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'indie':
          games = await RAWGService.instance.getGamesByGenre(
            'indie', 
            limit: _pageSize,
            includeAdultContent: includeAdultContent,
          );
          break;
        default:
          games = await RAWGService.instance.getPopularGames(
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
          moreGames = await RAWGService.instance.getTrendingGames(
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'popular':
          moreGames = await RAWGService.instance.getPopularGames(
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'action':
          moreGames = await RAWGService.instance.getGamesByGenre(
            'action',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'rpg':
          moreGames = await RAWGService.instance.getGamesByGenre(
            'role-playing-games-rpg',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        case 'indie':
          moreGames = await RAWGService.instance.getGamesByGenre(
            'indie',
            limit: _pageSize,
            page: _currentPage,
            includeAdultContent: includeAdultContent,
          );
          break;
        default:
          moreGames = await RAWGService.instance.getPopularGames(
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Add search functionality
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
          : _games.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${_games.length} games found',
                            style: const TextStyle(
                              color: Colors.grey,
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
                          childAspectRatio: 0.7,
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
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
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
                                  size: 40,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.videogame_asset,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.videogame_asset,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  if (game.averageRating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              game.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (game.releaseDate.isNotEmpty)
                      Text(
                        game.releaseDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    const Spacer(),
                    if (game.genres.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: game.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              genre,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.games_outlined,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No games found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or check back later',
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