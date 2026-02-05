import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../models/rating_comment.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/recommendation_service.dart';
import '../services/user_data_service.dart';
import '../services/follow_service.dart';
import '../services/friends_service.dart';
import '../services/event_bus.dart';
import '../services/rating_interaction_service.dart';
import 'game_ratings_screen.dart';
// Forum functionality disabled - keeping import commented
// import 'create_forum_post_screen.dart';

class GameDetailScreen extends StatefulWidget {
  final String gameId;
  final Game? initialGame;

  const GameDetailScreen({
    super.key,
    required this.gameId,
    this.initialGame,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  Game? _game;
  bool _isLoading = true;
  bool _isLoadingSimilarGames = false;
  List<Game> _similarGames = [];
  
  // Rating data
  UserRating? _userRating;
  List<UserRating> _gameRatings = [];
  List<UserRating> _friendRatings = [];
  Map<String, Map<String, dynamic>> _ratingUserProfiles = {};
  double _averageRating = 0.0;
  int _totalRatings = 0;
  int _backlogCount = 0;
  int _playingCount = 0;
  int _completedCount = 0;
  bool _isLoadingUserRating = true;
  bool _isLoadingStats = true;
  
  // Library status
  String? _currentLibraryStatus;
  
  // Favorite status
  bool _isFavorite = false;
  bool _isUpdatingFavorite = false;
  
  // Rating form
  double _selectedRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingRating = false;
  bool _isDescriptionExpanded = false;
  
  // Event subscriptions
  StreamSubscription<LibraryUpdatedEvent>? _libraryUpdateSubscription;
  Timer? _ratingUpdateTimer;

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loadGameData();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _libraryUpdateSubscription?.cancel();
    _ratingUpdateTimer?.cancel();
    super.dispose();
  }

  void _setupEventListeners() {
    _libraryUpdateSubscription = EventBus().on<LibraryUpdatedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && event.userId == currentUser.uid) {
        // Reload library status when library is updated
        _loadLibraryStatus();
      }
    });
    
    // Set up periodic updates for rating data (every 30 seconds)
    _ratingUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshAllRatingData();
      }
    });
  }

  Future<void> _loadLibraryStatus() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        final libraryEntry = await LibraryService.instance.getGameFromLibrary(currentUser.uid, widget.gameId);
        final currentStatus = libraryEntry?['status'] as String?;
        
        if (mounted) {
          setState(() {
            _currentLibraryStatus = currentStatus;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading library status: $e');
    }
  }

  Future<void> _loadGameData() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Loading game data for gameId: ${widget.gameId}');
      
      // Load game details if not provided
      if (_game == null) {
        debugPrint('Game is null, fetching from RAWG API...');
        _game = await IGDBService.instance.getGameDetails(widget.gameId);
        debugPrint('Fetched game: ${_game?.title ?? 'null'}');
      }

      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        // Load user's rating FIRST for immediate display
        await _loadUserRating();
        
        // Check if this game is the user's favorite
        await _loadFavoriteStatus();
        
        // Load current library status
        final libraryEntry = await LibraryService.instance.getGameFromLibrary(currentUser.uid, widget.gameId);
        final currentStatus = libraryEntry?['status'] as String?;
        
        if (mounted) {
          setState(() {
            _currentLibraryStatus = currentStatus;
          });
        }
        
        // Load community ratings in background (don't block UI)
        _loadCommunityRatings();
      }

      // Load similar games
      _loadSimilarGames();
    } catch (e) {
      debugPrint('Error loading game data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserRating() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    try {
      // Direct query for this specific game rating - much more efficient
      final ratingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('ratings')
          .doc(widget.gameId)
          .get();
      
      Map<String, dynamic>? userRating;
      if (ratingDoc.exists) {
        userRating = ratingDoc.data();
        userRating?['id'] = ratingDoc.id;
      }
      
      // Fallback: check legacy user_ratings collection
      if (userRating == null) {
        final legacyRatingDoc = await FirebaseFirestore.instance
            .collection('user_ratings')
            .doc('${currentUser.uid}_${widget.gameId}')
            .get();
        
        if (legacyRatingDoc.exists) {
          userRating = legacyRatingDoc.data();
          userRating?['id'] = legacyRatingDoc.id;
        }
      }
      
      debugPrint('🔍 User rating for game ${widget.gameId}: $userRating');
      
      if (mounted) {
        setState(() {
          // Convert user rating data to UserRating object if it exists
          if (userRating != null && userRating.isNotEmpty) {
            _userRating = UserRating(
              id: userRating['id'] ?? '${currentUser.uid}_${widget.gameId}',
              gameId: userRating['gameId'] ?? widget.gameId,
              userId: userRating['userId'] ?? currentUser.uid,
              username: userRating['username'] ?? currentUser.email?.split('@')[0] ?? 'user',
              rating: (userRating['rating'] ?? 0.0).toDouble(),
              review: userRating['review'],
              createdAt: userRating['createdAt'] != null 
                  ? (userRating['createdAt'] is Timestamp 
                      ? (userRating['createdAt'] as Timestamp).toDate()
                      : DateTime.fromMillisecondsSinceEpoch(userRating['createdAt']))
                  : DateTime.now(),
              updatedAt: userRating['updatedAt'] != null 
                  ? (userRating['updatedAt'] is Timestamp 
                      ? (userRating['updatedAt'] as Timestamp).toDate()
                      : DateTime.fromMillisecondsSinceEpoch(userRating['updatedAt']))
                  : DateTime.now(),
            );
            
            _selectedRating = _userRating!.rating;
            _reviewController.text = _userRating!.review ?? '';
          } else {
            _userRating = null;
          }
          _isLoadingUserRating = false;
          // Recalculate total ratings to include current user's rating
          _updateTotalRatingsCount();
        });
      }
    } catch (e) {
      debugPrint('Error loading user rating: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserRating = false;
          // Recalculate total ratings count
          _updateTotalRatingsCount();
        });
      }
    }
  }

  void _updateTotalRatingsCount() {
    // Calculate total ratings including current user's rating
    final communityRatingsCount = _gameRatings.length;
    final userRatingCount = _userRating != null ? 1 : 0;
    
    // Total is community + user rating
    _totalRatings = communityRatingsCount + userRatingCount;
    
    // Also update average rating to include current user's rating
    _updateAverageRating();
  }

  void _updateAverageRating() {
    if (_gameRatings.isEmpty && _userRating == null) {
      _averageRating = 0.0;
      return;
    }
    
    double totalRatingSum = 0.0;
    int totalCount = 0;
    
    // Add community ratings
    for (final rating in _gameRatings) {
      totalRatingSum += rating.rating;
      totalCount++;
    }
    
    // Add current user's rating
    if (_userRating != null) {
      totalRatingSum += _userRating!.rating;
      totalCount++;
    }
    
    _averageRating = totalCount > 0 ? totalRatingSum / totalCount : 0.0;
  }

  Future<void> _loadCommunityRatings() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    try {
      // Get ALL ratings for this game from both old and new structures
      final oldGameRatings = await RatingService.instance.getGameRatings(widget.gameId);
      final newGameRatings = await _getAllRatingsForGame(widget.gameId);
      
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
      
      final gameRatings = allRatingsMap.values.toList();
      gameRatings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Load interaction data for each rating (likes and comments)
      final enrichedRatings = <UserRating>[];
      for (final rating in gameRatings) {
        try {
          final interactionData = await RatingInteractionService.instance
              .getRatingWithInteractions(rating.id, currentUser.uid);
          final enrichedRating = interactionData['rating'] as UserRating? ?? rating;
          enrichedRatings.add(enrichedRating);
        } catch (e) {
          debugPrint('Error loading interactions for rating ${rating.id}: $e');
          // Fallback to original rating if interaction loading fails
          enrichedRatings.add(rating);
        }
      }
      
      // Load friend ratings for this game
      final friendRatings = await _getFriendRatingsForGame(widget.gameId);
      
      // Enrich friend ratings with interaction data
      final enrichedFriendRatings = <UserRating>[];
      for (final rating in friendRatings) {
        try {
          final interactionData = await RatingInteractionService.instance
              .getRatingWithInteractions(rating.id, currentUser.uid);
          final enrichedRating = interactionData['rating'] as UserRating? ?? rating;
          enrichedFriendRatings.add(enrichedRating);
        } catch (e) {
          debugPrint('Error loading interactions for friend rating ${rating.id}: $e');
          // Fallback to original rating if interaction loading fails
          enrichedFriendRatings.add(rating);
        }
      }
      
      // Load user profiles for ALL ratings and enrich the rating objects
      final Map<String, Map<String, dynamic>> profiles = {};
      final List<UserRating> finalEnrichedRatings = [];
      final List<UserRating> finalEnrichedFriendRatings = [];
      
      // Process community ratings (exclude current user's own review)
      for (final rating in enrichedRatings) {
        // Skip current user's own review in community section
        if (rating.userId == currentUser.uid) continue;
        
        Map<String, dynamic>? profile;
        if (!profiles.containsKey(rating.userId)) {
          profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
          }
        } else {
          profile = profiles[rating.userId];
        }
        
        // Create final enriched rating with both interaction data and user profile data
        final finalRating = rating.copyWith(
          displayName: profile?['displayName'] ?? profile?['username'] ?? rating.displayName,
          username: profile?['username'] ?? rating.username,
          profileImage: profile?['profileImage'] ?? rating.profileImage,
        );
        finalEnrichedRatings.add(finalRating);
      }
      
      // Process friend ratings
      for (final rating in enrichedFriendRatings) {
        Map<String, dynamic>? profile;
        if (!profiles.containsKey(rating.userId)) {
          profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
          }
        } else {
          profile = profiles[rating.userId];
        }
        
        // Create final enriched friend rating with both interaction data and user profile data
        final finalRating = rating.copyWith(
          displayName: profile?['displayName'] ?? profile?['username'] ?? rating.displayName,
          username: profile?['username'] ?? rating.username,
          profileImage: profile?['profileImage'] ?? rating.profileImage,
        );
        finalEnrichedFriendRatings.add(finalRating);
      }
      
      if (mounted) {
        setState(() {
          _gameRatings = finalEnrichedRatings;
          _friendRatings = finalEnrichedFriendRatings;
          _ratingUserProfiles = profiles;
          // Update total ratings count and average rating properly
          _updateTotalRatingsCount();
        });
        
        // Load library stats for this game in background (non-blocking)
        _loadLibraryStats();
      }
    } catch (e) {
      debugPrint('Error loading community ratings: $e');
    }
  }

  Future<void> _loadLibraryStats() async {
    try {
      // Use more efficient query approach - query the legacy user_library collection
      // which has better indexing for this type of query
      final librarySnapshot = await FirebaseFirestore.instance
          .collection('user_library')
          .where('gameId', isEqualTo: widget.gameId)
          .get();
      
      int backlogCount = 0;
      int playingCount = 0;
      int completedCount = 0;
      
      for (final doc in librarySnapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'backlog':
          case 'want_to_play':
          case 'planToPlay':
            backlogCount++;
            break;
          case 'playing':
            playingCount++;
            break;
          case 'completed':
            completedCount++;
            break;
        }
      }
      
      // If no data from legacy collection, use ratings as baseline
      if (librarySnapshot.docs.isEmpty && _totalRatings > 0) {
        backlogCount = (_totalRatings * 0.3).round();
        playingCount = (_totalRatings * 0.2).round();
        completedCount = _totalRatings;
      }
      
      if (mounted) {
        setState(() {
          _backlogCount = backlogCount;
          _playingCount = playingCount;
          _completedCount = completedCount;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading library stats: $e');
      // Fallback to ratings-based estimates
      if (mounted && _totalRatings > 0) {
        setState(() {
          _backlogCount = (_totalRatings * 0.3).round();
          _playingCount = (_totalRatings * 0.2).round();
          _completedCount = _totalRatings;
          _isLoadingStats = false;
        });
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

  Future<List<UserRating>> _getFriendRatingsForGame(String gameId) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return [];

      // Get user's friends
      final friends = await FriendsService.instance.getFriends(currentUser.uid);
      final friendIds = friends.map((friend) => friend['id'] as String).toList();
      
      if (friendIds.isEmpty) return [];

      final List<UserRating> friendRatings = [];
      
      // Get ratings from friends for this game
      for (final friendId in friendIds) {
        try {
          final friendRatingSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .collection('ratings')
              .where('gameId', isEqualTo: gameId)
              .get();
          
          for (final ratingDoc in friendRatingSnapshot.docs) {
            final data = ratingDoc.data();
            final rating = UserRating(
              id: data['id'] ?? '${friendId}_$gameId',
              gameId: data['gameId'] ?? gameId,
              userId: data['userId'] ?? friendId,
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
            friendRatings.add(rating);
          }
        } catch (e) {
          debugPrint('Error getting rating for friend $friendId: $e');
        }
      }
      
      // Sort by most recent
      friendRatings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return friendRatings;
    } catch (e) {
      debugPrint('Error getting friend ratings for game: $e');
      return [];
    }
  }

  Future<void> _loadSimilarGames() async {
    if (!mounted) return;
    
    setState(() => _isLoadingSimilarGames = true);

    try {
      final similarGames = await RecommendationService.instance.getSimilarGames(
        widget.gameId,
      );
      
      if (mounted) {
        setState(() {
          _similarGames = similarGames;
          _isLoadingSimilarGames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSimilarGames = false);
      }
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    // Show status selection dialog first
    final selectedStatus = await _showStatusSelectionDialog();
    if (selectedStatus == null) return; // User cancelled

    setState(() => _isSubmittingRating = true);

    try {
      final currentUser = FirebaseAuthService().currentUser;
      debugPrint('🔍 Current user: ${currentUser?.id} (${currentUser?.email})');
      debugPrint('🎮 Game ID: ${widget.gameId}');
      debugPrint('⭐ Rating: $_selectedRating');
      debugPrint('📊 Status: $selectedStatus');
      
      if (currentUser != null && _game != null) {
        debugPrint('📝 Submitting rating to UserDataService...');
        
        // Use the comprehensive UserDataService method for rating submission
        await UserDataService.submitUserRating(
          userId: currentUser.uid,
          gameId: widget.gameId,
          gameTitle: _game!.title,
          rating: _selectedRating,
          review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        );
        
        debugPrint('✅ UserDataService rating submitted successfully');

        // Also submit to the old rating service for backward compatibility
        debugPrint('📝 Submitting rating to RatingService...');
        await RatingService.instance.submitRating(
          gameId: widget.gameId,
          userId: currentUser.uid,
          username: currentUser.email != null ? currentUser.email!.split('@')[0] : 'user',
          rating: _selectedRating,
          review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
          gameTitle: _game!.title,
        );
        
        debugPrint('✅ RatingService rating submitted successfully');

        // Add to library with selected status
        debugPrint('📚 Adding to library with status: $selectedStatus');
        await _addToLibrary(selectedStatus);

        // Clear rating cache to ensure fresh data
        RatingService.clearAllCache();

        // Instead of reloading all game data, just update the specific rating data
        await _updateRatingDataOnly();

        // Update the game object with new community rating
        if (_game != null && _totalRatings > 0) {
          _game = Game(
            id: _game!.id,
            title: _game!.title,
            developer: _game!.developer,
            publisher: _game!.publisher,
            releaseDate: _game!.releaseDate,
            platforms: _game!.platforms,
            genres: _game!.genres,
            coverImage: _game!.coverImage,
            description: _game!.description,
            averageRating: _averageRating, // Use the updated community rating
            totalReviews: _totalRatings, // Use the updated total count
          );
        }

        // Trigger library refresh event for stats tracking
        EventBus().fire(RatingSubmittedEvent(
          userId: currentUser.uid,
          gameId: widget.gameId,
          rating: _selectedRating,
        ));

        // Notify followers about the rating
        await FollowService.notifyFollowersOfRating(
          userId: currentUser.uid,
          gameId: widget.gameId,
          gameTitle: _game!.title,
          rating: _selectedRating,
          review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_userRating != null ? 'Rating updated successfully!' : 'Rating submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('❌ Current user is null or game is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to rate games'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
      }
    }
  }

  Future<String?> _showStatusSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'How would you categorize this game?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Since you\'re rating this game, where should it go in your library?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildStatusOption(
              'Completed',
              'You finished this game',
              Icons.check_circle,
              const Color(0xFF10B981),
              'completed',
            ),
            const SizedBox(height: 8),
            _buildStatusOption(
              'Dropped',
              'You stopped playing this game',
              Icons.cancel,
              const Color(0xFFEF4444),
              'dropped',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String title, String description, IconData icon, Color color, String status) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(status),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF374151),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRating() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        // Delete from both the new structure (user's ratings subcollection) and old structure
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('ratings')
            .doc(widget.gameId)
            .delete();
        
        // Also delete from the old rating service structure for backward compatibility
        await RatingService.deleteRating(widget.gameId, currentUser.uid);
        
        // Reset the UI state
        setState(() {
          _userRating = null;
          _selectedRating = 0.0;
          _reviewController.clear();
        });

        // Reload rating data
        await _loadGameData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating deleted successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        final userProfile = await UserDataService.getUserProfile(currentUser.uid);
        final favoriteGame = userProfile?['favoriteGame'] as Map<String, dynamic>?;
        
        if (mounted) {
          setState(() {
            _isFavorite = favoriteGame?['gameId'] == widget.gameId;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading favorite status: $e');
    }
  }

  Future<void> _updateRatingDataOnly() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        // Load user's rating first for immediate update
        await _loadUserRating();
        
        // Load community ratings in background
        await _loadCommunityRatings();
      }
    } catch (e) {
      debugPrint('Error updating rating data: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isUpdatingFavorite) return;
    
    setState(() => _isUpdatingFavorite = true);

    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && _game != null) {
        if (_isFavorite) {
          // Remove from favorites by setting favoriteGame to null
          await UserDataService.saveUserProfile(currentUser.uid, {
            'favoriteGame': null,
          });
          
          setState(() => _isFavorite = false);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_game!.title} removed from favorites'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // Add to favorites
          await UserDataService.saveUserProfile(currentUser.uid, {
            'favoriteGame': {
              'gameId': _game!.id,
              'gameName': _game!.title,
              'gameImage': _game!.coverImage,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
          });
          
          setState(() => _isFavorite = true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_game!.title} added to favorites!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }

  Future<void> _addToLibrary(String status) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && _game != null) {
        await LibraryService.instance.addGameToLibrary(
          userId: currentUser.uid,
          game: _game ?? Game(
            id: widget.gameId,
            title: 'Unknown Game',
            developer: '',
            publisher: '',
            releaseDate: '',
            platforms: [],
            genres: [],
            coverImage: '',
            description: '',
            averageRating: 0.0,
            totalReviews: 0,
          ),
          rating: 0.0, // Default rating for library addition
          status: status,
        );
        
        // Update the current status immediately
        setState(() {
          _currentLibraryStatus = status;
        });
        
        // Refresh game data to update stats
        await _loadGameData();
        
        if (mounted) {
          // Create proper notification message
          String statusMessage;
          switch (status) {
            case 'backlog':
              statusMessage = 'Added to backlog';
              break;
            case 'playing':
              statusMessage = 'Added to playing';
              break;
            case 'completed':
              statusMessage = 'Added to completed';
              break;
            case 'dropped':
              statusMessage = 'Added to dropped';
              break;
            default:
              statusMessage = 'Added to library as ${status.replaceAll('_', ' ')}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusMessage),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsCompleted() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null || _game == null) return;

      // First, move the game to completed status
      await LibraryService.instance.addGameToLibrary(
        userId: currentUser.uid,
        game: _game!,
        rating: 0.0,
        status: 'completed',
      );
      
      // Update the current status immediately
      setState(() {
        _currentLibraryStatus = 'completed';
      });

      // Refresh game data to update stats
      await _loadGameData();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game marked as completed!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Show rating dialog after a brief delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showCompletionRatingDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as completed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCompletionRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Game Completed!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations on completing ${_game?.title ?? 'this game'}!',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to rate and review this game?',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // Scroll to the rating section
              _scrollToRatingSection();
            },
            icon: const Icon(Icons.star, size: 16),
            label: const Text('Rate Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToRatingSection() {
    // Find the rating section and scroll to it
    // This assumes there's a scroll controller for the main content
    if (mounted) {
      // Show a message to guide the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scroll down to rate and review this game!'),
          backgroundColor: Color(0xFF6366F1),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLibraryPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add to Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildLibraryOption(
              'Backlog',
              'Games you want to play in the future',
              Icons.bookmark_border,
              'backlog',
              const Color(0xFF6366F1),
            ),
            _buildLibraryOption(
              'Playing',
              'Games you are currently playing',
              Icons.play_circle_outline,
              'playing',
              const Color(0xFF10B981),
            ),
            _buildLibraryOption(
              'Completed',
              'Games you have finished',
              Icons.check_circle_outline,
              'completed',
              const Color(0xFFFBBF24),
            ),
            _buildLibraryOption(
              'Dropped',
              'Games you stopped playing',
              Icons.cancel_outlined,
              'dropped',
              const Color(0xFFEF4444),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryOption(String title, String description, IconData icon, String status, Color color) {
    final isCurrentStatus = _currentLibraryStatus == status;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            _addToLibrary(status);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentStatus ? color.withValues(alpha: 0.1) : const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
              border: isCurrentStatus ? Border.all(color: color, width: 2) : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (isCurrentStatus) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              color: color,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'playing' && isCurrentStatus)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _markAsCompleted();
                    },
                    child: const Text(
                      'Mark Complete',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      );
    }

    if (_game == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Game not found',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12), // Reduced from 16
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGameHeader(),
                  const SizedBox(height: 20),
                  _buildGameInfo(),
                  const SizedBox(height: 20),
                  _buildRatingSection(),
                  const SizedBox(height: 20),
                  _buildCommunityRatingsSection(),
                  const SizedBox(height: 20),
                  _buildSimilarGamesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250, // Reduced from 300
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1F2937),
      flexibleSpace: FlexibleSpaceBar(
        background: (_game?.coverImage?.isNotEmpty ?? false)
            ? CachedNetworkImage(
                imageUrl: _game!.coverImage,
                fit: BoxFit.contain, // Changed from cover to contain to show full image
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.white),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.games, color: Colors.white, size: 64),
              ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Forum button removed - keeping forum functionality disabled
        // IconButton(
        //   onPressed: () {
        //     Navigator.of(context).push(
        //       MaterialPageRoute(
        //         builder: (context) => CreateForumPostScreen(
        //           gameId: widget.gameId,
        //           gameTitle: _game?.title,
        //         ),
        //       ),
        //     );
        //   },
        //   icon: const Icon(Icons.forum, color: Colors.white),
        //   tooltip: 'Create Forum Post',
        // ),
        // Favorite star button
        IconButton(
          onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
          icon: _isUpdatingFavorite
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? const Color(0xFFFBBF24) : Colors.white,
                  size: 28,
                ),
        ),
      ],
    );
  }

  Widget _buildGameHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _game?.title ?? 'Loading...',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if ((_game?.releaseDate?.isNotEmpty ?? false)) ...[
          Row(
            children: [
              Text(
                _game!.releaseDate,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // Platform chips
        if (_game?.platforms?.isNotEmpty ?? false) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _game!.platforms.take(8).map((platform) => _buildPlatformChip(platform)).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Add to library button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showLibraryPopup,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Add to',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24), // Yellow color like in image
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformChip(String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        platform,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showAllRatings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameRatingsScreen(
          gameId: widget.gameId,
          gameName: _game?.title ?? 'Game',
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    final description = (_game?.description?.isNotEmpty ?? false) ? _game!.description : 'No description available.';
    final isLongDescription = description.length > 200;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row (like in the image)
        Row(
          children: [
            _buildStatItem(
              icon: Icons.star,
              value: _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '0.0',
              label: 'GameLoggers',
              color: const Color(0xFFFBBF24),
            ),
            _buildStatItem(
              icon: Icons.bookmark_border,
              value: _isLoadingStats ? '...' : '$_backlogCount',
              label: 'Backlog',
              color: const Color(0xFF6366F1),
            ),
            _buildStatItem(
              icon: Icons.play_circle_outline,
              value: _isLoadingStats ? '...' : '$_playingCount',
              label: 'Playing',
              color: const Color(0xFF10B981),
            ),
            _buildStatItem(
              icon: Icons.rate_review,
              value: '$_totalRatings',
              label: 'Reviews',
              color: const Color(0xFFEF4444),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Description section
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isDescriptionExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          firstChild: Text(
            isLongDescription 
                ? '${description.substring(0, 200)}...' 
                : description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          secondChild: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ),
        if (isLongDescription) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Text(
              _isDescriptionExpanded ? 'Show less' : 'Show more',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10), // Reduced from 12
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userRating != null ? 'Your Rating' : 'Rate This Game',
            style: const TextStyle(
              fontSize: 16, // Reduced from 18
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16
          
          // Show loading indicator while user rating is loading
          if (_isLoadingUserRating) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ] else ...[
            // Show different UI based on whether user has rated or not
            if (_userRating != null) ...[
              // User has already rated - show compact rating display with edit option
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Display current rating as stars
                        Row(
                          children: List.generate(5, (index) {
                            return Container(
                              width: 24,
                              height: 24,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 20,
                                    color: const Color(0xFF374151),
                                  ),
                                  if (_userRating!.rating >= index + 1)
                                    Icon(
                                      Icons.star,
                                      size: 20,
                                      color: const Color(0xFF10B981),
                                    ),
                                  if (_userRating!.rating == index + 0.5)
                                    ClipRect(
                                      clipper: HalfStarClipper(),
                                      child: const Icon(
                                        Icons.star,
                                        size: 20,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _userRating!.rating.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedRating = _userRating!.rating;
                              _reviewController.text = _userRating!.review ?? '';
                            });
                            _showEditRatingDialog();
                          },
                          child: const Text(
                            'Edit',
                            style: TextStyle(color: Color(0xFF6366F1)),
                          ),
                        ),
                      ],
                    ),
                    if (_userRating!.review != null && _userRating!.review!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _userRating!.review!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Rated on ${_formatDate(_userRating!.updatedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _deleteRating,
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // User hasn't rated yet - show interactive rating form
              GestureDetector(
                onTapDown: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(details.globalPosition);
                  
                  // Calculate which star and which half was tapped
                  final starsRowWidth = 5 * 36.0; // Reduced star size
                  final containerWidth = MediaQuery.of(context).size.width - 32;
                  final startX = (containerWidth - starsRowWidth) / 2;
                  
                  // Find which star was tapped
                  final relativeX = localPosition.dx - startX;
                  final starIndex = (relativeX / 36.0).floor();
                  final starLocalX = relativeX % 36.0;
                  
                  if (starIndex >= 0 && starIndex < 5) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      // If tap is on left half of star, set to .5, if on right half, set to full
                      if (starLocalX < 18.0) {
                        _selectedRating = starIndex + 0.5;
                      } else {
                        _selectedRating = (starIndex + 1).toDouble();
                      }
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Container(
                      width: 36, // Reduced from 40
                      height: 36, // Reduced from 40
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background star (empty) - using filled star with gray color
                          Icon(
                            Icons.star,
                            size: 28, // Reduced from 32
                            color: const Color(0xFF374151),
                          ),
                          // Full star overlay - only show if rating is >= index + 1 (full star)
                          if (_selectedRating >= index + 1)
                            Icon(
                              Icons.star,
                              size: 28, // Reduced from 32
                              color: const Color(0xFF10B981), // Green color like in reference
                            ),
                          // Half star overlay - only show if rating is exactly index + 0.5
                          if (_selectedRating == index + 0.5)
                            ClipRect(
                              clipper: HalfStarClipper(),
                              child: const Icon(
                                Icons.star,
                                size: 28, // Reduced from 32
                                color: Color(0xFF10B981), // Green color like in reference
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16
              TextField(
                controller: _reviewController,
                maxLines: 2, // Reduced from 3
                style: const TextStyle(color: Colors.white, fontSize: 13), // Smaller text
                decoration: const InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6366F1)),
                  ),
                  contentPadding: EdgeInsets.all(10), // Reduced padding
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmittingRating ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10), // Reduced padding
                  ),
                  child: _isSubmittingRating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Rating',
                          style: TextStyle(fontSize: 13), // Smaller text
                        ),
                ),
              ),
            ],
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
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showEditRatingDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Edit Rating',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star rating
              GestureDetector(
                onTapDown: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(details.globalPosition);
                  
                  final starsRowWidth = 5 * 32.0;
                  final containerWidth = 280.0; // Dialog width
                  final startX = (containerWidth - starsRowWidth) / 2;
                  
                  final relativeX = localPosition.dx - startX;
                  final starIndex = (relativeX / 32.0).floor();
                  final starLocalX = relativeX % 32.0;
                  
                  if (starIndex >= 0 && starIndex < 5) {
                    HapticFeedback.selectionClick();
                    setDialogState(() {
                      if (starLocalX < 16.0) {
                        _selectedRating = starIndex + 0.5;
                      } else {
                        _selectedRating = (starIndex + 1).toDouble();
                      }
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Container(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            size: 24,
                            color: const Color(0xFF374151),
                          ),
                          if (_selectedRating >= index + 1)
                            Icon(
                              Icons.star,
                              size: 24,
                              color: const Color(0xFF10B981),
                            ),
                          if (_selectedRating == index + 0.5)
                            ClipRect(
                              clipper: HalfStarClipper(),
                              child: const Icon(
                                Icons.star,
                                size: 24,
                                color: Color(0xFF10B981),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Show status selection dialog for updates too
              final selectedStatus = await _showStatusSelectionDialog();
              if (selectedStatus != null) {
                await _submitRating(); // This will now include the status selection
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityRatingsSection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10), // Reduced from 12
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people,
                color: Color(0xFF6366F1),
                size: 18, // Reduced from 20
              ),
              const SizedBox(width: 6), // Reduced from 8
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 16, // Reduced from 18
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_totalRatings > 0)
                GestureDetector(
                  onTap: _showAllRatings,
                  child: Text(
                    'View All ($_totalRatings)',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12, // Reduced from 14
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12), // Reduced from 16
          if (_totalRatings > 0) ...[
            Row(
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 24, // Reduced from 28
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6), // Reduced from 8
                const Icon(
                  Icons.star,
                  color: Color(0xFFFBBF24),
                  size: 20, // Reduced from 24
                ),
                const SizedBox(width: 12), // Reduced from 16
                Text(
                  '$_totalRatings rating${_totalRatings == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12, // Reduced from 14
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // Reduced from 16
            _buildRecentRatings(),
          ] else ...[
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 40, // Reduced from 48
                    color: Colors.grey,
                  ),
                  SizedBox(height: 6), // Reduced from 8
                  Text(
                    'No ratings yet',
                    style: TextStyle(
                      fontSize: 14, // Reduced from 16
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 3), // Reduced from 4
                  Text(
                    'Be the first to rate this game!',
                    style: TextStyle(
                      fontSize: 12, // Reduced from 14
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentRatings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Friend Reviews Section
        if (_friendRatings.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.group,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Friend Reviews',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_friendRatings.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._friendRatings.take(3).map((rating) => _buildFriendRatingItem(rating)),
                if (_friendRatings.length > 3) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _showAllRatings,
                      child: Text(
                        'View All ${_friendRatings.length} Friend Reviews',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Community Reviews Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.public,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Community Reviews',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_gameRatings.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_gameRatings.isNotEmpty) ...[
                ..._gameRatings.take(5).map((rating) => _buildCommunityRatingItem(rating)),
                if (_gameRatings.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _showAllRatings,
                      child: Text(
                        'View All ${_gameRatings.length} Community Reviews',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'No community reviews yet. Be the first to review!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRatingItem(UserRating rating) {
    final currentUser = FirebaseAuthService().currentUser;
    final isLiked = currentUser != null && rating.likedBy.contains(currentUser.uid);
    final displayName = rating.displayName ?? rating.username;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Friend indicator badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'FRIEND',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF374151),
                backgroundImage: rating.profileImage != null && rating.profileImage!.isNotEmpty
                    ? CachedNetworkImageProvider(rating.profileImage!)
                    : null,
                child: rating.profileImage == null || rating.profileImage!.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Stack(
                    children: [
                      Icon(
                        Icons.star,
                        size: 10,
                        color: const Color(0xFF374151),
                      ),
                      if (rating.rating >= index + 1)
                        Icon(
                          Icons.star,
                          size: 10,
                          color: const Color(0xFF10B981),
                        ),
                      if (rating.rating == index + 0.5)
                        ClipRect(
                          clipper: HalfStarClipper(),
                          child: const Icon(
                            Icons.star,
                            size: 10,
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rating.review!,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: currentUser != null ? () => _toggleRatingLike(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.likeCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: currentUser != null ? () => _openRatingComments(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.commentCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityRatingItem(UserRating rating) {
    final currentUser = FirebaseAuthService().currentUser;
    final isLiked = currentUser != null && rating.likedBy.contains(currentUser.uid);
    final displayName = rating.displayName ?? rating.username;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Community indicator badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'COMMUNITY',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF374151),
                backgroundImage: rating.profileImage != null && rating.profileImage!.isNotEmpty
                    ? CachedNetworkImageProvider(rating.profileImage!)
                    : null,
                child: rating.profileImage == null || rating.profileImage!.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Stack(
                    children: [
                      Icon(
                        Icons.star,
                        size: 10,
                        color: const Color(0xFF374151),
                      ),
                      if (rating.rating >= index + 1)
                        Icon(
                          Icons.star,
                          size: 10,
                          color: const Color(0xFF6366F1),
                        ),
                      if (rating.rating == index + 0.5)
                        ClipRect(
                          clipper: HalfStarClipper(),
                          child: const Icon(
                            Icons.star,
                            size: 10,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rating.review!,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: currentUser != null ? () => _toggleRatingLike(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.likeCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: currentUser != null ? () => _openRatingComments(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.commentCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRatingItem(UserRating rating) {
    final userProfile = _ratingUserProfiles[rating.userId];
    final displayName = userProfile?['displayName'] ?? userProfile?['username'] ?? 'User';
    final profileImage = userProfile?['profileImage'] ?? '';
    final currentUser = FirebaseAuthService().currentUser;
    final isLiked = currentUser != null && rating.likedBy.contains(currentUser.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Reduced from 8
      padding: const EdgeInsets.all(10), // Reduced from 12
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(6), // Reduced from 8
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10, // Reduced from 12
                backgroundColor: const Color(0xFF6366F1),
                backgroundImage: profileImage.isNotEmpty && profileImage.startsWith('http')
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage.isEmpty || !profileImage.startsWith('http')
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 8, // Reduced from 10
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6), // Reduced from 8
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 12, // Reduced from 14
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Stack(
                    children: [
                      Icon(
                        Icons.star,
                        size: 10, // Reduced from 12
                        color: const Color(0xFF374151),
                      ),
                      // Full star overlay - only show if rating is >= index + 1
                      if (rating.rating >= index + 1)
                        Icon(
                          Icons.star,
                          size: 10, // Reduced from 12
                          color: const Color(0xFF10B981), // Green color like in reference
                        ),
                      // Half star overlay - only show if rating is exactly index + 0.5
                      if (rating.rating == index + 0.5)
                        ClipRect(
                          clipper: HalfStarClipper(),
                          child: const Icon(
                            Icons.star,
                            size: 10, // Reduced from 12
                            color: Color(0xFF10B981), // Green color like in reference
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 6), // Reduced from 8
            Text(
              rating.review!,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Like and comment buttons
          const SizedBox(height: 8),
          Row(
            children: [
              // Like button
              GestureDetector(
                onTap: currentUser != null ? () => _toggleRatingLike(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.likeCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Comment button
              GestureDetector(
                onTap: currentUser != null ? () => _openRatingComments(rating) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.commentCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRatingLike(UserRating rating) async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    // Optimistic update - update UI immediately
    final wasLiked = rating.likedBy.contains(currentUser.uid);
    final ratingIndex = _gameRatings.indexWhere((r) => r.id == rating.id);
    
    if (ratingIndex != -1) {
      setState(() {
        if (wasLiked) {
          // Unlike: remove user from likedBy and decrease count
          final newLikedBy = List<String>.from(_gameRatings[ratingIndex].likedBy);
          newLikedBy.remove(currentUser.uid);
          _gameRatings[ratingIndex] = _gameRatings[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: (_gameRatings[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
          );
        } else {
          // Like: add user to likedBy and increase count
          final newLikedBy = List<String>.from(_gameRatings[ratingIndex].likedBy);
          newLikedBy.add(currentUser.uid);
          _gameRatings[ratingIndex] = _gameRatings[ratingIndex].copyWith(
            likedBy: newLikedBy,
            likeCount: _gameRatings[ratingIndex].likeCount + 1,
          );
        }
      });
    }

    try {
      await RatingInteractionService.instance.toggleRatingLike(rating.id, currentUser.uid);
      
      // Refresh all rating data to get real-time updates
      await _refreshAllRatingData();
      
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
            final newLikedBy = List<String>.from(_gameRatings[ratingIndex].likedBy);
            newLikedBy.add(currentUser.uid);
            _gameRatings[ratingIndex] = _gameRatings[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: _gameRatings[ratingIndex].likeCount + 1,
            );
          } else {
            // Revert like: remove user and decrease count
            final newLikedBy = List<String>.from(_gameRatings[ratingIndex].likedBy);
            newLikedBy.remove(currentUser.uid);
            _gameRatings[ratingIndex] = _gameRatings[ratingIndex].copyWith(
              likedBy: newLikedBy,
              likeCount: (_gameRatings[ratingIndex].likeCount - 1).clamp(0, double.infinity).toInt(),
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
      // Refresh the entire rating data when returning from comments to get real-time updates
      _refreshAllRatingData();
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

  Future<void> _refreshAllRatingData() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;
      
      // Get ALL ratings for this game from both old and new structures
      final oldGameRatings = await RatingService.instance.getGameRatings(widget.gameId);
      final newGameRatings = await _getAllRatingsForGame(widget.gameId);
      
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
      
      final gameRatings = allRatingsMap.values.toList();
      gameRatings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Load interaction data for each rating (likes and comments)
      final enrichedRatings = <UserRating>[];
      for (final rating in gameRatings.take(10)) { // Limit to first 10 for performance
        try {
          final interactionData = await RatingInteractionService.instance
              .getRatingWithInteractions(rating.id, currentUser.uid);
          final enrichedRating = interactionData['rating'] as UserRating? ?? rating;
          enrichedRatings.add(enrichedRating);
        } catch (e) {
          debugPrint('Error loading interactions for rating ${rating.id}: $e');
          // Fallback to original rating if interaction loading fails
          enrichedRatings.add(rating);
        }
      }
      
      // Load friend ratings for this game
      final friendRatings = await _getFriendRatingsForGame(widget.gameId);
      
      // Enrich friend ratings with interaction data
      final enrichedFriendRatings = <UserRating>[];
      for (final rating in friendRatings) {
        try {
          final interactionData = await RatingInteractionService.instance
              .getRatingWithInteractions(rating.id, currentUser.uid);
          final enrichedRating = interactionData['rating'] as UserRating? ?? rating;
          enrichedFriendRatings.add(enrichedRating);
        } catch (e) {
          debugPrint('Error loading interactions for friend rating ${rating.id}: $e');
          // Fallback to original rating if interaction loading fails
          enrichedFriendRatings.add(rating);
        }
      }
      
      // Load user profiles for ratings and enrich the rating objects
      final Map<String, Map<String, dynamic>> profiles = {};
      final List<UserRating> finalEnrichedRatings = [];
      final List<UserRating> finalEnrichedFriendRatings = [];
      
      // Process community ratings (exclude current user's own review)
      for (final rating in enrichedRatings) {
        // Skip current user's own review in community section
        if (rating.userId == currentUser.uid) continue;
        
        Map<String, dynamic>? profile;
        if (!profiles.containsKey(rating.userId)) {
          profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
          }
        } else {
          profile = profiles[rating.userId];
        }
        
        // Create final enriched rating with both interaction data and user profile data
        final finalRating = rating.copyWith(
          displayName: profile?['displayName'] ?? profile?['username'] ?? rating.displayName,
          username: profile?['username'] ?? rating.username,
          profileImage: profile?['profileImage'] ?? rating.profileImage,
        );
        finalEnrichedRatings.add(finalRating);
      }
      
      // Process friend ratings
      for (final rating in enrichedFriendRatings) {
        Map<String, dynamic>? profile;
        if (!profiles.containsKey(rating.userId)) {
          profile = await UserDataService.getUserProfile(rating.userId);
          if (profile != null) {
            profiles[rating.userId] = profile;
          }
        } else {
          profile = profiles[rating.userId];
        }
        
        // Create final enriched friend rating with both interaction data and user profile data
        final finalRating = rating.copyWith(
          displayName: profile?['displayName'] ?? profile?['username'] ?? rating.displayName,
          username: profile?['username'] ?? rating.username,
          profileImage: profile?['profileImage'] ?? rating.profileImage,
        );
        finalEnrichedFriendRatings.add(finalRating);
      }
      
      if (mounted) {
        setState(() {
          _gameRatings = finalEnrichedRatings;
          _friendRatings = finalEnrichedFriendRatings;
          _ratingUserProfiles = profiles;
          _averageRating = gameRatings.isEmpty 
              ? 0.0 
              : gameRatings.map((r) => r.rating).reduce((a, b) => a + b) / gameRatings.length;
          _totalRatings = gameRatings.length;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing rating data: $e');
    }
  }

  Future<void> _refreshSingleRatingInDetail(UserRating rating) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;
      
      // Get updated rating data with interactions
      final data = await RatingInteractionService.instance.getRatingWithInteractions(rating.id, currentUser.uid);
      final updatedRating = data['rating'] as UserRating?;
      
      if (updatedRating != null) {
        final ratingIndex = _gameRatings.indexWhere((r) => r.id == rating.id);
        if (ratingIndex != -1) {
          setState(() {
            _gameRatings[ratingIndex] = updatedRating;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing single rating in detail: $e');
    }
  }

  Widget _buildSimilarGamesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Similar Games',
          style: TextStyle(
            fontSize: 18, // Reduced from 20
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12), // Reduced from 16
        if (_isLoadingSimilarGames)
          const Center(child: CircularProgressIndicator())
        else if (_similarGames.isEmpty)
          const Center(
            child: Text(
              'No similar games found',
              style: TextStyle(color: Colors.grey, fontSize: 13), // Smaller text
            ),
          )
        else
          SizedBox(
            height: 160, // Reduced from 200
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _similarGames.length,
              itemBuilder: (context, index) {
                final game = _similarGames[index];
                return _buildSimilarGameCard(game);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSimilarGameCard(Game game) {
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
        width: 100, // Reduced from 120
        margin: const EdgeInsets.only(right: 10), // Reduced from 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6), // Reduced from 8
                child: game.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: game.coverImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.games, color: Colors.white),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.games, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 6), // Reduced from 8
            Text(
              game.title,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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

// Custom clipper for half stars
class HalfStarClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}