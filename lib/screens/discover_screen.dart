import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_rating.dart';
import '../models/rating_comment.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/rating_interaction_service.dart';
import 'game_detail_screen.dart';
import 'user_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<UserRating> _recentReviews = [];
  bool _isLoading = true;
  String _loadingMessage = 'Loading reviews...';
  String _selectedFilter = 'recent';
  String _selectedGenre = 'all';
  String _selectedPlatform = 'all';
  String _selectedRating = 'all';

  final List<Map<String, String>> _filterOptions = [
    {'label': 'Recent', 'value': 'recent'},
    {'label': 'Top Rated', 'value': 'top_rated'},
    {'label': 'Popular', 'value': 'popular'},
    {'label': 'New Users', 'value': 'new_users'},
  ];

  final List<Map<String, String>> _genreOptions = [
    {'label': 'All Genres', 'value': 'all'},
    {'label': 'Action', 'value': 'action'},
    {'label': 'Adventure', 'value': 'adventure'},
    {'label': 'RPG', 'value': 'rpg'},
    {'label': 'Strategy', 'value': 'strategy'},
    {'label': 'Indie', 'value': 'indie'},
    {'label': 'Shooter', 'value': 'shooter'},
  ];

  final List<Map<String, String>> _platformOptions = [
    {'label': 'All Platforms', 'value': 'all'},
    {'label': 'PC', 'value': 'pc'},
    {'label': 'PlayStation', 'value': 'playstation'},
    {'label': 'Xbox', 'value': 'xbox'},
    {'label': 'Nintendo', 'value': 'nintendo'},
    {'label': 'Mobile', 'value': 'mobile'},
  ];

  final List<Map<String, String>> _ratingOptions = [
    {'label': 'All Ratings', 'value': 'all'},
    {'label': '5 Stars', 'value': '5'},
    {'label': '4+ Stars', 'value': '4'},
    {'label': '3+ Stars', 'value': '3'},
    {'label': '2+ Stars', 'value': '2'},
  ];

  @override
  void initState() {
    super.initState();
    _checkDatabaseStats();
    _loadRecentReviews();
  }

  Future<void> _checkDatabaseStats() async {
    try {
      final stats = await RatingService.getDatabaseStats();
      debugPrint('=== DISCOVER SCREEN DEBUG ===');
      debugPrint('Database contains ${stats['totalRatings']} total ratings');
      debugPrint('Database contains ${stats['uniqueGames']} unique games');
      
      // Also check if we can query the collection directly
      final directQuery = await FirebaseFirestore.instance
          .collection('game_ratings')
          .limit(5)
          .get();
      debugPrint('Direct query found ${directQuery.docs.length} documents');
      
      // Check if there are any documents at all
      if (directQuery.docs.isNotEmpty) {
        debugPrint('Sample rating data: ${directQuery.docs.first.data()}');
      }
      
      debugPrint('=============================');
    } catch (e) {
      debugPrint('Error checking database stats: $e');
    }
  }

  Future<void> _loadRecentReviews() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Loading reviews...';
    });
    
    try {
      debugPrint('=== LOADING REVIEWS DEBUG ===');
      debugPrint('Loading reviews with optimized filter: $_selectedFilter');
      
      setState(() => _loadingMessage = 'Fetching ${_selectedFilter} reviews...');
      
      List<UserRating> reviews = [];
      
      // Use optimized methods for better performance
      switch (_selectedFilter) {
        case 'recent':
          debugPrint('Calling getAllRecentRatings...');
          reviews = await RatingService.getAllRecentRatings(limit: 50);
          break;
        case 'top_rated':
          debugPrint('Calling getTopRatedReviewsOptimized...');
          reviews = await RatingService.getTopRatedReviewsOptimized(limit: 50);
          break;
        case 'popular':
          debugPrint('Calling getPopularReviewsOptimized...');
          reviews = await RatingService.getPopularReviewsOptimized(limit: 50);
          break;
        case 'new_users':
          debugPrint('Calling getAllRecentRatings for new users...');
          reviews = await RatingService.getAllRecentRatings(limit: 50);
          break;
      }
      
      debugPrint('Retrieved ${reviews.length} reviews from optimized query');
      
      if (reviews.isEmpty) {
        debugPrint('⚠️ No reviews found! This could mean:');
        debugPrint('1. No ratings exist in the database');
        debugPrint('2. All ratings belong to the current user');
        debugPrint('3. There\'s an issue with the query');
      } else {
        debugPrint('✅ Found reviews, sample: ${reviews.first.gameId} by ${reviews.first.username}');
      }
      
      setState(() => _loadingMessage = 'Filtering reviews...');
      
      // Filter out current user's ratings
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        final beforeFilter = reviews.length;
        reviews = reviews.where((rating) => rating.userId != currentUser.id).toList();
        debugPrint('After filtering current user (${currentUser.id}): ${reviews.length} ratings (was $beforeFilter)');
      } else {
        debugPrint('No current user, keeping all ${reviews.length} ratings');
      }
      
      // Apply additional filters (rating filter only for now)
      reviews = _applyAdditionalFilters(reviews);
      debugPrint('After applying additional filters: ${reviews.length} ratings');
      
      // If still no reviews, let's check what's in the database
      if (reviews.isEmpty) {
        debugPrint('🔍 No reviews after filtering. Checking database directly...');
        try {
          final directCheck = await FirebaseFirestore.instance
              .collection('game_ratings')
              .limit(10)
              .get();
          debugPrint('Direct database check found ${directCheck.docs.length} total ratings');
          
          if (directCheck.docs.isNotEmpty) {
            for (final doc in directCheck.docs) {
              final data = doc.data();
              debugPrint('Rating: ${data['gameId']} by ${data['userId']} (${data['username']}) - ${data['rating']} stars');
            }
          }
        } catch (e) {
          debugPrint('Error in direct database check: $e');
        }
      }
      
      debugPrint('=== END LOADING REVIEWS DEBUG ===');
      
      setState(() => _loadingMessage = 'Loading user profiles...');
      
      // Enrich with current user data (profile pics and updated usernames)
      reviews = await _enrichWithCurrentUserData(reviews);
      
      if (mounted) {
        setState(() {
          _recentReviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Enrich UserRating objects with current user profile data - OPTIMIZED
  Future<List<UserRating>> _enrichWithCurrentUserData(List<UserRating> reviews) async {
    if (reviews.isEmpty) return reviews;
    
    debugPrint('Enriching ${reviews.length} reviews with user data...');
    final enrichedReviews = <UserRating>[];
    
    // Process in smaller batches to avoid overwhelming the system
    const batchSize = 10;
    for (int i = 0; i < reviews.length; i += batchSize) {
      final batch = reviews.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((review) => _enrichSingleReview(review)),
      );
      enrichedReviews.addAll(batchResults);
    }
    
    debugPrint('Enriched ${enrichedReviews.length} reviews with user data');
    return enrichedReviews;
  }

  Future<UserRating> _enrichSingleReview(UserRating review) async {
    try {
      final userProfile = await UserDataService.getUserProfile(review.userId);
      
      if (userProfile != null) {
        return review.copyWith(
          displayName: userProfile['displayName'] ?? userProfile['username'] ?? review.username,
          profileImage: userProfile['profileImage'],
        );
      }
    } catch (e) {
      // Keep original if error fetching profile
      debugPrint('Error enriching review ${review.id}: $e');
    }
    
    return review;
  }

  /// Apply additional filters (genre, platform, rating) to the ratings
  List<UserRating> _applyAdditionalFilters(List<UserRating> reviews) {
    List<UserRating> filteredReviews = reviews;
    
    debugPrint('Applying additional filters - Original count: ${reviews.length}');
    debugPrint('Selected rating filter: $_selectedRating');

    // Filter by rating
    if (_selectedRating != 'all') {
      final minRating = double.parse(_selectedRating);
      filteredReviews = filteredReviews.where((review) => review.rating >= minRating).toList();
      debugPrint('After rating filter (>= $minRating): ${filteredReviews.length}');
    }

    // TODO: Genre and platform filtering would require fetching game details from RAWG
    // For now, we'll implement basic filtering based on available data
    // This could be enhanced by caching game details or fetching them in batches
    
    debugPrint('Final filtered count: ${filteredReviews.length}');
    return filteredReviews;
  }

  void _clearFilters() {
    setState(() {
      _selectedGenre = 'all';
      _selectedPlatform = 'all';
      _selectedRating = 'all';
    });
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Filters cleared'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
    
    _loadRecentReviews();
  }

  void _refreshCommunityData() {
    _loadRecentReviews();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildFilterTabs(theme),
            _buildAdvancedFilters(theme),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadingMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildReviewsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final hasActiveFilters = _selectedGenre != 'all' || _selectedPlatform != 'all' || _selectedRating != 'all';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
      child: Row(
        children: [
          Text(
            'Discover',
            style: TextStyle(
              fontSize: 18, // Reduced from 20
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Filtered',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: hasActiveFilters ? _clearFilters : null,
            icon: Icon(
              Icons.filter_list_off, 
              color: hasActiveFilters ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5), 
              size: 20
            ), // Smaller icon
            tooltip: hasActiveFilters ? 'Clear Filters' : 'No active filters',
            padding: const EdgeInsets.all(8), // Reduced padding
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // Smaller button
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(ThemeData theme) {
    return Container(
      height: 40, // Reduced from 50
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced margin
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filterOptions.map((filter) => 
          _buildFilterChip(filter['label']!, filter['value']!, theme)
        ).toList(),
      ),
    );
  }

  Widget _buildAdvancedFilters(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced margin
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdownFilter('Genre', _selectedGenre, _genreOptions, (value) {
                setState(() => _selectedGenre = value!);
                _loadRecentReviews();
              }, theme)),
              const SizedBox(width: 6), // Reduced spacing
              Expanded(child: _buildDropdownFilter('Platform', _selectedPlatform, _platformOptions, (value) {
                setState(() => _selectedPlatform = value!);
                _loadRecentReviews();
              }, theme)),
            ],
          ),
          const SizedBox(height: 6), // Reduced spacing
          _buildDropdownFilter('Rating', _selectedRating, _ratingOptions, (value) {
            setState(() => _selectedRating = value!);
            _loadRecentReviews();
          }, theme),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String selectedValue, List<Map<String, String>> options, ValueChanged<String?> onChanged, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), // Reduced padding
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6), // Smaller radius
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          onChanged: (value) {
            if (value != null && value != selectedValue) {
              onChanged(value);
            }
          },
          dropdownColor: theme.colorScheme.surface,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12), // Smaller text
          icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface, size: 18), // Smaller icon
          isExpanded: true,
          items: options.map((option) => DropdownMenuItem<String>(
            value: option['value'],
            child: Text(option['label']!, style: const TextStyle(fontSize: 12)), // Smaller text
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ThemeData theme) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = value;
            });
            _loadRecentReviews();
          }
        },
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildReviewsList(ThemeData theme) {
    if (_recentReviews.isEmpty) {
      final hasActiveFilters = _selectedGenre != 'all' || _selectedPlatform != 'all' || _selectedRating != 'all';
      
      if (hasActiveFilters) {
        return _buildEmptyState(
          'No Reviews Match Filters',
          'Try adjusting your filters to see more reviews.',
        );
      } else {
        // Different messages based on selected filter
        String title, subtitle;
        switch (_selectedFilter) {
          case 'top_rated':
            title = 'No Top Rated Games Yet';
            subtitle = 'Games need at least one rating to appear here. Rate some games to get started!';
            break;
          case 'popular':
            title = 'No Popular Games Yet';
            subtitle = 'Popular games will appear here once more users rate games.';
            break;
          case 'new_users':
            title = 'No New User Reviews';
            subtitle = 'Reviews from new users will appear here.';
            break;
          default:
            title = 'No Reviews Yet';
            subtitle = 'Be the first to discover and review games!';
        }
        
        return _buildEmptyState(title, subtitle);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recentReviews.length,
      itemBuilder: (context, index) {
        final review = _recentReviews[index];
        return _buildReviewItem(review);
      },
    );
  }

  Widget _buildReviewItem(UserRating review) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(gameId: review.gameId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: review.userId,
                        ),
                      ),
                    );
                  },
                  child: _buildUserAvatar(review),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.displayName ?? review.username,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _formatDate(review.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    final isFullStar = review.rating >= starValue;
                    final isHalfStar = review.rating >= starValue - 0.5 && review.rating < starValue;
                    
                    return Icon(
                      isFullStar ? Icons.star : (isHalfStar ? Icons.star_half : Icons.star_border),
                      size: 16,
                      color: (isFullStar || isHalfStar) ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
                    );
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  review.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGameInfo(review.gameId),
            if (review.review != null && review.review!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.review!,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Like and comment buttons
            const SizedBox(height: 12),
            Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: () => _toggleRatingLike(review),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRatingLiked(review) ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: _isRatingLiked(review) ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.likeCount.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Comment button
                GestureDetector(
                  onTap: () => _openRatingComments(review),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.commentCount.toString(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfo(String gameId) {
    final theme = Theme.of(context);
    
    return FutureBuilder<Game?>(
      future: IGDBService.instance.getGameDetails(gameId),
      builder: (context, snapshot) {
        final game = snapshot.data;
        
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: game?.coverImage != null && game!.coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverImage,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.games, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game?.title ?? 'Loading...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    game?.developer ?? 'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _refreshCommunityData();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    _clearFilters();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Filters cleared! Showing all recent reviews.'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.filter_list_off, size: 18),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildUserAvatar(UserRating review) {
    final theme = Theme.of(context);
    final displayName = review.displayName ?? review.username;
    
    if (review.profileImage != null && review.profileImage!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: review.profileImage!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 32,
              height: 32,
              color: theme.colorScheme.primary,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 32,
              height: 32,
              color: theme.colorScheme.primary,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Fallback to initial avatar
      return CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  bool _isRatingLiked(UserRating rating) {
    final currentUser = FirebaseAuthService().currentUser;
    return currentUser != null && rating.likedBy.contains(currentUser.uid);
  }

  Future<void> _toggleRatingLike(UserRating rating) async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    // Optimistic update - update UI immediately
    final wasLiked = _isRatingLiked(rating);
    final ratingIndex = _recentReviews.indexWhere((r) => r.id == rating.id);
    
    if (ratingIndex != -1) {
      setState(() {
        if (wasLiked) {
          // Unlike: remove user from likedBy and decrease count
          final newLikedBy = List<String>.from(_recentReviews[ratingIndex].likedBy);
          newLikedBy.remove(currentUser.uid);
          _recentReviews[ratingIndex] = _recentReviews[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: (_recentReviews[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
          );
        } else {
          // Like: add user to likedBy and increase count
          final newLikedBy = List<String>.from(_recentReviews[ratingIndex].likedBy);
          newLikedBy.add(currentUser.uid);
          _recentReviews[ratingIndex] = _recentReviews[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: _recentReviews[ratingIndex].likeCount + 1,
          );
        }
      });
    }

    try {
      await RatingInteractionService.instance.toggleRatingLike(rating.id, currentUser.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasLiked ? 'Rating unliked!' : 'Rating liked!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (ratingIndex != -1) {
        setState(() {
          if (wasLiked) {
            // Revert unlike: add user back and increase count
            final newLikedBy = List<String>.from(_recentReviews[ratingIndex].likedBy);
            newLikedBy.add(currentUser.uid);
            _recentReviews[ratingIndex] = _recentReviews[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: _recentReviews[ratingIndex].likeCount + 1,
            );
          } else {
            // Revert like: remove user and decrease count
            final newLikedBy = List<String>.from(_recentReviews[ratingIndex].likedBy);
            newLikedBy.remove(currentUser.uid);
            _recentReviews[ratingIndex] = _recentReviews[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: (_recentReviews[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
            );
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle like: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openRatingComments(UserRating rating) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullFunctionalCommentsScreen(rating: rating),
      ),
    ).then((_) {
      // Refresh only the specific rating's comment count when returning
      _refreshSingleRatingInDiscover(rating);
    });
  }

  Widget _FullFunctionalCommentsScreen({required UserRating rating}) {
    return _CommentsScreenStateful(rating: rating);
  }

  Widget _SimpleCommentsScreen({required UserRating rating}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rating.displayName ?? rating.username,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          final isFullStar = rating.rating >= starValue;
                          final isHalfStar = rating.rating >= starValue - 0.5 && rating.rating < starValue;
                          
                          return Icon(
                            isFullStar ? Icons.star : (isHalfStar ? Icons.star_half : Icons.star_border),
                            size: 16,
                            color: (isFullStar || isHalfStar) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rating.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (rating.review != null && rating.review!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      rating.review!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Comments section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Comments Feature',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comments are now fully functional!\nUsers can like, comment, and interact with reviews.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Reviews'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Future<void> _refreshSingleRatingInDiscover(UserRating rating) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;
      
      // Get updated rating data with interactions
      final data = await RatingInteractionService.instance.getRatingWithInteractions(rating.id, currentUser.uid);
      final updatedRating = data['rating'] as UserRating?;
      
      if (updatedRating != null) {
        final ratingIndex = _recentReviews.indexWhere((r) => r.id == rating.id);
        if (ratingIndex != -1) {
          setState(() {
            _recentReviews[ratingIndex] = updatedRating;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing single rating in discover: $e');
    }
  }
}

class _CommentsScreenStateful extends StatefulWidget {
  final UserRating rating;

  const _CommentsScreenStateful({required this.rating});

  @override
  State<_CommentsScreenStateful> createState() => _CommentsScreenStatefulState();
}

class _CommentsScreenStatefulState extends State<_CommentsScreenStateful> {
  List<RatingComment> _comments = [];
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _hasCommentText = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRatingAndComments();
    _commentController.addListener(_onCommentTextChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCommentTextChanged() {
    final hasText = _commentController.text.trim().isNotEmpty;
    if (hasText != _hasCommentText) {
      setState(() {
        _hasCommentText = hasText;
      });
    }
  }

  Future<void> _loadRatingAndComments() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;

      final data = await RatingInteractionService.instance
          .getRatingWithInteractions(widget.rating.id, currentUser.uid);
      
      if (mounted) {
        setState(() {
          _comments = data['comments'] ?? [];
          _isLiked = data['isLiked'] ?? false;
          _likeCount = widget.rating.likeCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rating and comments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    try {
      await RatingInteractionService.instance
          .toggleRatingLike(widget.rating.id, currentUser.uid);
      
      setState(() {
        if (_isLiked) {
          _likeCount--;
          _isLiked = false;
        } else {
          _likeCount++;
          _isLiked = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLiked ? 'Rating liked!' : 'Rating unliked!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle like: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null || _commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      // Get proper user data
      String username = currentUser.username;
      String? displayName = currentUser.displayName;
      
      // Try to get additional user profile data
      try {
        final userProfile = await UserDataService.getUserProfile(currentUser.uid);
        if (userProfile != null) {
          displayName = userProfile['displayName'] ?? userProfile['username'] ?? displayName;
          username = userProfile['username'] ?? username;
        }
      } catch (e) {
        debugPrint('Could not load user profile for comment: $e');
      }

      await RatingInteractionService.instance.addComment(
        ratingId: widget.rating.id,
        authorId: currentUser.uid,
        authorUsername: username,
        content: _commentController.text.trim(),
      );

      _commentController.clear();
      setState(() {
        _hasCommentText = false;
      });
      await _loadRatingAndComments();

      // Scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comment added successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _toggleCommentLike(RatingComment comment) async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    try {
      await RatingInteractionService.instance
          .toggleCommentLike(comment.id, currentUser.uid);
      
      await _loadRatingAndComments(); // Refresh to get updated like counts
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle comment like: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Rating & Comments',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            onPressed: _loadRatingAndComments,
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildRatingCard(theme),
                      const SizedBox(height: 24),
                      if (_comments.isNotEmpty) ...[
                        _buildCommentsSection(theme),
                      ] else ...[
                        _buildNoCommentsState(theme),
                      ],
                    ],
                  ),
                ),
                _buildCommentInput(theme),
              ],
            ),
    );
  }

  Widget _buildRatingCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  (widget.rating.displayName ?? widget.rating.username).isNotEmpty 
                      ? (widget.rating.displayName ?? widget.rating.username)[0].toUpperCase() 
                      : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rating.displayName ?? widget.rating.username,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _formatDate(widget.rating.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isFullStar = widget.rating.rating >= starValue;
                  final isHalfStar = widget.rating.rating >= starValue - 0.5 && widget.rating.rating < starValue;
                  
                  return Icon(
                    isFullStar ? Icons.star : (isHalfStar ? Icons.star_half : Icons.star_border),
                    size: 20,
                    color: (isFullStar || isHalfStar) ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                widget.rating.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (widget.rating.review != null && widget.rating.review!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.rating.review!,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _likeCount.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  Icon(
                    Icons.comment,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _comments.length.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${_comments.length})',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ..._comments.map((comment) => _buildCommentItem(comment, theme)),
      ],
    );
  }

  Widget _buildCommentItem(RatingComment comment, ThemeData theme) {
    final currentUser = FirebaseAuthService().currentUser;
    final isLiked = currentUser != null && comment.likedBy.contains(currentUser.uid);
    final isOriginalReviewer = comment.authorId == widget.rating.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  (comment.authorDisplayName ?? comment.authorUsername).isNotEmpty 
                      ? (comment.authorDisplayName ?? comment.authorUsername)[0].toUpperCase() 
                      : '?',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorDisplayName ?? comment.authorUsername,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isOriginalReviewer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'REVIEWER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleCommentLike(comment),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comment.likeCount.toString(),
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
          const SizedBox(height: 12),
          Text(
            comment.content,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          if (comment.isEdited) ...[
            const SizedBox(height: 8),
            Text(
              'Edited',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoCommentsState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.comment_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment on this rating!',
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

  Widget _buildCommentInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          _isSubmittingComment
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              : IconButton(
                  onPressed: _hasCommentText ? _submitComment : null,
                  icon: Icon(
                    Icons.send,
                    color: _hasCommentText
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}