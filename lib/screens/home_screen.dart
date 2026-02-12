import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
import '../services/cache_service.dart';
import '../services/rating_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/theme_service.dart';
import '../services/widget_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Game> _trendingGames = [];
  List<Game> _popularGames = [];
  List<Game> _actionGames = [];
  List<Game> _rpgGames = [];
  List<Game> _strategyGames = [];
  List<Game> _featuredGames = [];
  List<Game> _gotyGames = [];
  List<Game> _suggestedGames = [];
  List<UserRating> _friendReviews = [];
  bool _isLoading = true; // Hot reload trigger - Updated UI
  bool _isLoadingInProgress = false; // Prevent multiple simultaneous loads
  
  // Animation controller for new reviews
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _previousReviewCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _loadAllGames();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllGames() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingInProgress) return;
    
    try {
      setState(() => _isLoadingInProgress = true);
      
      // DON'T clear cache - let it work! Only clear on manual refresh
      // await CacheService.clearAllCache(); // REMOVED - this was killing performance
      
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load critical sections in parallel for faster initial display
      final results = await Future.wait([
        IGDBService.instance.getPopularGames(
          limit: 12,
          includeAdultContent: includeAdultContent,
        ),
        IGDBService.instance.getHighlyRatedGames(
          limit: 20,
          includeAdultContent: includeAdultContent,
        ),
        _loadFriendReviewsAsync(), // Load friend reviews in parallel
      ]);
      
      final popularGames = results[0] as List<Game>;
      final highlyRatedGames = results[1] as List<Game>;
      final friendReviews = results[2] as List<UserRating>;
      
      // Create daily randomized featured games
      final featuredGames = _getDailyRandomizedGames(highlyRatedGames, 10);
      
      // Apply cross-section deduplication
      final deduplicatedPopular = _deduplicateAcrossSections(popularGames, []);
      final deduplicatedFeatured = _deduplicateAcrossSections(featuredGames, deduplicatedPopular);
      
      setState(() {
        _popularGames = deduplicatedPopular;
        _featuredGames = deduplicatedFeatured;
        _friendReviews = friendReviews;
        _isLoading = false;
        _isLoadingInProgress = false;
      });
      
      // Update widget with friend reviews
      if (friendReviews.isNotEmpty) {
        WidgetService.updateWidget();
      }

      // Load remaining sections in parallel batches for better performance
      _loadRemainingContentInBackground(includeAdultContent);
      
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
  
  // Deduplicate games across sections to avoid showing same game multiple times
  List<Game> _deduplicateAcrossSections(List<Game> newGames, List<Game> existingGames) {
    final existingNormalizedTitles = existingGames.map((g) => _normalizeGameTitle(g.title)).toSet();
    
    return newGames.where((game) {
      final normalized = _normalizeGameTitle(game.title);
      return !existingNormalizedTitles.contains(normalized);
    }).toList();
  }
  
  // Normalize game title for deduplication
  String _normalizeGameTitle(String title) {
    String normalized = title.toLowerCase().trim();
    
    // Remove common separators and extra text
    normalized = normalized.split(':').first.trim();
    normalized = normalized.split('-').first.trim();
    normalized = normalized.split('–').first.trim();
    normalized = normalized.split('—').first.trim();
    
    // Remove edition suffixes
    final editionSuffixes = [
      r'\s+goty\s+edition$',
      r'\s+game of the year\s+edition$',
      r'\s+complete\s+edition$',
      r'\s+definitive\s+edition$',
      r'\s+ultimate\s+edition$',
      r'\s+gold\s+edition$',
      r'\s+deluxe\s+edition$',
      r'\s+premium\s+edition$',
      r'\s+enhanced\s+edition$',
      r'\s+special\s+edition$',
      r'\s+remastered$',
      r'\s+remake$',
      r'\s+edition$',
    ];
    
    for (final pattern in editionSuffixes) {
      normalized = normalized.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }
    
    // Remove extra whitespace and special characters
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Remove "the" at the beginning
    if (normalized.startsWith('the ')) {
      normalized = normalized.substring(4);
    }
    
    return normalized;
  }
  
  // Load friend reviews and return the result (for parallel loading)
  Future<List<UserRating>> _loadFriendReviewsAsync() async {
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) return [];
      
      return await RatingService.getFriendRecentRatings(
        currentUser.uid,
        limit: 10,
      );
    } catch (e) {
      debugPrint('❌ Error loading friend reviews: $e');
      return [];
    }
  }
  
  // Load remaining content in optimized parallel batches
  Future<void> _loadRemainingContentInBackground(bool includeAdultContent) async {
    if (!mounted) return;
    
    // Batch 1: Trending and genre games (load in parallel) - reduced limits for faster loading
    Future.wait([
      IGDBService.instance.getTrendingGames(
        limit: 10, // Reduced from 12
        includeAdultContent: includeAdultContent,
      ),
      IGDBService.instance.getGamesByGenre(
        'Shooter',
        limit: 10, // Reduced from 12
        includeAdultContent: includeAdultContent,
      ),
    ]).then((results) {
      if (mounted) {
        // Deduplicate against already loaded games
        final allExisting = [..._popularGames, ..._featuredGames];
        final deduplicatedTrending = _deduplicateAcrossSections(results[0], allExisting);
        final deduplicatedAction = _deduplicateAcrossSections(results[1], [...allExisting, ...deduplicatedTrending]);
        
        setState(() {
          _trendingGames = deduplicatedTrending;
          _actionGames = deduplicatedAction;
        });
      }
    }).catchError((e) {
      debugPrint('Error loading batch 1: $e');
    });
    
    // Batch 2: More genre games (load in parallel) - reduced limits
    Future.wait([
      IGDBService.instance.getGamesByGenre(
        'Role-playing (RPG)',
        limit: 10, // Reduced from 12
        includeAdultContent: includeAdultContent,
      ),
      IGDBService.instance.getGamesByGenre(
        'Strategy',
        limit: 10, // Reduced from 12
        includeAdultContent: includeAdultContent,
      ),
    ]).then((results) {
      if (mounted) {
        // Deduplicate against already loaded games
        final allExisting = [..._popularGames, ..._featuredGames, ..._trendingGames, ..._actionGames];
        final deduplicatedRpg = _deduplicateAcrossSections(results[0], allExisting);
        final deduplicatedStrategy = _deduplicateAcrossSections(results[1], [...allExisting, ...deduplicatedRpg]);
        
        setState(() {
          _rpgGames = deduplicatedRpg;
          _strategyGames = deduplicatedStrategy;
        });
      }
    }).catchError((e) {
      debugPrint('Error loading batch 2: $e');
    });
    
    // Batch 3: GOTY and personalized (load in parallel) - reduced limits
    Future.wait([
      IGDBService.instance.getGOTYCandidates(
        year: DateTime.now().year - 1,
        limit: 10, // Reduced from 12
        includeAdultContent: includeAdultContent,
      ),
      RecommendationService.instance.getPersonalizedRecommendations(limit: 8), // Reduced from 10
    ]).then((results) {
      if (mounted) {
        // Deduplicate against already loaded games
        final allExisting = [..._popularGames, ..._featuredGames, ..._trendingGames, ..._actionGames, ..._rpgGames, ..._strategyGames];
        final deduplicatedGoty = _deduplicateAcrossSections(results[0] as List<Game>, allExisting);
        final deduplicatedSuggested = _deduplicateAcrossSections(results[1] as List<Game>, [...allExisting, ...deduplicatedGoty]);
        
        setState(() {
          _gotyGames = deduplicatedGoty;
          _suggestedGames = deduplicatedSuggested;
        });
      }
    }).catchError((e) {
      debugPrint('Error loading batch 3: $e');
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildPlayStoreHeader(theme),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(theme)
                  : _buildMainContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAllGames,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Popular Section
            _buildPopularSection(theme),
            const SizedBox(height: 32),
            
            // Recent Reviews Section
            _buildRecentReviewsSection(theme),
            const SizedBox(height: 32),
            
            // For You Section
            _buildForYouSection(theme),
            const SizedBox(height: 32),
            
            // Additional Sections
            _buildHorizontalGameSection('Trending now', _trendingGames, 'trending', theme),
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

  Widget _buildPlayStoreHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // App logo/icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.videogame_asset,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Home',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          // Notification bell
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularSection(ThemeData theme) {
    final displayGames = _featuredGames.isNotEmpty ? _featuredGames : _popularGames;
    if (displayGames.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240, // Reduced from 320
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayGames.take(5).length,
              itemBuilder: (context, index) {
                final game = displayGames[index];
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildPopularGameCard(game, theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularGameCard(Game game, ThemeData theme) {
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
        width: 140, // Reduced from 180
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // Reduced from 16
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), // Reduced shadow
              blurRadius: 8, // Reduced from 12
              offset: const Offset(0, 4), // Reduced from 6
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Game Cover Image
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
                          size: 36, // Reduced from 48
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: Icon(
                        Icons.videogame_asset,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 36,
                      ),
                    ),
              
              // Gradient Overlay
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
              
              // Game Title
              Positioned(
                bottom: 12, // Reduced from 16
                left: 12, // Reduced from 16
                right: 12, // Reduced from 16
                child: Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover full catalog',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore thousands of games across all genres and platforms',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForYouSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For you',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Personalized Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Add games to your library and rate them to get personalized recommendations.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (_suggestedGames.isNotEmpty) ...[
                  Text(
                    'Recommended Games',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestedGames.take(5).length,
                      itemBuilder: (context, index) {
                        final game = _suggestedGames[index];
                        return _buildSmallGameCard(game, theme);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallGameCard(Game game, ThemeData theme) {
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
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: game.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: game.coverImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surface,
                          child: Icon(
                            Icons.videogame_asset,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 24,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surface,
                          child: Icon(
                            Icons.videogame_asset,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surface,
                        child: Icon(
                          Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
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
                          Icon(Icons.star, color: ThemeService().starColor, size: 16),
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

  Widget _buildRecentReviewsSection(ThemeData theme) {
    // Always show the section for debugging, even if empty
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent reviews',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'from friends (${_friendReviews.length})',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          if (_friendReviews.isEmpty)
            Container(
              height: 60, // Significantly reduced from 80
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row( // Changed from Column to Row for horizontal layout
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: 18, // Reduced from 20
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No friend reviews yet',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Add friends to see their reviews here',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 220, // Reduced from 280
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _friendReviews.length,
                itemBuilder: (context, index) {
                  // Apply animation only to the first item (newest review)
                  if (index == 0) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildRecentReviewCard(_friendReviews[index], theme),
                      ),
                    );
                  }
                  return _buildRecentReviewCard(_friendReviews[index], theme);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentReviewCard(UserRating review, ThemeData theme) {
    final rating = review.rating;
    final reviewText = review.review;
    final username = review.displayName ?? review.username;
    final profileImage = review.profileImage;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(
              gameId: review.gameId,
            ),
          ),
        );
      },
      child: Container(
        width: 180,
        height: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Game cover on left, rating/likes on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game cover with shadow effect
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FutureBuilder<Game?>(
                      future: _getGameDetails(review.gameId),
                      builder: (context, snapshot) {
                        return Container(
                          height: 80,
                          width: 60,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: snapshot.hasData && snapshot.data != null
                              ? CachedNetworkImage(
                                  imageUrl: snapshot.data!.coverImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: Icon(
                                      Icons.games,
                                      size: 24,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      Icons.games,
                                      size: 24,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.games,
                                    size: 24,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                
                // Rating and likes on the right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: ThemeService().starColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(0),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${review.likeCount}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Review text
            Expanded(
              child: reviewText != null && reviewText.isNotEmpty
                  ? Text(
                      reviewText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      'No review text',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            
            // User info at bottom
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: profileImage != null && profileImage.isNotEmpty
                      ? CachedNetworkImageProvider(profileImage)
                      : null,
                  child: profileImage == null || profileImage.isEmpty
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    username,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get game details for cover image
  Future<Game?> _getGameDetails(String gameId) async {
    try {
      final game = await IGDBService.instance.getGameDetails(gameId);
      return game;
    } catch (e) {
      return null;
    }
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
                      Icon(Icons.star, color: ThemeService().starColor, size: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: games.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: _buildPopularGameCard(games[index], theme),
              );
            },
          ),
        ),
      ],
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
                        Icon(Icons.star, color: ThemeService().starColor, size: 12),
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