import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_rating.dart';
import '../models/rating_comment.dart';
import '../services/rating_service.dart';
import '../services/user_data_service.dart';
import '../services/rating_interaction_service.dart';
import '../services/firebase_auth_service.dart';
import 'user_profile_screen.dart';

class GameRatingsScreen extends StatefulWidget {
  final String gameId;
  final String gameName;

  const GameRatingsScreen({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<GameRatingsScreen> createState() => _GameRatingsScreenState();
}

class _GameRatingsScreenState extends State<GameRatingsScreen> {
  List<UserRating> _ratings = [];
  Map<String, Map<String, dynamic>> _userProfiles = {};
  bool _isLoading = true;
  String _sortBy = 'recent'; // recent, highest, lowest

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('🔍 Loading ratings for game: ${widget.gameId}');
      
      // Get ratings from both old and new systems (same approach as GameDetailScreen)
      final oldGameRatings = await RatingService.instance.getGameRatings(widget.gameId);
      final newGameRatings = await _getAllRatingsForGame(widget.gameId);
      
      debugPrint('📊 Found ${oldGameRatings.length} old ratings and ${newGameRatings.length} new ratings');
      
      // Combine and deduplicate ratings
      final Map<String, UserRating> allRatingsMap = {};
      
      // Add old ratings
      for (final rating in oldGameRatings) {
        allRatingsMap[rating.userId] = rating;
      }
      
      // Add new ratings (will override old ones if same user)
      for (final rating in newGameRatings) {
        allRatingsMap[rating.userId] = rating;
      }
      
      final combinedRatings = allRatingsMap.values.toList();
      debugPrint('📊 Combined total: ${combinedRatings.length} unique ratings');
      
      // Load user profiles for each rating and enrich the rating objects
      final Map<String, Map<String, dynamic>> profiles = {};
      final List<UserRating> enrichedRatings = [];
      
      for (final rating in combinedRatings) {
        Map<String, dynamic>? profile;
        if (!profiles.containsKey(rating.userId)) {
          profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
            debugPrint('👤 Loaded profile for user: ${rating.userId}');
          } else {
            debugPrint('❌ No profile found for user: ${rating.userId}');
          }
        } else {
          profile = profiles[rating.userId];
        }
        
        // Create enriched rating with proper user data
        final enrichedRating = rating.copyWith(
          displayName: profile?['displayName'] ?? profile?['username'] ?? rating.displayName,
          username: profile?['username'] ?? rating.username,
          profileImage: profile?['profileImage'] ?? rating.profileImage,
        );
        enrichedRatings.add(enrichedRating);
      }

      if (mounted) {
        setState(() {
          _ratings = enrichedRatings;
          _userProfiles = profiles;
          _isLoading = false;
        });
        _sortRatings();
        debugPrint('✅ Ratings loaded and sorted');
      }
    } catch (e) {
      debugPrint('❌ Error loading ratings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ratings: $e')),
        );
      }
    }
  }

  Future<List<UserRating>> _getAllRatingsForGame(String gameId) async {
    try {
      // Get all users who have rated this game from the new structure
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final List<UserRating> ratings = [];
      
      for (final userDoc in usersSnapshot.docs) {
        final ratingsSnapshot = await userDoc.reference
            .collection('ratings')
            .where('gameId', isEqualTo: gameId)
            .get();
        
        for (final ratingDoc in ratingsSnapshot.docs) {
          final data = ratingDoc.data();
          final rating = UserRating(
            id: data['id'] ?? '${userDoc.id}_$gameId',
            gameId: data['gameId'] ?? gameId,
            userId: data['userId'] ?? userDoc.id,
            username: data['username'] ?? 'user',
            rating: (data['rating'] ?? 0.0).toDouble(),
            review: data['review'],
            createdAt: data['createdAt'] != null 
                ? (data['createdAt'] is Timestamp 
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.fromMillisecondsSinceEpoch(data['createdAt']))
                : DateTime.now(),
            updatedAt: data['updatedAt'] != null 
                ? (data['updatedAt'] is Timestamp 
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : DateTime.fromMillisecondsSinceEpoch(data['updatedAt']))
                : DateTime.now(),
            likeCount: data['likeCount'] ?? 0,
            likedBy: List<String>.from(data['likedBy'] ?? []),
            commentCount: data['commentCount'] ?? 0,
          );
          ratings.add(rating);
        }
      }
      
      return ratings;
    } catch (e) {
      debugPrint('Error getting all ratings for game: $e');
      return [];
    }
  }

  void _sortRatings() {
    setState(() {
      switch (_sortBy) {
        case 'highest':
          _ratings.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'lowest':
          _ratings.sort((a, b) => a.rating.compareTo(b.rating));
          break;
        case 'recent':
        default:
          _ratings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.gameName,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: theme.colorScheme.onSurface),
            color: theme.colorScheme.surface,
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortRatings();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recent',
                child: Text('Most Recent', style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              PopupMenuItem(
                value: 'highest',
                child: Text('Highest Rating', style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              PopupMenuItem(
                value: 'lowest',
                child: Text('Lowest Rating', style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : _ratings.isEmpty
              ? _buildEmptyState()
              : _buildRatingsList(),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Reviews Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to share your thoughts about this game!',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.rate_review, size: 16),
              label: const Text('Write a Review', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _ratings.length,
      itemBuilder: (context, index) {
        final rating = _ratings[index];
        final userProfile = _userProfiles[rating.userId];
        return _buildRatingItem(rating, userProfile);
      },
    );
  }

  Widget _buildRatingItem(UserRating rating, Map<String, dynamic>? userProfile) {
    final theme = Theme.of(context);
    final displayName = userProfile?['displayName'] ?? userProfile?['username'] ?? 'User';
    final profileImage = userProfile?['profileImage'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info and rating
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(userId: rating.userId),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary,
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : null,
                    child: profileImage.isEmpty
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatDate(rating.updatedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      rating.rating.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Star rating display
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 1),
                child: Stack(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    // Full star overlay
                    if (rating.rating >= index + 1)
                      Icon(
                        Icons.star,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    // Half star overlay
                    if (rating.rating == index + 0.5)
                      ClipRect(
                        clipper: HalfStarClipper(),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          
          // Review text
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rating.review!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ),
          ],
          
          // Action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              // Like button
              _buildActionButton(
                icon: _isRatingLiked(rating) ? Icons.favorite : Icons.favorite_border,
                label: rating.likeCount.toString(),
                color: _isRatingLiked(rating) ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: () => _toggleRatingLike(rating),
              ),
              const SizedBox(width: 16),
              // Comment button
              _buildActionButton(
                icon: Icons.comment_outlined,
                label: rating.commentCount.toString(),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: () => _openRatingComments(rating),
              ),
              const Spacer(),
              // More options button
              _buildActionButton(
                icon: Icons.more_horiz,
                label: '',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: () => _showRatingOptions(rating),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRatingOptions(UserRating rating) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.onSurface),
              title: Text('Share Review', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                // Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: theme.colorScheme.error),
              title: Text('Report Review', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                // Implement report functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report feature coming soon!')),
                );
              },
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

  bool _isRatingLiked(UserRating rating) {
    final currentUser = FirebaseAuthService().currentUser;
    return currentUser != null && rating.likedBy.contains(currentUser.uid);
  }

  Future<void> _toggleRatingLike(UserRating rating) async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    // Optimistic update - update UI immediately
    final wasLiked = _isRatingLiked(rating);
    final ratingIndex = _ratings.indexWhere((r) => r.id == rating.id);
    
    if (ratingIndex != -1) {
      setState(() {
        if (wasLiked) {
          // Unlike: remove user from likedBy and decrease count
          final newLikedBy = List<String>.from(_ratings[ratingIndex].likedBy);
          newLikedBy.remove(currentUser.uid);
          _ratings[ratingIndex] = _ratings[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: (_ratings[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
          );
        } else {
          // Like: add user to likedBy and increase count
          final newLikedBy = List<String>.from(_ratings[ratingIndex].likedBy);
          newLikedBy.add(currentUser.uid);
          _ratings[ratingIndex] = _ratings[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: _ratings[ratingIndex].likeCount + 1,
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
            backgroundColor: Colors.green,
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
            final newLikedBy = List<String>.from(_ratings[ratingIndex].likedBy);
            newLikedBy.add(currentUser.uid);
            _ratings[ratingIndex] = _ratings[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: _ratings[ratingIndex].likeCount + 1,
            );
          } else {
            // Revert like: remove user and decrease count
            final newLikedBy = List<String>.from(_ratings[ratingIndex].likedBy);
            newLikedBy.remove(currentUser.uid);
            _ratings[ratingIndex] = _ratings[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: (_ratings[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
            );
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle like: $e'),
            backgroundColor: Colors.red,
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
      // Comments screen handles its own state, no need to refresh here
    });
  }

  Widget _FullFunctionalCommentsScreen({required UserRating rating}) {
    return _CommentsScreenStateful(rating: rating);
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: (widget.rating.profileImage?.isNotEmpty ?? false)
                      ? CachedNetworkImageProvider(widget.rating.profileImage!)
                      : null,
                  child: (widget.rating.profileImage?.isEmpty ?? true)
                      ? Text(
                          (widget.rating.displayName ?? widget.rating.username).isNotEmpty 
                              ? (widget.rating.displayName ?? widget.rating.username)[0].toUpperCase() 
                              : 'U',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rating.displayName ?? widget.rating.username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatDate(widget.rating.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.rating.rating.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Star rating display
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 1),
                child: Stack(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    // Full star overlay
                    if (widget.rating.rating >= index + 1)
                      Icon(
                        Icons.star,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    // Half star overlay
                    if (widget.rating.rating == index + 0.5)
                      ClipRect(
                        clipper: HalfStarClipper(),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          
          // Review text
          if (widget.rating.review != null && widget.rating.review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.rating.review!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ),
          ],
          
          // Action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              // Like button
              _buildActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: _likeCount.toString(),
                color: _isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: _toggleLike,
              ),
              const SizedBox(width: 16),
              // Comment button
              _buildActionButton(
                icon: Icons.comment_outlined,
                label: _comments.length.toString(),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: () {}, // No action needed, we're already in comments
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ],
        ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: (comment.authorProfileImage?.isNotEmpty ?? false)
                      ? CachedNetworkImageProvider(comment.authorProfileImage!)
                      : null,
                  child: (comment.authorProfileImage?.isEmpty ?? true)
                      ? Text(
                          (comment.authorDisplayName ?? comment.authorUsername).isNotEmpty 
                              ? (comment.authorDisplayName ?? comment.authorUsername)[0].toUpperCase() 
                              : 'U',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 1),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Like button for comment
              _buildActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: comment.likeCount.toString(),
                color: isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onTap: () => _toggleCommentLike(comment),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Comment text
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              comment.content,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
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
// Custom clipper for half stars
class HalfStarClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}