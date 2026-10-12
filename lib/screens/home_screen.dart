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
import 'notifications_screen.dart';
import 'game_detail_screen.dart';
import 'category_games_screen.dart';
import 'search_screen.dart';
import 'main_screen.dart';
import '../utils/date_format.dart';
import '../services/recommendation_service.dart';

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
  List<Game> _strategyGames = [];
  List<Game> _featuredGames = [];
  List<Game> _gotyGames = [];
  List<Game> _suggestedGames = [];
  List<UserRating> _friendReviews = [];
  List<UserRating> _myRecentRatings = [];
  List<UserRating> _trendingReviews = [];
  List<Map<String, dynamic>> _communityTopRated = [];
  bool _isLoading = true; // Hot reload trigger - Updated UI
  bool _isLoadingInProgress = false; // Prevent multiple simultaneous loads

  @override
  void initState() {
    super.initState();
    _loadAllGames();
  }

  @override
  void dispose() {
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

      // Load friend reviews in the background (immediate for refresh)
      if (mounted) {
        _loadFriendReviews();
        _loadFeedExtras();
      }
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

  Future<void> _loadFriendReviews() async {
    try {
      debugPrint('🔍 Loading friend reviews...');
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No current user found');
        return;
      }

      debugPrint('✅ Current user: ${currentUser.uid}');
      final friendReviews = await RatingService.getFriendRecentRatings(
        currentUser.uid,
        limit: 10,
      );
      
      debugPrint('📊 Found ${friendReviews.length} friend reviews');
      
      if (mounted) {
        setState(() {
          _friendReviews = friendReviews;
        });
        debugPrint('🔄 Updated UI with ${_friendReviews.length} friend reviews');
      }
    } catch (e) {
      debugPrint('❌ Error loading friend reviews: $e');
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
            _buildFeedHeader(theme),
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
            // Feed layout: popular, activity, trending reviews, community top rated
            _buildPopularRow(theme),
            const SizedBox(height: 20),
            _buildActivityFeed(theme),
            const SizedBox(height: 12),
            _buildTrendingReviews(theme),
            const SizedBox(height: 12),
            _buildCommunityTopRated(theme),
            const SizedBox(height: 28),
            
            // For You Section
            _buildForYouSection(theme),
            const SizedBox(height: 32),
            
            // Additional Sections
            _buildHorizontalGameSection('Trending now', _trendingGames, 'trending', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('Best of ${DateTime.now().year - 1}', _gotyGames, 'goty', theme),
            const SizedBox(height: 16),
            _buildHorizontalGameSection('Top shooters', _actionGames, 'shooter', theme),
            const SizedBox(height: 60),
          ],
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
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
                  _suggestedGames.isEmpty
                      ? 'Finding games for you…'
                      : RecommendationService.instance.lastWasPersonalized
                          ? 'Picked from the genres you rate highest, leaving out games already in your library.'
                          : 'Rate a few games to get recommendations tailored to you. Until then, here\'s what\'s popular.',
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
          _buildHorizontalGameSection('Shooters', _actionGames, 'shooter', theme),
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
                      game.subtitle,
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

  // ========== FEED LAYOUT (header, popular, activity, trending, top rated) ==========

  Future<void> _loadFeedExtras() async {
    final currentUser = FirebaseAuthService.instance.currentUser;

    // Your own latest ratings, shown in "My Activity & Feed" with friends'.
    if (currentUser != null) {
      RatingService.getUserRecentRatings(currentUser.uid, limit: 5).then((mine) {
        if (mounted) setState(() => _myRecentRatings = mine);
      }).catchError((e) => debugPrint('Error loading own ratings: $e'));
    }

    // Trending reviews: most-liked written reviews, topped up with recent ones.
    () async {
      try {
        final liked = await RatingService.getPopularReviewsOptimized(limit: 20);
        final withText = liked.where((r) => (r.review ?? '').trim().isNotEmpty).toList();
        if (withText.length < 5) {
          final recent = await RatingService.getAllRecentRatings(limit: 60);
          final seen = withText.map((r) => r.id).toSet();
          withText.addAll(recent.where(
              (r) => (r.review ?? '').trim().isNotEmpty && !seen.contains(r.id)));
        }
        // At most two per person, so one prolific reviewer doesn't fill the list.
        final perUser = <String, int>{};
        final varied = withText.where((r) => (perUser[r.userId] = (perUser[r.userId] ?? 0) + 1) <= 2).toList();
        if (mounted) setState(() => _trendingReviews = varied.take(5).toList());
      } catch (e) {
        debugPrint('Error loading trending reviews: $e');
      }
    }();

    // Community top rated: highest average GameLog rating.
    RatingService.getTopRatedGames(limit: 12).then((top) {
      if (mounted) setState(() => _communityTopRated = top);
    }).catchError((e) => debugPrint('Error loading community top rated: $e'));
  }

  /// Latest ratings from you and your friends, newest first.
  List<UserRating> get _activityFeed {
    final seen = <String>{};
    final all = [..._myRecentRatings, ..._friendReviews]
        .where((r) => seen.add('${r.userId}_${r.gameId}'))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all.take(4).toList();
  }

  void _openSearchTab() {
    context.findAncestorStateOfType<MainScreenState>()?.switchToTab(2);
  }

  void _openGame(String gameId, {Game? game}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: gameId, initialGame: game)),
    );
  }

  Widget _buildFeedHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.videogame_asset, color: theme.colorScheme.onPrimary, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            'GameLog',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: theme.colorScheme.surface,
              shape: StadiumBorder(
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _openSearchTab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Search games…',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            ),
            icon: Icon(Icons.notifications_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
  }

  Widget _feedSectionHeader(ThemeData theme, String title, {VoidCallback? onMore, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(right: 8), child: trailing),
          if (onMore != null)
            IconButton(
              onPressed: onMore,
              icon: Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              tooltip: 'See all',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _starRow(double rating, {double size = 12}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = i < rating.floor()
            ? Icons.star
            : (i < rating ? Icons.star_half : Icons.star_border);
        return Icon(icon, size: size, color: ThemeService().starColor);
      }),
    );
  }

  Widget _coverThumb(ThemeData theme, String? url, {double width = 44, double height = 58}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.videogame_asset, size: 18, color: theme.colorScheme.primary),
              ),
      ),
    );
  }

  Widget _avatar(ThemeData theme, String? imageUrl, String name, {double radius = 14}) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundImage: hasImage ? CachedNetworkImageProvider(imageUrl) : null,
      child: hasImage
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatShortDate(date);
  }

  // ---------- Popular Games This Week ----------

  Widget _buildPopularRow(ThemeData theme) {
    final games = _popularGames.isNotEmpty ? _popularGames : _featuredGames;
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _feedSectionHeader(
          theme,
          'Popular Games',
          onMore: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CategoryGamesScreen(
                categoryTitle: 'Popular Games',
                categoryType: 'popular',
              ),
            ),
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () => _openGame(game.id, game: game),
                child: SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: index == 0
                              ? Border.all(color: theme.colorScheme.primary, width: 2)
                              : null,
                          boxShadow: index == 0
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: _coverThumb(theme, game.coverImage, width: 100, height: 134),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (game.averageRating > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              game.averageRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Icon(Icons.star, size: 11, color: ThemeService().starColor),
                          ],
                        ],
                      ),
                      if (game.totalReviews > 0)
                        Text(
                          '${_compactCount(game.totalReviews)} ratings',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
    );
  }

  String _compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ---------- My Activity & Feed ----------

  Widget _buildActivityFeed(ThemeData theme) {
    final feed = _activityFeed;
    final currentUid = FirebaseAuthService.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _feedSectionHeader(
          theme,
          'My Activity & Feed',
          trailing: FilledButton.icon(
            onPressed: _openSearchTab,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log a game'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: feed.isEmpty
              ? _feedEmptyCard(
                  theme,
                  Icons.people_outline,
                  'Nothing here yet',
                  'Rate a game or add friends to see activity here.',
                )
              : Column(
                  children: [
                    for (final review in feed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildActivityItem(theme, review, isMine: review.userId == currentUid),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(ThemeData theme, UserRating review, {required bool isMine}) {
    final name = isMine ? 'You' : (review.displayName ?? review.username);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openGame(review.gameId),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FutureBuilder<Game?>(
            future: _gameFor(review.gameId),
            builder: (context, snapshot) {
              final game = snapshot.data;
              final title = game?.title ?? review.gameTitle ?? 'a game';
              return Row(
                children: [
                  _coverThumb(theme, game?.coverImage),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 13, color: muted),
                            children: [
                              TextSpan(
                                text: name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: ' rated '),
                              TextSpan(
                                text: title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _starRow(review.rating, size: 12),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (review.review ?? '').trim().isNotEmpty ? 'Reviewed' : 'Rated',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_timeAgo(review.updatedAt), style: TextStyle(fontSize: 11, color: muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, size: 13, color: muted),
                  const SizedBox(width: 2),
                  Text('${review.likeCount}', style: TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(width: 8),
                  Icon(Icons.chat_bubble, size: 12, color: muted),
                  const SizedBox(width: 2),
                  Text('${review.commentCount}', style: TextStyle(fontSize: 11, color: muted)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- Trending Reviews ----------

  Widget _buildTrendingReviews(ThemeData theme) {
    if (_trendingReviews.isEmpty) return const SizedBox.shrink();
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _feedSectionHeader(
          theme,
          'Trending Reviews',
          onMore: () => context.findAncestorStateOfType<MainScreenState>()?.switchToTab(1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final review in _trendingReviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openGame(review.gameId),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: FutureBuilder<Game?>(
                          future: _gameFor(review.gameId),
                          builder: (context, snapshot) {
                            final game = snapshot.data;
                            final name = review.displayName ?? review.username;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _avatar(theme, review.profileImage, name),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          style: TextStyle(fontSize: 13, color: muted),
                                          children: [
                                            TextSpan(
                                              text: name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const TextSpan(text: ' rated '),
                                            TextSpan(
                                              text: game?.title ?? review.gameTitle ?? 'a game',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const TextSpan(text: '  '),
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.middle,
                                              child: _starRow(review.rating, size: 12),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        review.review!.trim(),
                                        style: TextStyle(fontSize: 12, color: muted, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _coverThumb(theme, game?.coverImage),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Community Top Rated ----------

  Widget _buildCommunityTopRated(ThemeData theme) {
    if (_communityTopRated.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _feedSectionHeader(theme, 'Community Top Rated'),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _communityTopRated.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = _communityTopRated[index];
              final gameId = entry['gameId'] as String;
              final average = (entry['averageRating'] as num).toDouble();
              final count = entry['totalRatings'] as int;
              return FutureBuilder<Game?>(
                future: _gameFor(gameId),
                builder: (context, snapshot) {
                  final game = snapshot.data;
                  return GestureDetector(
                    onTap: () => _openGame(gameId, game: game),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _coverThumb(theme, game?.coverImage, width: 120, height: 104),
                          const SizedBox(height: 6),
                          Text(
                            game?.title ?? '…',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                average.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Icon(Icons.star, size: 12, color: ThemeService().starColor),
                              const SizedBox(width: 4),
                              Text(
                                '($count)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
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

  Widget _feedEmptyCard(ThemeData theme, IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // One lookup per game while this screen is alive, even across rebuilds.
  final Map<String, Future<Game?>> _gameLookups = {};

  Future<Game?> _gameFor(String gameId) => _gameLookups.putIfAbsent(gameId, () async {
        try {
          return await IGDBService.instance.getGameDetails(gameId);
        } catch (e) {
          return null;
        }
      });

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
                  game.subtitle,
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
              game.subtitle,
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
                    game.subtitle,
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
