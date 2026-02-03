import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
import '../services/cache_service.dart';
import 'notifications_screen.dart';
import 'game_detail_screen.dart';
import 'category_games_screen.dart';
import 'search_screen.dart';
import '../services/recommendation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Game> _trendingGames = [];
  List<Game> _popularGames = [];
  List<Game> _actionGames = [];
  List<Game> _rpgGames = [];
  List<Game> _strategyGames = [];
  List<Game> _featuredGames = [];
  List<Game> _gotyGames = [];
  List<Game> _suggestedGames = [];
  bool _isLoading = true; // Hot reload trigger - Updated UI
  bool _isLoadingInProgress = false; // Prevent multiple simultaneous loads
  
  // Play Store style tabs
  final List<String> _tabs = ['For you', 'Top charts', 'Categories'];
  late TabController _tabController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _loadAllGames();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllGames() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingInProgress) return;
    
    try {
      setState(() => _isLoadingInProgress = true);
      
      // Clear cache to ensure fresh data with current year
      await CacheService.clearAllCache();
      
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load the most important sections first
      final popularGames = await IGDBService.instance.getPopularGames(
        limit: 12,
        includeAdultContent: includeAdultContent,
      );
      
      // Get highly rated games for featured section
      final highlyRatedGames = await IGDBService.instance.getHighlyRatedGames(
        limit: 20,
        includeAdultContent: includeAdultContent,
      );
      
      // Create daily randomized featured games
      final featuredGames = _getDailyRandomizedGames(highlyRatedGames, 10);
      
      setState(() {
        _popularGames = popularGames;
        _featuredGames = featuredGames;
        _isLoading = false;
        _isLoadingInProgress = false;
      });

      // Start animations
      _animationController.forward();

      // Load trending games
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          try {
            final trendingGames = await IGDBService.instance.getTrendingGames(
              limit: 12,
              includeAdultContent: includeAdultContent,
            );
            
            if (mounted) {
              setState(() {
                _trendingGames = trendingGames;
              });
            }
          } catch (e) {
            debugPrint('Error loading trending games: $e');
          }
        }
      });

      // Load genre-specific games in the background
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _loadGenreGamesInBackground();
        }
      });

      // Load GOTY games in the background
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _loadGOTYGames();
        }
      });

      // Load personalized suggestions in the background
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _loadPersonalizedSuggestions();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingInProgress = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading games: $e'),
            backgroundColor: const Color(0xFFEA4335),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Generate daily randomized games using date as seed
  List<Game> _getDailyRandomizedGames(List<Game> games, int count) {
    if (games.isEmpty) return [];
    
    // Create a seed based on current date (changes daily)
    final now = DateTime.now();
    final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final seed = dateString.hashCode;
    
    // Create a new Random instance with the daily seed
    final random = Random(seed);
    
    // Create a copy of the games list and shuffle it with the daily seed
    final shuffledGames = List<Game>.from(games);
    
    // Custom shuffle with seeded random
    for (int i = shuffledGames.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = shuffledGames[i];
      shuffledGames[i] = shuffledGames[j];
      shuffledGames[j] = temp;
    }
    
    // Return the requested number of games
    return shuffledGames.take(count).toList();
  }

  Future<void> _loadGenreGamesInBackground() async {
    try {
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load genre games with staggered delays for better performance
      
      // Shooter games first
      try {
        final shooterGames = await IGDBService.instance.getGamesByGenre(
          'Shooter', 
          limit: 12, 
          includeAdultContent: includeAdultContent
        );
        
        if (mounted) {
          setState(() {
            _actionGames = shooterGames;
          });
        }
      } catch (e) {
        debugPrint('Error loading Shooter games: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));
      
      // RPG games
      if (mounted) {
        try {
          final rpgGames = await IGDBService.instance.getGamesByGenre(
            'Role-playing (RPG)', 
            limit: 12, 
            includeAdultContent: includeAdultContent
          );
          
          if (mounted) {
            setState(() {
              _rpgGames = rpgGames;
            });
          }
        } catch (e) {
          debugPrint('Error loading RPG games: $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      
      // Strategy games
      if (mounted) {
        try {
          final strategyGames = await IGDBService.instance.getGamesByGenre(
            'Strategy', 
            limit: 12, 
            includeAdultContent: includeAdultContent
          );
          
          if (mounted) {
            setState(() {
              _strategyGames = strategyGames;
            });
          }
        } catch (e) {
          debugPrint('Error loading Strategy games: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading genre games: $e');
    }
  }

  Future<void> _loadGOTYGames() async {
    try {
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load GOTY candidates from last year
      try {
        final gotyGames = await IGDBService.instance.getGOTYCandidates(
          year: DateTime.now().year - 1,
          limit: 12, 
          includeAdultContent: includeAdultContent
        );
        
        if (mounted) {
          setState(() {
            _gotyGames = gotyGames;
          });
        }
      } catch (e) {
        debugPrint('Error loading GOTY games: $e');
      }
    } catch (e) {
      debugPrint('Error in _loadGOTYGames: $e');
    }
  }

  Future<void> _loadPersonalizedSuggestions() async {
    try {
      // Load personalized recommendations based on user's library
      try {
        final suggestions = await RecommendationService.instance.getPersonalizedRecommendations(limit: 10);
        
        if (mounted) {
          setState(() {
            _suggestedGames = suggestions;
          });
        }
      } catch (e) {
        debugPrint('Error loading personalized suggestions: $e');
      }
    } catch (e) {
      debugPrint('Error in _loadPersonalizedSuggestions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildPlayStoreHeader(theme),
            _buildTabBar(theme),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(theme)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildForYouTab(theme),
                        _buildTopChartsTab(theme),
                        _buildCategoriesTab(theme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayStoreHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Play Store style logo
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.videogame_asset,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search for games',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Notification bell with badge
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335),
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
        labelPadding: const EdgeInsets.symmetric(vertical: 8),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildForYouTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAllGames,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeaturedCarousel(theme),
            const SizedBox(height: 12),
            _buildSuggestedSection(theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('Recommended for you', _suggestedGames, 'suggested', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('Trending now', _trendingGames, 'trending', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('Popular games', _popularGames, 'popular', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('${DateTime.now().year - 1} Award Winners', _gotyGames, 'goty', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('New releases', _actionGames, 'shooter', theme),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChartsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildTopChartsList('Top games', _featuredGames, theme),
          const SizedBox(height: 16),
          _buildTopChartsList('Top trending', _trendingGames, theme),
          const SizedBox(height: 16),
          _buildTopChartsList('Top rated', _popularGames, theme),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildCategoryGrid(theme),
          const SizedBox(height: 16),
          _buildHorizontalGameSection('Action & Adventure', _actionGames, 'shooter', theme),
          const SizedBox(height: 16),
          _buildHorizontalGameSection('Role Playing', _rpgGames, 'rpg', theme),
          const SizedBox(height: 16),
          _buildHorizontalGameSection('Strategy', _strategyGames, 'strategy', theme),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading games...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(ThemeData theme) {
    if (_featuredGames.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Games',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Daily Selection',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: _featuredGames.length,
              itemBuilder: (context, index) {
                final game = _featuredGames[index];
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildCarouselItem(game, theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Game game, ThemeData theme) {
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              game.coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surface,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surface,
                        child: Icon(
                          Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 64,
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: Icon(
                        Icons.videogame_asset,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 64,
                      ),
                    ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.developer,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (game.averageRating > 0) ...[
                          const Icon(Icons.star, color: Color(0xFFFBBC05), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            game.averageRating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const Spacer(),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Suggested for you',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_suggestedGames.isNotEmpty) ...[
            _buildSuggestedGameItem(_suggestedGames.first, theme),
            if (_suggestedGames.length > 1) ...[
              const SizedBox(height: 10),
              _buildSuggestedGameItem(_suggestedGames[1], theme),
            ],
          ] else if (_popularGames.isNotEmpty) ...[
            // Fallback to popular games if no personalized suggestions
            _buildSuggestedGameItem(_popularGames.first, theme),
            if (_popularGames.length > 1) ...[
              const SizedBox(height: 10),
              _buildSuggestedGameItem(_popularGames[1], theme),
            ],
          ] else ...[
            // Loading state
            _buildSuggestedLoadingItem(theme),
            const SizedBox(height: 10),
            _buildSuggestedLoadingItem(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedGameItem(Game game, ThemeData theme) {
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: game.coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surface,
                        child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surface,
                        child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  game.developer,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (game.averageRating > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFBBC05), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        game.averageRating.toStringAsFixed(1),
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Review',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedLoadingItem(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              strokeWidth: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Loading...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalGameSection(String title, List<Game> games, String categoryType, ThemeData theme) {
    if (games.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryGamesScreen(
                        categoryTitle: title,
                        categoryType: categoryType,
                      ),
                    ),
                  );
                },
                child: Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              return _buildPlayStoreGameCard(games[index], theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayStoreGameCard(Game game, ThemeData theme) {
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
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: game.coverImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: game.coverImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surface,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surface,
                            child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 32),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surface,
                          child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 32),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              game.developer,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (game.averageRating > 0)
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFBBC05), size: 12),
                  const SizedBox(width: 2),
                  Text(
                    game.averageRating.toStringAsFixed(1),
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChartsList(String title, List<Game> games, ThemeData theme) {
    if (games.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...games.take(10).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final game = entry.value;
          return _buildTopChartItem(index + 1, game, theme);
        }),
      ],
    );
  }

  Widget _buildTopChartItem(int rank, Game game, ThemeData theme) {
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: game.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: game.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surface,
                          child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surface,
                          child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surface,
                        child: Icon(Icons.videogame_asset, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.developer,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (game.averageRating > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFBBC05), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          game.averageRating.toStringAsFixed(1),
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Review',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(ThemeData theme) {
    final categories = [
      {'name': 'Action', 'icon': Icons.flash_on, 'color': const Color(0xFFEA4335), 'type': 'shooter'},
      {'name': 'Adventure', 'icon': Icons.explore, 'color': const Color(0xFF34A853), 'type': 'adventure'},
      {'name': 'RPG', 'icon': Icons.auto_stories, 'color': const Color(0xFF8B5CF6), 'type': 'rpg'},
      {'name': 'Strategy', 'icon': Icons.psychology, 'color': const Color(0xFFFBBC05), 'type': 'strategy'},
      {'name': 'Indie', 'icon': Icons.palette, 'color': const Color(0xFFFF6B6B), 'type': 'indie'},
      {'name': '${DateTime.now().year - 1} Winners', 'icon': Icons.emoji_events, 'color': const Color(0xFFFFD700), 'type': 'goty'},
      {'name': 'Trending', 'icon': Icons.trending_up, 'color': const Color(0xFF4ECDC4), 'type': 'trending'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CategoryGamesScreen(
                  categoryTitle: '${category['name']} Games',
                  categoryType: category['type'] as String,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (category['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: category['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  category['name'] as String,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}