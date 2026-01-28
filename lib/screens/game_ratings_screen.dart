import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_rating.dart';
import '../services/rating_service.dart';
import '../services/user_data_service.dart';
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
      
      // Load user profiles for each rating
      final Map<String, Map<String, dynamic>> profiles = {};
      for (final rating in combinedRatings) {
        if (!profiles.containsKey(rating.userId)) {
          final profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
            debugPrint('👤 Loaded profile for user: ${rating.userId}');
          } else {
            debugPrint('❌ No profile found for user: ${rating.userId}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _ratings = combinedRatings;
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
            id: data['id'] ?? '',
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
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ratings & Reviews',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.gameName,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            color: const Color(0xFF1F2937),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortRatings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'recent',
                child: Text('Most Recent', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'highest',
                child: Text('Highest Rating', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'lowest',
                child: Text('Lowest Rating', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ratings.isEmpty
              ? _buildEmptyState()
              : _buildRatingsList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Ratings Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to rate this game!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ratings.length,
      itemBuilder: (context, index) {
        final rating = _ratings[index];
        final userProfile = _userProfiles[rating.userId];
        return _buildRatingItem(rating, userProfile);
      },
    );
  }

  Widget _buildRatingItem(UserRating rating, Map<String, dynamic>? userProfile) {
    final displayName = userProfile?['displayName'] ?? userProfile?['username'] ?? 'User';
    final profileImage = userProfile?['profileImage'] ?? '';

    return Container(
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
                      builder: (context) => UserProfileScreen(userId: rating.userId),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1),
                  backgroundImage: profileImage.isNotEmpty
                      ? CachedNetworkImageProvider(profileImage)
                      : null,
                  child: profileImage.isEmpty
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatDate(rating.updatedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Stack(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFF374151),
                          ),
                          // Full star overlay - only show if rating is >= index + 1
                          if (rating.rating >= index + 1)
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Color(0xFF10B981), // Green color like in reference
                            ),
                          // Half star overlay - only show if rating is exactly index + 0.5
                          if (rating.rating == index + 0.5)
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
                  const SizedBox(height: 4),
                ],
              ),
            ],
          ),
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.review!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
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