import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_rating.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
import '../services/rating_service.dart';
import '../services/firebase_auth_service.dart';
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
    _loadRecentReviews();
  }

  Future<void> _loadRecentReviews() async {
    setState(() => _isLoading = true);
    
    try {
      List<UserRating> reviews = [];
      
      switch (_selectedFilter) {
        case 'recent':
          reviews = await _getRecentRatingsFromAllUsers();
          break;
        case 'top_rated':
          reviews = await _getTopRatedGameReviews();
          break;
        case 'popular':
          reviews = await _getPopularGameReviews();
          break;
        case 'new_users':
          reviews = await _getNewUserReviews();
          break;
      }
      
      // Apply additional filters
      reviews = _applyFilters(reviews);
      
      if (mounted) {
        setState(() {
          _recentReviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserRating> _applyFilters(List<UserRating> reviews) {
    List<UserRating> filteredReviews = reviews;

    // Filter by rating
    if (_selectedRating != 'all') {
      final minRating = int.parse(_selectedRating);
      filteredReviews = filteredReviews.where((review) => review.rating >= minRating).toList();
    }

    // TODO: Add genre and platform filtering when game data includes these fields
    // This would require fetching game details and filtering based on genres/platforms

    return filteredReviews;
  }

  Future<List<UserRating>> _getRecentRatingsFromAllUsers() async {
    try {
      return await RatingService.getAllRecentRatings(limit: 20);
    } catch (e) {
      return [];
    }
  }

  Future<List<UserRating>> _getTopRatedGameReviews() async {
    try {
      final topGames = await RatingService.getTopRatedGames(limit: 10);
      List<UserRating> reviews = [];
      
      for (final gameData in topGames) {
        final gameRatings = await RatingService.instance.getGameRatings(gameData['gameId'], limit: 2);
        reviews.addAll(gameRatings);
      }
      
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        reviews = reviews.where((rating) => rating.userId != currentUser.id).toList();
      }
      
      reviews.sort((a, b) => b.rating.compareTo(a.rating));
      return reviews.take(20).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserRating>> _getPopularGameReviews() async {
    try {
      final topGames = await RatingService.getTopRatedGames(limit: 15);
      List<UserRating> reviews = [];
      
      for (final gameData in topGames) {
        final gameRatings = await RatingService.instance.getGameRatings(gameData['gameId'], limit: 3);
        reviews.addAll(gameRatings);
      }
      
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        reviews = reviews.where((rating) => rating.userId != currentUser.id).toList();
      }
      
      reviews.shuffle();
      return reviews.take(20).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserRating>> _getNewUserReviews() async {
    try {
      final allRatings = await RatingService.getAllRecentRatings(limit: 50);
      final currentUser = FirebaseAuthService().currentUser;
      
      if (currentUser != null) {
        return allRatings.where((rating) => rating.userId != currentUser.id).toList();
      }
      
      return allRatings;
    } catch (e) {
      return [];
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedGenre = 'all';
      _selectedPlatform = 'all';
      _selectedRating = 'all';
    });
    _loadRecentReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            _buildAdvancedFilters(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : _buildReviewsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
      child: Row(
        children: [
          const Text(
            'Discover',
            style: TextStyle(
              fontSize: 18, // Reduced from 20
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_list_off, color: Colors.white, size: 20), // Smaller icon
            tooltip: 'Clear Filters',
            padding: const EdgeInsets.all(8), // Reduced padding
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // Smaller button
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 40, // Reduced from 50
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced margin
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filterOptions.map((filter) => 
          _buildFilterChip(filter['label']!, filter['value']!)
        ).toList(),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced margin
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdownFilter('Genre', _selectedGenre, _genreOptions, (value) {
                setState(() => _selectedGenre = value!);
                _loadRecentReviews();
              })),
              const SizedBox(width: 6), // Reduced spacing
              Expanded(child: _buildDropdownFilter('Platform', _selectedPlatform, _platformOptions, (value) {
                setState(() => _selectedPlatform = value!);
                _loadRecentReviews();
              })),
            ],
          ),
          const SizedBox(height: 6), // Reduced spacing
          _buildDropdownFilter('Rating', _selectedRating, _ratingOptions, (value) {
            setState(() => _selectedRating = value!);
            _loadRecentReviews();
          }),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String selectedValue, List<Map<String, String>> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), // Reduced padding
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(6), // Smaller radius
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1F2937),
          style: const TextStyle(color: Colors.white, fontSize: 12), // Smaller text
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18), // Smaller icon
          isExpanded: true,
          items: options.map((option) => DropdownMenuItem<String>(
            value: option['value'],
            child: Text(option['label']!, style: const TextStyle(fontSize: 12)), // Smaller text
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey,
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
        backgroundColor: const Color(0xFF1F2937),
        selectedColor: const Color(0xFF6366F1),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_recentReviews.isEmpty) {
      return _buildEmptyState(
        'No Reviews Yet',
        'Be the first to discover and review games!',
      );
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
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
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
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      review.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatDate(review.updatedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Stack(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: const Color(0xFF374151),
                        ),
                        // Full star overlay - only show if rating is >= index + 1
                        if (review.rating >= index + 1)
                          Icon(
                            Icons.star,
                            size: 16,
                            color: const Color(0xFF10B981), // Green color like in reference
                          ),
                        // Half star overlay - only show if rating is exactly index + 0.5
                        if (review.rating == index + 0.5)
                          ClipRect(
                            clipper: HalfStarClipper(),
                            child: const Icon(
                              Icons.star,
                              size: 16,
                              color: Color(0xFF10B981), // Green color like in reference
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  review.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfo(String gameId) {
    return FutureBuilder<Game?>(
      future: RAWGService.instance.getGameDetails(gameId),
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
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.games, color: Colors.white, size: 20),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.games, color: Colors.white, size: 20),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.games, color: Colors.white, size: 20),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game?.title ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    game?.developer ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.explore_off,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _clearFilters();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Filters cleared! Showing all recent reviews.'),
                    backgroundColor: Color(0xFF6366F1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Reviews'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
}
// Custom clipper for half stars
class HalfStarClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}