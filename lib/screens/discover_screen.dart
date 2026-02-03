import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_rating.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/rating_interaction_service.dart';
import 'game_detail_screen.dart';
import 'user_profile_screen.dart';
// import 'rating_comments_screen.dart';

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
      debugPrint('Loading reviews with optimized filter: $_selectedFilter');
      
      setState(() => _loadingMessage = 'Fetching ${_selectedFilter} reviews...');
      
      List<UserRating> reviews = [];
      
      // Use optimized methods for better performance
      switch (_selectedFilter) {
        case 'recent':
          reviews = await RatingService.getAllRecentRatings(limit: 50);
          break;
        case 'top_rated':
          reviews = await RatingService.getTopRatedReviewsOptimized(limit: 50);
          break;
        case 'popular':
          reviews = await RatingService.getPopularReviewsOptimized(limit: 50);
          break;
        case 'new_users':
          reviews = await RatingService.getAllRecentRatings(limit: 50);
          break;
      }
      
      debugPrint('Retrieved ${reviews.length} reviews from optimized query');
      
      setState(() => _loadingMessage = 'Filtering reviews...');
      
      // Filter out current user's ratings
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        reviews = reviews.where((rating) => rating.userId != currentUser.id).toList();
        debugPrint('After filtering current user: ${reviews.length} ratings');
      }
      
      // Apply additional filters (rating filter only for now)
      reviews = _applyAdditionalFilters(reviews);
      debugPrint('After applying additional filters: ${reviews.length} ratings');
      
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

    try {
      await RatingInteractionService.instance.toggleRatingLike(rating.id, currentUser.uid);
      
      // Refresh the reviews to get updated like counts
      _loadRecentReviews();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRatingLiked(rating) ? 'Rating unliked!' : 'Rating liked!'),
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

  void _openRatingComments(UserRating rating) {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => RatingCommentsScreen(rating: rating),
    //   ),
    // ).then((_) {
    //   // Refresh reviews when returning from comments screen
    //   _loadRecentReviews();
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments feature temporarily disabled')),
    );
  }
}