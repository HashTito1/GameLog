import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/recommendation_service.dart';
import '../services/user_data_service.dart';
import '../services/follow_service.dart';
import '../services/event_bus.dart';
import '../services/rating_interaction_service.dart';
import 'game_ratings_screen.dart';
import 'create_forum_post_screen.dart';
// import 'rating_comments_screen.dart';

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
  Map<String, Map<String, dynamic>> _ratingUserProfiles = {};
  double _averageRating = 0.0;
  int _totalRatings = 0;
  
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

      // Load rating data using both new and old structures
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        // Check if this game is the user's favorite
        await _loadFavoriteStatus();
        
        // Get user's rating from the new structure
        final userRatings = await UserDataService.getUserRatings(currentUser.uid, limit: 1000);
        final userRating = userRatings.firstWhere(
          (rating) => rating['gameId'] == widget.gameId,
          orElse: () => <String, dynamic>{},
        );
        
        debugPrint('🔍 User ratings count: ${userRatings.length}');
        debugPrint('🔍 User rating for game ${widget.gameId}: $userRating');
        
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
        
        // Load user profiles for ALL ratings (not just first 3)
        final Map<String, Map<String, dynamic>> profiles = {};
        for (final rating in gameRatings) {
          if (!profiles.containsKey(rating.userId)) {
            final profile = await UserDataService.getUserProfile(rating.userId);
            if (profile != null) {
              profiles[rating.userId] = profile;
            }
          }
        }
        
        // Load current library status
        final libraryEntry = await LibraryService.instance.getGameFromLibrary(currentUser.uid, widget.gameId);
        final currentStatus = libraryEntry?['status'] as String?;
        
        if (mounted) {
          setState(() {
            // Convert user rating data to UserRating object if it exists
            if (userRating.isNotEmpty) {
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
            } else {
              _userRating = null;
            }
            
            _gameRatings = gameRatings;
            _ratingUserProfiles = profiles;
            _averageRating = gameRatings.isEmpty 
                ? 0.0 
                : gameRatings.map((r) => r.rating).reduce((a, b) => a + b) / gameRatings.length;
            _totalRatings = gameRatings.length;
            _currentLibraryStatus = currentStatus;
            
            if (_userRating != null) {
              _selectedRating = _userRating!.rating;
              _reviewController.text = _userRating!.review ?? '';
            }
          });
        }
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

    setState(() => _isSubmittingRating = true);

    try {
      final currentUser = FirebaseAuthService().currentUser;
      debugPrint('🔍 Current user: ${currentUser?.id} (${currentUser?.email})');
      debugPrint('🎮 Game ID: ${widget.gameId}');
      debugPrint('⭐ Rating: $_selectedRating');
      
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
        // Get user's rating from the new structure
        final userRatings = await UserDataService.getUserRatings(currentUser.uid, limit: 1000);
        final userRating = userRatings.firstWhere(
          (rating) => rating['gameId'] == widget.gameId,
          orElse: () => <String, dynamic>{},
        );
        
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
        
        // Load user profiles for ratings (limit to avoid performance issues)
        final Map<String, Map<String, dynamic>> profiles = {};
        for (final rating in gameRatings.take(10)) { // Only load profiles for first 10 ratings
          if (!profiles.containsKey(rating.userId)) {
            final profile = await UserDataService.getUserProfile(rating.userId);
            if (profile != null) {
              profiles[rating.userId] = profile;
            }
          }
        }
        
        if (mounted) {
          setState(() {
            // Convert user rating data to UserRating object if it exists
            if (userRating.isNotEmpty) {
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
            } else {
              _userRating = null;
            }
            
            _gameRatings = gameRatings;
            _ratingUserProfiles = profiles;
            _averageRating = gameRatings.isEmpty 
                ? 0.0 
                : gameRatings.map((r) => r.rating).reduce((a, b) => a + b) / gameRatings.length;
            _totalRatings = gameRatings.length;
            
            if (_userRating != null) {
              _selectedRating = _userRating!.rating;
              _reviewController.text = _userRating!.review ?? '';
            }
          });
        }
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to library as ${status.replaceAll('_', ' ')}'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2937),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_game == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2937),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Game not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
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
                  const SizedBox(height: 16), // Reduced from 24
                  _buildGameInfo(),
                  const SizedBox(height: 16), // Reduced from 24
                  _buildRatingSection(),
                  const SizedBox(height: 16), // Reduced from 24
                  _buildCommunityRatingsSection(),
                  const SizedBox(height: 16), // Reduced from 24
                  _buildLibrarySection(),
                  const SizedBox(height: 16), // Reduced from 24
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
        // Forum post button
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CreateForumPostScreen(
                  gameId: widget.gameId,
                  gameTitle: _game?.title,
                ),
              ),
            );
          },
          icon: const Icon(Icons.forum, color: Colors.white),
          tooltip: 'Create Forum Post',
        ),
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
            fontSize: 22, // Reduced from 24
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6), // Reduced from 8
        Text(
          _game?.developer ?? '',
          style: const TextStyle(
            fontSize: 14, // Reduced from 16
            color: Colors.grey,
          ),
        ),
        if ((_game?.releaseDate?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 3), // Reduced from 4
          Text(
            'Released: ${_game!.releaseDate}',
            style: const TextStyle(
              fontSize: 12, // Reduced from 14
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGameInfo() {
    final description = (_game?.description?.isNotEmpty ?? false) ? _game!.description : 'No description available.';
    final isLongDescription = description.length > 150;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(
            fontSize: 18, // Reduced from 20
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6), // Reduced from 8
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isDescriptionExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          firstChild: Text(
            isLongDescription 
                ? '${description.substring(0, 150)}...' 
                : description,
            style: const TextStyle(
              fontSize: 13, // Reduced from 14
              color: Colors.grey,
              height: 1.4, // Reduced line height
            ),
          ),
          secondChild: Text(
            description,
            style: const TextStyle(
              fontSize: 13, // Reduced from 14
              color: Colors.grey,
              height: 1.4, // Reduced line height
            ),
          ),
        ),
        if (isLongDescription) ...[
          const SizedBox(height: 6), // Reduced from 8
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Text(
              _isDescriptionExpanded ? 'Show less' : 'Show more',
              style: const TextStyle(
                fontSize: 13, // Reduced from 14
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
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
            onPressed: () {
              Navigator.of(context).pop();
              _submitRating();
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
                'Community Ratings',
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
    final recentRatings = _gameRatings.take(5).toList(); // Show more ratings
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'App User Reviews',
              style: TextStyle(
                fontSize: 14, // Reduced from 16
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_gameRatings.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8), // Reduced from 12
        if (recentRatings.isNotEmpty) ...[
          ...recentRatings.map((rating) => _buildRecentRatingItem(rating)),
          if (_gameRatings.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showAllRatings,
                child: Text(
                  'View All ${_gameRatings.length} Reviews',
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
            padding: const EdgeInsets.all(10), // Reduced from 12
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(6), // Reduced from 8
            ),
            child: const Text(
              'No app user reviews yet. Be the first to review!',
              style: TextStyle(
                fontSize: 12, // Reduced from 14
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ],
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

    try {
      await RatingInteractionService.instance.toggleRatingLike(rating.id, currentUser.uid);
      
      // Update the local rating data
      await _updateRatingDataOnly();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rating.likedBy.contains(currentUser.uid) ? 'Rating unliked!' : 'Rating liked!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
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
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => RatingCommentsScreen(rating: rating),
    //   ),
    // ).then((_) {
    //   // Refresh rating data when returning from comments screen
    //   _updateRatingDataOnly();
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments feature temporarily disabled')),
    );
  }

  Widget _buildLibrarySection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10), // Slightly smaller radius
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark,
                color: Color(0xFF10B981),
                size: 18, // Smaller icon
              ),
              const SizedBox(width: 6), // Reduced spacing
              const Text(
                'My Library',
                style: TextStyle(
                  fontSize: 16, // Smaller text
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_currentLibraryStatus != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1), width: 1),
                  ),
                  child: Text(
                    _currentLibraryStatus!.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12), // Reduced spacing
          
          // Library status filters (compact horizontal scroll)
          SizedBox(
            height: 32, // Compact height
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildLibraryFilterChip('Want to Play', 'want_to_play', Icons.bookmark_add),
                _buildLibraryFilterChip('Playing', 'playing', Icons.play_circle),
                _buildLibraryFilterChip('Completed', 'completed', Icons.check_circle),
                _buildLibraryFilterChip('Dropped', 'dropped', Icons.cancel),
                _buildLibraryFilterChip('On Hold', 'on_hold', Icons.pause_circle),
                _buildLibraryFilterChip('Backlog', 'backlog', Icons.bookmark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Add to Playlist button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddToPlaylistDialog,
              icon: const Icon(Icons.playlist_add, size: 16),
              label: const Text('Add to Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10), // Reduced padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryFilterChip(String label, String status, IconData icon) {
    final isSelected = _currentLibraryStatus == status;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: () => _addToLibrary(status),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected 
              ? const Color(0xFF6366F1) 
              : const Color(0xFF374151),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isSelected 
                ? const BorderSide(color: Color(0xFF6366F1), width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylistDialog() async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null || _game == null) return;

    // Get user's playlists with full details
    final playlists = await UserDataService.getUserPlaylistsWithGames(currentUser.uid);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Add to Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: playlists.isEmpty
            ? const Text(
                'No playlists found. Create a playlist in your profile first.',
                style: TextStyle(color: Colors.grey),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
                    final isGameInPlaylist = games.any((game) => game['gameId'] == widget.gameId);
                    
                    return ListTile(
                      leading: const Icon(Icons.playlist_play, color: Color(0xFF8B5CF6)),
                      title: Text(
                        playlist['name'] ?? 'Unnamed Playlist',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${games.length} games${isGameInPlaylist ? ' • Already added' : ''}',
                        style: TextStyle(
                          color: isGameInPlaylist ? Colors.orange : Colors.grey, 
                          fontSize: 12
                        ),
                      ),
                      trailing: isGameInPlaylist 
                          ? const Icon(Icons.check, color: Colors.orange)
                          : null,
                      onTap: isGameInPlaylist 
                          ? null 
                          : () {
                              Navigator.of(context).pop();
                              _addToPlaylistNew(playlist);
                            },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (playlists.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Go to Profile tab to create playlists!'),
                    backgroundColor: Color(0xFF8B5CF6),
                  ),
                );
              },
              child: const Text('Create Playlist', style: TextStyle(color: Color(0xFF8B5CF6))),
            ),
        ],
      ),
    );
  }

  Future<void> _addToPlaylistNew(Map<String, dynamic> playlist) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null || _game == null) return;

      await UserDataService.addGameToPlaylist(
        userId: currentUser.uid,
        playlistId: playlist['id'],
        gameId: widget.gameId,
        gameTitle: _game!.title,
        gameCoverImage: _game!.coverImage,
        gameDeveloper: _game!.developer,
        gameGenres: _game!.genres,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "${playlist['name']}" playlist!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to playlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

// Custom clipper for half stars
class HalfStarClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}