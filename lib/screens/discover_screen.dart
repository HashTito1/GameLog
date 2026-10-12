import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import '../utils/date_format.dart';
import '../models/user_rating.dart';
import '../models/rating_comment.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/follow_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/rating_interaction_service.dart';
import '../services/theme_service.dart';
import 'game_detail_screen.dart';
import 'user_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<UserRating> _recentReviews = [];
  Set<String> _followingIds = {};
  int _priorityCount = 0; // leading reviews by people you follow

  /// Highlight colour for reviews by people you follow.
  static const Color _followAccent = Color(0xFFF5B83D);
  bool _isLoading = true;
  String _selectedFilter = 'recent';
  String _selectedRating = 'all';

  final List<Map<String, String>> _filterOptions = [
    {'label': 'Recent', 'value': 'recent'},
    {'label': 'Top Rated', 'value': 'top_rated'},
    {'label': 'Popular', 'value': 'popular'},
    {'label': 'Following', 'value': 'following'},
    {'label': 'Friends', 'value': 'friends'},
  ];

  final List<Map<String, String>> _ratingOptions = [
    {'label': 'Any rating', 'value': 'all'},
    {'label': '5★', 'value': '5'},
    {'label': '4★ & up', 'value': '4'},
    {'label': '3★ & up', 'value': '3'},
    {'label': '2★ & up', 'value': '2'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentReviews();
  }

  Future<void> _loadRecentReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final following = await FollowService.getFollowingIds();
      List<UserRating> reviews = [];

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
        case 'following':
          reviews = await RatingService.getRecentRatingsByUsers(following, limit: 50);
          break;
        case 'friends':
          final me = FirebaseAuthService().currentUser;
          reviews = me == null ? [] : await RatingService.getFriendRecentRatings(me.uid, limit: 50);
          break;
      }

      // People you follow come first in the community tabs. On Recent their
      // latest reviews are pulled in even if they're not in the newest 50.
      if (following.isNotEmpty && !{'following', 'friends'}.contains(_selectedFilter)) {
        var priority = <UserRating>[];
        if (_selectedFilter == 'recent') {
          priority = await RatingService.getRecentRatingsByUsers(following, limit: 10);
        }
        final seen = priority.map((r) => r.id).toSet();
        priority = [
          ...priority,
          ...reviews.where((r) => following.contains(r.userId) && !seen.contains(r.id)),
        ];
        final priorityIds = priority.map((r) => r.id).toSet();
        reviews = [...priority, ...reviews.where((r) => !priorityIds.contains(r.id))];
      }

      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        reviews = reviews.where((rating) => rating.userId != currentUser.id).toList();
      }
      reviews = _applyAdditionalFilters(reviews);
      final priorityCount = _selectedFilter == 'following'
          ? 0
          : reviews.takeWhile((r) => following.contains(r.userId)).length;

      // Enrich with current user data (profile pics and updated usernames)
      reviews = await _enrichWithCurrentUserData(reviews);
      
      if (mounted) {
        setState(() {
          _recentReviews = reviews;
          _followingIds = following;
          _priorityCount = priorityCount;
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

    // TODO: Genre and platform filtering would require fetching game details from IGDB
    // For now, we'll implement basic filtering based on available data
    // This could be enhanced by caching game details or fetching them in batches
    
    debugPrint('Final filtered count: ${filteredReviews.length}');
    return filteredReviews;
  }

  void _clearFilters() {
    setState(() {
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
        child: RefreshIndicator(
          onRefresh: _loadRecentReviews,
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(theme)),
              SliverToBoxAdapter(child: _buildFilterTabs(theme)),
              SliverToBoxAdapter(child: _buildRatingFilters(theme)),
              if (_isLoading)
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => _buildSkeletonCard(theme),
                )
              else if (_recentReviews.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildReviewsList(theme))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.list(
                    children: [
                      if (_priorityCount > 0)
                        _buildSectionLabel(theme, 'From people you follow', Icons.how_to_reg_rounded, _followAccent),
                      for (var i = 0; i < _recentReviews.length; i++) ...[
                        if (_priorityCount > 0 && i == _priorityCount)
                          _buildSectionLabel(theme, 'Community', Icons.public, theme.colorScheme.primary),
                        _buildReviewItem(_recentReviews[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'What the GameLog community is playing',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, IconData> _filterIcons = {
    'recent': Icons.schedule,
    'top_rated': Icons.star_rounded,
    'popular': Icons.local_fire_department,
    'following': Icons.how_to_reg_rounded,
    'friends': Icons.people_alt_outlined,
  };

  Widget _buildFilterTabs(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        children: _filterOptions
            .map((filter) => _buildFilterChip(filter['label']!, filter['value']!, theme))
            .toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ThemeData theme) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            if (isSelected) return;
            setState(() => _selectedFilter = value);
            _loadRecentReviews();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  _filterIcons[value] ?? Icons.circle,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingFilters(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          for (final option in _ratingOptions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(option['label']!),
                selected: _selectedRating == option['value'],
                onSelected: (_) {
                  if (_selectedRating == option['value']) return;
                  setState(() => _selectedRating = option['value']!);
                  _loadRecentReviews();
                },
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedRating == option['value']
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                backgroundColor: Colors.transparent,
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                side: BorderSide(
                  color: _selectedRating == option['value']
                      ? theme.colorScheme.primary.withValues(alpha: 0.6)
                      : theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: color.withValues(alpha: 0.25), height: 1)),
        ],
      ),
    );
  }

  Widget _buildReviewsList(ThemeData theme) {
    final hasActiveFilters = _selectedRating != 'all';
    if (hasActiveFilters) {
      return _buildEmptyState(
        'No reviews match',
        'Try a different rating filter to see more reviews.',
      );
    }

    final (title, subtitle) = switch (_selectedFilter) {
      'top_rated' => ('No top-rated reviews yet', 'Reviews of 4★ and up will appear here.'),
      'popular' => ('No popular reviews yet', 'Reviews other players like will appear here.'),
      'friends' => ('No friend reviews yet', 'Add friends to see what they think of the games they play.'),
      'following' => ('No reviews from people you follow', 'Follow players from their profiles to see their reviews here first.'),
      _ => ('No reviews yet', 'Be the first to rate and review a game!'),
    };
    return _buildEmptyState(title, subtitle);
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    final block = theme.colorScheme.onSurface.withValues(alpha: 0.06);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(72, 96),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(160, 16),
                const SizedBox(height: 8),
                bar(100, 12),
                const SizedBox(height: 16),
                bar(double.infinity, 12),
                const SizedBox(height: 6),
                bar(180, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Game details are looked up once per game, not on every rebuild.
  final Map<String, Future<Game?>> _gameLookups = {};

  Future<Game?> _gameFor(String gameId) => _gameLookups.putIfAbsent(gameId, () async {
        try {
          return await IGDBService.instance.getGameDetails(gameId);
        } catch (e) {
          return null;
        }
      });

  Widget _buildReviewItem(UserRating review) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final hasText = review.review != null && review.review!.trim().isNotEmpty;
    final name = review.displayName ?? review.username;
    final followed = _followingIds.contains(review.userId);
    final accent = followed ? _followAccent : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: followed
            ? Color.alphaBlend(_followAccent.withValues(alpha: 0.06), theme.colorScheme.surface)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: followed
              ? BorderSide(color: _followAccent.withValues(alpha: 0.7), width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: review.gameId)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (followed) ...[
                  Row(
                    children: [
                      const Icon(Icons.how_to_reg_rounded, size: 14, color: _followAccent),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'You follow $name',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _followAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                _buildGameInfo(review),
                if (hasText) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: accent, width: 3),
                      ),
                    ),
                    child: Text(
                      review.review!.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => UserProfileScreen(userId: review.userId)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildUserAvatar(review),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text('· ${_formatDate(review.updatedAt)}', style: TextStyle(fontSize: 12, color: muted)),
                    const Spacer(),
                    _buildActionPill(
                      theme,
                      icon: _isRatingLiked(review) ? Icons.favorite : Icons.favorite_border,
                      color: _isRatingLiked(review) ? Colors.redAccent : muted,
                      count: review.likeCount,
                      onTap: () => _toggleRatingLike(review),
                      tooltip: _isRatingLiked(review) ? 'Unlike' : 'Like',
                    ),
                    const SizedBox(width: 6),
                    _buildActionPill(
                      theme,
                      icon: Icons.chat_bubble_outline,
                      color: muted,
                      count: review.commentCount,
                      onTap: () => _openRatingComments(review),
                      tooltip: 'Comments',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionPill(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfo(UserRating review) {
    final theme = Theme.of(context);

    return FutureBuilder<Game?>(
      future: _gameFor(review.gameId),
      builder: (context, snapshot) {
        final game = snapshot.data;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 86,
                child: (game?.coverImage.isNotEmpty ?? false)
                    ? AppNetworkImage(imageUrl: game!.coverImage, fit: BoxFit.cover)
                    : Container(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.videogame_asset, color: theme.colorScheme.primary),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game?.title ?? review.gameTitle ?? 'Loading…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game?.subtitle ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ThemeService().starColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 15, color: ThemeService().starColor),
                            const SizedBox(width: 3),
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ThemeService().starColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        final starValue = index + 1;
                        final full = review.rating >= starValue;
                        final half = !full && review.rating >= starValue - 0.5;
                        return Icon(
                          full ? Icons.star_rounded : (half ? Icons.star_half_rounded : Icons.star_outline_rounded),
                          size: 15,
                          color: (full || half)
                              ? ThemeService().starColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        );
                      }),
                    ],
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
      return formatShortDate(date);
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
          child: AppNetworkImage(
            imageUrl: review.profileImage!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 32,
              height: 32,
              color: theme.colorScheme.primary,
              alignment: Alignment.center,
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
              alignment: Alignment.center,
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
        builder: (context) => _buildCommentsScreen(rating: rating),
      ),
    ).then((_) {
      // Refresh only the specific rating's comment count when returning
      _refreshSingleRatingInDiscover(rating);
    });
  }

  Widget _buildCommentsScreen({required UserRating rating}) {
    return _CommentsScreenStateful(rating: rating);
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
      return formatShortDate(date);
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
