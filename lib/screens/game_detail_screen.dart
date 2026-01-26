import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../services/rawg_service.dart';
import '../services/rating_service.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/recommendation_service.dart';
import '../services/event_bus.dart';

// Temporary FriendsService stub for game detail screen
class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();
  static FriendsService get instance => _instance;

  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    return [];
  }
}


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
  bool _isSubmittingRating = false;
  
  // Rating data
  UserRating? _userRating;
  // List<UserRating> _gameRatings = []; // unused
  double _averageRating = 0.0;
  int _totalRatings = 0;
  
  // Rating input
  double _selectedRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  // final bool _isQuickRating = false; // unused
  
  // Library status
  bool _isInLibrary = false;
  
  // Similar games
  List<Game> _similarGames = [];
  bool _isLoadingSimilarGames = false;
  
  // Event subscription
  StreamSubscription<RatingSubmittedEvent>? _ratingSubmittedSubscription;

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loadGameData();
    _loadRatingData();
    _checkLibraryStatus();
    _loadSimilarGames();
    
    // Subscribe to rating events
    _ratingSubmittedSubscription = EventBus.instance.ratingSubmitted.listen((event) {
      if (event.gameId == widget.gameId) {
        _loadRatingData();
      }
    });
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _ratingSubmittedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadGameData() async {
    if (_game != null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final game = await RAWGService.instance.getGameDetails(widget.gameId);
      if (mounted) {
        setState(() {
          _game = game;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load game details: $e')),
        );
      }
    }
  }

  Future<void> _loadRatingData() async {
    try {
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final userRating = await RatingService.instance.getUserRating(
          currentUser.uid,
          widget.gameId,
        );
        
        final gameRatings = await RatingService.instance.getGameRatings(widget.gameId);
        
        if (mounted) {
          setState(() {
            _userRating = userRating;
            // _gameRatings = gameRatings; // unused
            _averageRating = gameRatings.isEmpty 
                ? 0.0 
                : gameRatings.map((r) => r.rating).reduce((a, b) => a + b) / gameRatings.length;
            _totalRatings = gameRatings.length;
            
            if (userRating != null) {
              _selectedRating = userRating.rating;
              _reviewController.text = userRating.review ?? '';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading rating data: $e');
    }
  }

  Future<void> _checkLibraryStatus() async {
    try {
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final libraryEntry = await LibraryService.instance.getLibraryEntry(
          currentUser.uid,
          widget.gameId,
        );
        
        if (mounted) {
          setState(() {
            _isInLibrary = libraryEntry != null;
            // _currentLibraryStatus = libraryEntry?['status']; // unused
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking library status: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) return;

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      
      if (currentUser != null && _game != null) {
        await RatingService.instance.submitRating(
          userId: currentUser.uid,
          gameId: widget.gameId,
          username: currentUser.displayName,
          rating: _selectedRating,
          review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        );
        
        await _loadRatingData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating submitted successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Future<void> _deleteRating() async {
    setState(() {
      _isSubmittingRating = true;
    });

    try {
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        await RatingService.deleteRating(widget.gameId, currentUser.uid);
        
        // Reset the UI state
        setState(() {
          _userRating = null;
          _selectedRating = 0.0;
          _reviewController.clear();
        });
        
        await _loadRatingData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating deleted successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rating: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Future<void> _toggleLibraryStatus() async {
    try {
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      
      if (currentUser != null && _game != null) {
        if (_isInLibrary) {
          await LibraryService.instance.removeFromLibrary(
            currentUser.uid,
            widget.gameId,
          );
        } else {
          await LibraryService.instance.addToLibrary(
            userId: currentUser.uid,
            game: _game!,
            status: 'want_to_play',
          );
        }
        
        await _checkLibraryStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update library: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(_game?.title ?? 'Game Details'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _game == null
              ? const Center(child: Text('Game not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGameHeader(),
                      const SizedBox(height: 24),
                      _buildGameInfo(),
                      const SizedBox(height: 24),
                      _buildRatingSection(),
                      const SizedBox(height: 24),
                      _buildLibrarySection(),
                      const SizedBox(height: 24),
                      _buildRecommendSection(),
                      const SizedBox(height: 24),
                      _buildSimilarGamesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGameHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_game!.coverImage.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _game!.coverImage,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: const Color(0xFF374151),
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: const Color(0xFF374151),
                child: const Center(child: const Icon(Icons.error)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          _game!.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (_game!.releaseDate.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Released: ${_game!.releaseDate}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGameInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_game!.description.isNotEmpty) ...[
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _game!.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_game!.genres.isNotEmpty) ...[
          const Text(
            'Genres',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _game!.genres.map((genre) => Chip(
              label: Text(genre),
              backgroundColor: const Color(0xFF374151),
              labelStyle: const TextStyle(color: Colors.white),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_game!.platforms.isNotEmpty) ...[
          const Text(
            'Platforms',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _game!.platforms.map((platform) => Chip(
              label: Text(platform),
              backgroundColor: const Color(0xFF1F2937),
              labelStyle: const TextStyle(color: Colors.white),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRatingSection() {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_totalRatings > 0)
                Text(
                  '${_averageRating.toStringAsFixed(1)}/5 ($_totalRatings reviews)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_userRating != null) ...[
            const Text(
              'Your Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < _userRating!.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                );
              }),
            ),
            if (_userRating!.review != null && _userRating!.review!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _userRating!.review!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          const Text(
            'Rate this game',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRating = (index + 1).toDouble();
                  });
                },
                child: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            decoration: const InputDecoration(
              hintText: 'Write a review (optional)',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            style: TextStyle(color: Colors.white),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedRating > 0 && !_isSubmittingRating ? _submitRating : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSubmittingRating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _userRating != null ? 'Update Rating' : 'Submit Rating',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ),
              if (_userRating != null) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: !_isSubmittingRating ? _deleteRating : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: _isSubmittingRating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete, color: Colors.white),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Library',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleLibraryStatus,
              icon: Icon(_isInLibrary ? Icons.remove : Icons.add),
              label: Text(_isInLibrary ? 'Remove from Library' : 'Add to Library'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isInLibrary ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSimilarGames() async {
    setState(() {
      _isLoadingSimilarGames = true;
    });

    try {
      final similarGames = await RecommendationService.instance.getSimilarGames(
        widget.gameId,
        limit: 6,
      );

      if (mounted) {
        setState(() {
          _similarGames = similarGames;
          _isLoadingSimilarGames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSimilarGames = false;
        });
      }
    }
  }

  Widget _buildRecommendSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommend to Friends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share this game with your friends and help them discover something new!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRecommendDialog(),
              icon: const Icon(Icons.share),
              label: const Text('Recommend Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildSimilarGamesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Similar Games',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingSimilarGames)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          )
        else if (_similarGames.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: const Center(
              child: Text(
                'No similar games found',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
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
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: game.coverImage,
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF374151),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF374151),
                          child: const Icon(
                            Icons.videogame_asset,
                            color: Colors.white54,
                            size: 30,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF374151),
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.white54,
                          size: 30,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (game.averageRating > 0)
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: 12,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    game.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRecommendDialog() async {
    // Get user's friends list
    final currentUser = FirebaseAuthService.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to recommend games!'),
        ),
      );
      return;
    }
    
    final friends = await FriendsService.instance.getFriends(currentUser.uid);
    
    if (friends.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add some friends first to recommend games!'),
          ),
        );
      }
      return;
    }

    final messageController = TextEditingController();
    String? selectedFriendId;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Recommend Game',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommend "${_game!.title}" to:',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedFriendId,
                  decoration: const InputDecoration(
                    labelText: 'Select Friend',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: const Color(0xFF1F2937),
                  style: const TextStyle(color: Colors.white),
                  items: friends.map((friend) => DropdownMenuItem<String>(
                    value: friend['friendId'],
                    child: Text(friend['friendId']), // Using friendId as display name for now
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedFriendId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: selectedFriendId == null
                    ? null
                    : () async {
                        final success = await RecommendationService.instance.recommendGame(
                          gameId: widget.gameId,
                          friendId: selectedFriendId!,
                          message: messageController.text.trim().isEmpty
                              ? null
                              : messageController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.of(context).pop();

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Game recommended successfully!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to recommend game'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('Recommend'),
              ),
            ],
          ),
        ),
      );
    }
  }
}


