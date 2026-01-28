import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
import '../services/content_filter_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import 'notifications_screen.dart';
import 'game_detail_screen.dart';
import 'category_games_screen.dart';
import 'search_screen.dart';

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
  List<Game> _indieGames = [];
  List<Game> _featuredGames = [];
  bool _isLoading = true;
  String _userName = 'Gamer';
  String _greeting = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    _setGreeting();
    _loadUserData();
    _loadAllGames();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        final profile = await UserDataService.getUserProfile(currentUser.id);
        if (profile != null && mounted) {
          setState(() {
            _userName = profile['displayName'] ?? profile['username'] ?? 'Gamer';
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadAllGames() async {
    try {
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load the most important sections first with smaller limits for faster initial load
      final trendingGames = await RAWGService.instance.getTrendingGames(
        limit: 10, // Reduced from 12 for faster loading
        includeAdultContent: includeAdultContent,
      );
      final popularGames = await RAWGService.instance.getPopularGames(
        limit: 10, // Reduced from 12 for faster loading
        includeAdultContent: includeAdultContent,
      );
      
      // Create a smaller pool of games for featured section for faster processing
      final allFeaturedCandidates = [
        ...trendingGames.take(10), // Limit candidates
        ...popularGames.take(10),  // Limit candidates
      ];
      
      // Remove duplicates based on game ID (more efficient)
      final Map<String, Game> uniqueGames = {};
      for (final game in allFeaturedCandidates) {
        uniqueGames[game.id] = game;
      }
      final uniqueGamesList = uniqueGames.values.toList();
      
      // Create daily randomized featured games (changes every day)
      final featuredGames = _getDailyRandomizedGames(uniqueGamesList, 6); // Reduced from 8 to 6
      
      setState(() {
        _trendingGames = trendingGames;
        _popularGames = popularGames;
        _featuredGames = featuredGames;
        _isLoading = false;
      });

      // Start animations
      _animationController.forward();

      // Load genre-specific games in the background with longer delay for better performance
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _loadGenreGamesInBackground();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading games: $e'),
            backgroundColor: const Color(0xFFEF4444),
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
      // Load genre games with a longer delay to prioritize main content
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if adult content is enabled
      final includeAdultContent = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Load genre games with smaller limits for better performance
      final results = await Future.wait([
        RAWGService.instance.getGamesByGenre('action', limit: 8, includeAdultContent: includeAdultContent), // Reduced from 12
        RAWGService.instance.getGamesByGenre('role-playing-games-rpg', limit: 8, includeAdultContent: includeAdultContent), // Reduced from 12
        RAWGService.instance.getGamesByGenre('indie', limit: 8, includeAdultContent: includeAdultContent), // Reduced from 12
      ]);

      if (mounted) {
        setState(() {
          _actionGames = results[0];
          _rpgGames = results[1];
          _indieGames = results[2];
        });
      }
    } catch (e) {
      // Don't show error to user since this is background loading
      debugPrint('Error loading genre games: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : RefreshIndicator(
                onRefresh: _loadAllGames,
                color: const Color(0xFF6366F1),
                backgroundColor: const Color(0xFF1F2937),
                child: CustomScrollView(
                  slivers: [
                    _buildModernHeader(),
                    _buildFeaturedSection(),
                    _buildQuickActions(),
                    _buildGameSections(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading amazing games...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 20, // Reduced from 24
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF374151),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SearchScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white70,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF374151),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6366F1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Discover Your Next',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Favorite Game',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Explore trending titles and hidden gems',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SearchScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Explore Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.white,
                          size: 28,
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
  }

  Widget _buildFeaturedSection() {
    if (_featuredGames.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Featured Games',
                    style: TextStyle(
                      fontSize: 18, // Reduced from 20
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Daily Picks',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280, // Increased from 220
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88), // Increased from 0.85
                  itemCount: _featuredGames.length,
                  itemBuilder: (context, index) {
                    final game = _featuredGames[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 16), // Increased from 12
                      child: GestureDetector(
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
                            borderRadius: BorderRadius.circular(24), // Increased from 20
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4), // Increased shadow
                                blurRadius: 20, // Increased from 16
                                offset: const Offset(0, 10), // Increased from 8
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24), // Increased from 20
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                game.coverImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: game.coverImage,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: const Color(0xFF1F2937),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                              strokeWidth: 3, // Increased from 2
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: const Color(0xFF1F2937),
                                          child: const Icon(
                                            Icons.videogame_asset,
                                            color: Colors.white54,
                                            size: 64, // Increased from 48
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF1F2937),
                                        child: const Icon(
                                          Icons.videogame_asset,
                                          color: Colors.white54,
                                          size: 64, // Increased from 48
                                        ),
                                      ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.85), // Increased opacity
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20, // Increased from 16
                                  left: 20, // Increased from 16
                                  right: 20, // Increased from 16
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        game.title,
                                        style: const TextStyle(
                                          fontSize: 20, // Increased from 18
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8), // Increased from 6
                                      if (game.developer.isNotEmpty) ...[
                                        Text(
                                          game.developer,
                                          style: const TextStyle(
                                            fontSize: 14, // Increased from 13
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6), // Increased from 4
                                      ],
                                      if (game.averageRating > 0)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Color(0xFFFBBF24),
                                              size: 18, // Increased from 16
                                            ),
                                            const SizedBox(width: 6), // Increased from 4
                                            Text(
                                              game.averageRating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16, // Increased from 14
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 10), // Increased from 8
                                            Text(
                                              '${game.totalReviews} reviews',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13, // Increased from 12
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 20, // Increased from 16
                                  right: 20, // Increased from 16
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Increased padding
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                      ),
                                      borderRadius: BorderRadius.circular(16), // Increased from 12
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.5), // Increased opacity
                                          blurRadius: 12, // Increased from 8
                                          offset: const Offset(0, 4), // Increased from 2
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Featured',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12, // Increased from 11
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'Trending',
                      'See what\'s hot',
                      Icons.trending_up,
                      const Color(0xFFEF4444),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CategoryGamesScreen(
                              categoryTitle: 'Trending Now',
                              categoryType: 'trending',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Popular',
                      'All-time favorites',
                      Icons.star,
                      const Color(0xFFF59E0B),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CategoryGamesScreen(
                              categoryTitle: 'Popular Games',
                              categoryType: 'popular',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'Action',
                      'High-octane games',
                      Icons.flash_on,
                      const Color(0xFF10B981),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CategoryGamesScreen(
                              categoryTitle: 'Action Games',
                              categoryType: 'action',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'RPG',
                      'Epic adventures',
                      Icons.auto_stories,
                      const Color(0xFF8B5CF6),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CategoryGamesScreen(
                              categoryTitle: 'RPG Games',
                              categoryType: 'rpg',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameSections() {
    return SliverList(
      delegate: SliverChildListDelegate([
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildModernGameSection('Trending Now', _trendingGames, 'trending'),
              const SizedBox(height: 20), // Reduced from 24
              _buildModernGameSection('Popular Games', _popularGames, 'popular'),
              const SizedBox(height: 20), // Reduced from 24
              _buildModernGameSection('Action Games', _actionGames, 'action'),
              const SizedBox(height: 20), // Reduced from 24
              _buildModernGameSection('RPG Games', _rpgGames, 'rpg'),
              const SizedBox(height: 20), // Reduced from 24
              _buildModernGameSection('Indie Games', _indieGames, 'indie'),
              const SizedBox(height: 60), // Reduced from 80
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildModernGameSection(String title, List<Game> games, String categoryType) {
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
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (games.isNotEmpty)
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF6366F1),
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: games.isEmpty
                ? _buildEmptyGameSection()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 6),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return _buildModernGameCard(game, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGameSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.games_outlined,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loading games...',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernGameCard(Game game, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'game_${game.id}_${DateTime.now().millisecondsSinceEpoch}_$index', // Make tags unique with timestamp
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        game.coverImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: game.coverImage,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF1F2937),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF1F2937),
                                  child: const Icon(
                                    Icons.videogame_asset,
                                    color: Colors.white54,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF1F2937),
                                child: const Icon(
                                  Icons.videogame_asset,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                        if (game.averageRating > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2937).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
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
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              game.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (game.developer.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                game.developer,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white60,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuickRating(Game game) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF374151)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.star,
                  color: Color(0xFF6366F1),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rate ${game.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to open game details and rate',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Icon(
                        Icons.star_border,
                        color: Color(0xFFFBBF24),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Rate Game',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: Long press any game for quick rating',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}