import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
import 'notifications_screen.dart';
import 'game_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Game> _trendingGames = [];
  List<Game> _popularGames = [];
  List<Game> _actionGames = [];
  List<Game> _rpgGames = [];
  List<Game> _indieGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllGames();
  }

  Future<void> _loadAllGames() async {
    try {
      // Load the most important sections first (trending and popular)
      // These will likely be cached after the first load
      final trendingGames = await RAWGService.instance.getTrendingGames(limit: 10);
      final popularGames = await RAWGService.instance.getPopularGames(limit: 10);
      
      setState(() {
        _trendingGames = trendingGames;
        _popularGames = popularGames;
        _isLoading = false; // Show content immediately
      });

      // Load genre-specific games in the background
      // These are less critical and can load after the main content
      _loadGenreGamesInBackground();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games: $e')),
        );
      }
    }
  }

  Future<void> _loadGenreGamesInBackground() async {
    try {
      // Load genre games with a small delay to prioritize main content
      await Future.delayed(const Duration(milliseconds: 500));
      
      final results = await Future.wait([
        RAWGService.instance.getGamesByGenre('action', limit: 10),
        RAWGService.instance.getGamesByGenre('role-playing-games-rpg', limit: 10),
        RAWGService.instance.getGamesByGenre('indie', limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _actionGames = results[0];
          _rpgGames = results[1];
          _indieGames = results[2];
        });
      }
    } catch (e) {
            // Don\'t show error to user since this is background loading
      // Error handled
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildGameSection('Trending Now', _trendingGames),
                          const SizedBox(height: 20),
                          _buildGameSection('Popular Games', _popularGames),
                          const SizedBox(height: 20),
                          _buildGameSection('Action Games', _actionGames),
                          const SizedBox(height: 20),
                          _buildGameSection('RPG Games', _rpgGames),
                          const SizedBox(height: 20),
                          _buildGameSection('Indie Games', _indieGames),
                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'GameLog',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameSection(String title, List<Game> games) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (games.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // Navigate to see all games in this category
                    // You can implement this later
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: games.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.games_outlined,
                          size: 48,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
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
                        onLongPress: () {
                          _showQuickRating(game);
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: game.coverImage.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: game.coverImage,
                                              width: 100,
                                              height: 140,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 100,
                                                height: 140,
                                                color: Colors.grey[800],
                                                child: const Icon(Icons.videogame_asset,
                                                  color: Colors.white54,
                                                  size: 30,
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: 100,
                                                height: 140,
                                                color: Colors.grey[800],
                                                child: const Icon(Icons.videogame_asset,
                                                  color: Colors.white54,
                                                  size: 30,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 100,
                                              height: 140,
                                              color: Colors.grey[800],
                                              child: const Icon(Icons.videogame_asset,
                                                color: Colors.white54,
                                                size: 30,
                                              ),
                                            ),
                                    ),
                                    if (game.averageRating > 0)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.7),
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
                                                  fontSize: 8,
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
                              const SizedBox(height: 6),
                              Text(
                                game.title,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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

  void _showQuickRating(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          'Rate ${game.title}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tap to rate:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GameDetailScreen(
                          gameId: game.id,
                          initialGame: game,
                        ),
                      ),
                    );
                  },
                  child: Icon(Icons.star_border,
                    color: Color(0xFFFBBF24),
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Long press any game to quick rate!',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}


