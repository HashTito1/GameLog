import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/igdb_service.dart';
import '../services/event_bus.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  final String? initialPlaylistId;
  
  const LibraryScreen({super.key, this.initialPlaylistId});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _libraryGames = [];
  Map<String, dynamic> _libraryStats = {};
  bool _isLoading = true;
  StreamSubscription<LibraryUpdatedEvent>? _libraryUpdateSubscription;
  StreamSubscription<RatingSubmittedEvent>? _ratingSubmittedSubscription;
  
  late TabController _tabController;
  
  // Track expanded playlists
  Set<String> _expandedPlaylists = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // If we have an initial playlist ID, switch to playlists tab and expand it
    if (widget.initialPlaylistId != null) {
      _tabController.index = 1; // Switch to playlists tab
      _expandedPlaylists.add(widget.initialPlaylistId!);
    }
    
    _loadLibrary();
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _libraryUpdateSubscription = EventBus().on<LibraryUpdatedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && event.userId == currentUser.uid) {
                // Force refresh with loading state
        setState(() => _isLoading = true);
        _loadLibrary();
      }
    });
    
    _ratingSubmittedSubscription = EventBus().on<RatingSubmittedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
                // Force refresh with loading state
        setState(() => _isLoading = true);
        _loadLibrary();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _libraryUpdateSubscription?.cancel();
    _ratingSubmittedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final authService = FirebaseAuthService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final library = await LibraryService.instance.getUserLibrary(currentUser.uid);
      final stats = await LibraryService.instance.getUserLibraryStats(currentUser.uid);
      
      // Debug: Print each game's status
      for (final _ in library) {
        // Debug logging can be added here if needed
      }
      
      if (mounted) {
        setState(() {
          _libraryGames = library;
          _libraryStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading library: $e')),
        );
      }
    }
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
            _buildTabBar(theme),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    )
                  : _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'My Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Games'),
          Tab(text: 'Playlists'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGamesTab(),
        _buildPlaylistsTab(),
      ],
    );
  }

  Widget _buildGamesTab() {
    return Column(
      children: [
        // Stats bar at the top
        if (_libraryStats.isNotEmpty) _buildTopStatsBar(),
        Expanded(
          child: _libraryGames.isEmpty
              ? _buildEmptyState()
              : _buildHorizontalSectionsView(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videogame_asset_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Games Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start building your game library\nby rating and reviewing games',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadUserPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final playlists = snapshot.data ?? [];
          
          if (playlists.isEmpty) {
            return _buildEmptyPlaylistsState();
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _buildPlaylistItemWithGames(playlist);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadUserPlaylists() async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) return [];
    
    // In library screen, user is always viewing their own playlists, so show all
    return await UserDataService.getUserPlaylistsWithGamesFiltered(user.uid, currentUserId: user.uid);
  }

  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isCreating = false;
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text(
            'Create Playlist',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Playlist Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter playlist name',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter playlist description',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4B5563)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPublic ? Icons.public : Icons.lock,
                      color: isPublic ? const Color(0xFF10B981) : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPublic ? 'Public Playlist' : 'Private Playlist',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            isPublic 
                                ? 'Others can see this playlist on your profile'
                                : 'Only you can see this playlist',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isPublic,
                      onChanged: (value) {
                        setDialogState(() {
                          isPublic = value;
                        });
                      },
                      activeThumbColor: const Color(0xFF10B981),
                      activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a playlist name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isCreating = true);

                try {
                  await _createPlaylist(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    isPublic,
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playlist "${nameController.text.trim()}" created!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Refresh the playlists tab
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    setDialogState(() => isCreating = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create playlist: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist(String name, String description, bool isPublic) async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) throw Exception('User not logged in');

    await UserDataService.createPlaylistWithGames(
      userId: user.uid,
      playlistName: name,
      description: description,
      gameIds: [], // Empty playlist initially
      isPublic: isPublic,
    );
  }

  Widget _buildPlaylistItemWithGames(Map<String, dynamic> playlist) {
    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
    final playlistId = playlist['id'] ?? '';
    final isExpanded = _expandedPlaylists.contains(playlistId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPlaylists.remove(playlistId);
                } else {
                  _expandedPlaylists.add(playlistId);
                }
              });
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPlaylistIcon(playlist),
                    color: const Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(playlist['name'] ?? 'Unnamed Playlist',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            playlist['isPublic'] == true ? Icons.public : Icons.lock,
                            size: 14,
                            color: playlist['isPublic'] == true ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ],
                      ),
                      if ((playlist['description'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(playlist['description'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${games.length} games',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  color: const Color(0xFF374151),
                  onSelected: (value) {
                    switch (value) {
                      case 'add_games':
                        _showAddGamesToPlaylistDialog(playlist);
                        break;
                      case 'toggle_privacy':
                        _togglePlaylistPrivacy(playlist);
                        break;
                      case 'edit':
                        _showEditPlaylistDialog(playlist);
                        break;
                      case 'delete':
                        _showDeletePlaylistDialog(playlist);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_games',
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 8),
                          Text('Add Games', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_privacy',
                      child: Row(
                        children: [
                          Icon(
                            playlist['isPublic'] == true ? Icons.lock : Icons.public,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            playlist['isPublic'] == true ? 'Make Private' : 'Make Public',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Show games based on expansion state
          if (games.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (isExpanded) ...[
              // Expanded view - show games as a vertical list
              Column(
                children: games.map((game) => _buildPlaylistGameItem(game)).toList(),
              ),
            ] else ...[
              // Collapsed view - show horizontal thumbnails
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: game['gameCoverImage']?.isNotEmpty == true
                                  ? CachedNetworkImage(
                                      imageUrl: game['gameCoverImage'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[700],
                                        child: const Icon(Icons.videogame_asset,
                                          color: Colors.white54,
                                          size: 20,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[700],
                                        child: const Icon(Icons.videogame_asset,
                                          color: Colors.white54,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[700],
                                      child: const Icon(Icons.videogame_asset,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game['gameTitle'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No games in this playlist yet',
                    style: TextStyle(
                      fontSize: 12,
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

  Future<void> _showEditPlaylistDialog(Map<String, dynamic> playlist) async {
    final nameController = TextEditingController(text: playlist['name'] ?? '');
    final descriptionController = TextEditingController(text: playlist['description'] ?? '');
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text(
            'Edit Playlist',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Playlist Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
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
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a playlist name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isUpdating = true);

                try {
                  await _updatePlaylist(
                    playlist['id'],
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Playlist updated!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    setDialogState(() => isUpdating = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update playlist: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeletePlaylistDialog(Map<String, dynamic> playlist) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Delete Playlist',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist['name']}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await _deletePlaylist(playlist['id']);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playlist "${playlist['name']}" deleted'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete playlist: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGameItem(Map<String, dynamic> game) {
    final gameTitle = game['gameTitle'] ?? 'Unknown Game';
    final gameCoverImage = game['gameCoverImage'] ?? '';
    final gameDeveloper = game['gameDeveloper'] ?? 'Unknown Developer';
    final gameId = game['gameId'] ?? '';

    return GestureDetector(
      onTap: () {
        if (gameId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: gameId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: gameCoverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gameCoverImage,
                      width: 50,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey[800],
                        child: const Icon(Icons.videogame_asset,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey[800],
                        child: const Icon(Icons.videogame_asset,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameDeveloper,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePlaylist(String playlistId, String name, String description) async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get current playlist data
    final currentPlaylist = await UserDataService.getPlaylistDetails(user.id, playlistId);
    if (currentPlaylist == null) throw Exception('Playlist not found');

    // Update the playlist with new name and description
    final updatedPlaylist = {
      ...currentPlaylist,
      'name': name,
      'description': description,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Update in user's subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('playlists')
        .doc(playlistId)
        .set(updatedPlaylist);

    // Update in global collection
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlistId)
        .set(updatedPlaylist);

    // Update user profile playlist reference
    final userProfile = await UserDataService.getUserProfile(user.id);
    final playlists = List<Map<String, dynamic>>.from(userProfile?['playlists'] ?? []);
    final playlistIndex = playlists.indexWhere((p) => p['id'] == playlistId);
    if (playlistIndex != -1) {
      playlists[playlistIndex]['name'] = name;
      playlists[playlistIndex]['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      await UserDataService.createOrUpdateUserProfile(
        userId: user.id,
        playlists: playlists,
      );
    }
  }

  Future<void> _deletePlaylist(String playlistId) async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) throw Exception('User not logged in');

    await UserDataService.deletePlaylist(
      userId: user.id,
      playlistId: playlistId,
    );
  }

  Future<void> _showAddGamesToPlaylistDialog(Map<String, dynamic> playlist) async {
    final searchController = TextEditingController();
    List<Game> searchResults = [];
    bool isSearching = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add Games to "${playlist['name']}"',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search for games...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                    suffixIcon: isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.trim().isEmpty) {
                      setDialogState(() {
                        searchResults = [];
                        isSearching = false;
                      });
                      return;
                    }
                    
                    setDialogState(() => isSearching = true);
                    
                    try {
                      final results = await IGDBService.instance.searchGames(query.trim());
                      setDialogState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } catch (e) {
                      setDialogState(() => isSearching = false);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Search results
                Expanded(
                  child: searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isEmpty
                                    ? 'Search for games to add to your playlist'
                                    : 'No games found',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final game = searchResults[index];
                            final isAlreadyInPlaylist = (playlist['games'] as List?)
                                ?.any((g) => g['gameId'] == game.id) ?? false;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: game.coverImage.isNotEmpty
                                      ? Image.network(
                                          game.coverImage,
                                          width: 50,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            width: 50,
                                            height: 70,
                                            color: Colors.grey[700],
                                            child: const Icon(
                                              Icons.videogame_asset,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 70,
                                          color: Colors.grey[700],
                                          child: const Icon(
                                            Icons.videogame_asset,
                                            color: Colors.white54,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  game.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  game.releaseDate.isNotEmpty ? game.releaseDate : 'Unknown release date',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isAlreadyInPlaylist
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF10B981),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: Color(0xFF6366F1),
                                        ),
                                        onPressed: () async {
                                          try {
                                            final user = FirebaseAuthService().currentUser;
                                            if (user != null) {
                                              await UserDataService.addGameToPlaylist(
                                                userId: user.id,
                                                playlistId: playlist['id'],
                                                gameId: game.id,
                                                gameTitle: game.title,
                                                gameCoverImage: game.coverImage,
                                                gameDeveloper: game.developer,
                                                gameGenres: game.genres,
                                              );
                                              
                                              // Update local playlist data
                                              final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
                                              games.add({
                                                'gameId': game.id,
                                                'gameTitle': game.title,
                                                'gameCoverImage': game.coverImage,
                                                'gameDeveloper': game.developer,
                                                'gameGenres': game.genres,
                                                'addedAt': DateTime.now().millisecondsSinceEpoch,
                                              });
                                              playlist['games'] = games;
                                              
                                              setDialogState(() {});
                                              
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${game.title} added to playlist'),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to add game: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                tileColor: const Color(0xFF374151),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Refresh the playlists to show updated game count
                setState(() {});
              },
              child: const Text('Done', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlaylistIcon(Map<String, dynamic> playlist) {
    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
    final gameCount = games.length;
    
    // Choose icon based on playlist characteristics
    if (gameCount == 0) {
      return Icons.playlist_add;
    } else if (gameCount < 5) {
      return Icons.playlist_play;
    } else if (gameCount < 15) {
      return Icons.library_music;
    } else {
      return Icons.collections;
    }
  }

  Future<void> _togglePlaylistPrivacy(Map<String, dynamic> playlist) async {
    try {
      final user = FirebaseAuthService().currentUser;
      if (user != null) {
        final newPrivacy = !(playlist['isPublic'] == true);
        
        await UserDataService.updatePlaylistPrivacy(
          user.id,
          playlist['id'],
          newPrivacy,
        );
        
        // Update local state
        setState(() {
          playlist['isPublic'] = newPrivacy;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPrivacy 
                  ? 'Playlist is now public' 
                  : 'Playlist is now private',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update playlist privacy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyPlaylistsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play_outlined,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No Playlists Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create playlists to organize your games\ninto custom collections',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePlaylistDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSectionsView() {
    final theme = Theme.of(context);
    
    // Group games by status
    final backlogGames = _libraryGames.where((game) {
      final status = game['status'] as String?;
      final userRating = (game['userRating'] ?? 0.0).toDouble();
      return (status == 'want_to_play' || status == 'planToPlay' || status == 'backlog') && userRating == 0;
    }).toList();
    
    final playingGames = _libraryGames.where((game) {
      final status = game['status'] as String?;
      return status == 'playing';
    }).toList();
    
    final beatenGames = _libraryGames.where((game) {
      final status = game['status'] as String?;
      final userRating = (game['userRating'] ?? 0.0).toDouble();
      return status == 'completed' || userRating > 0;
    }).toList();
    
    final droppedGames = _libraryGames.where((game) {
      final status = game['status'] as String?;
      return status == 'dropped';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (backlogGames.isNotEmpty)
            _buildGameSection('Backlog', backlogGames, Icons.bookmark_border, theme),
          if (playingGames.isNotEmpty)
            _buildGameSection('Playing', playingGames, Icons.play_circle_outline, theme),
          if (beatenGames.isNotEmpty)
            _buildGameSection('Beaten', beatenGames, Icons.check_circle_outline, theme),
          if (droppedGames.isNotEmpty)
            _buildGameSection('Dropped', droppedGames, Icons.cancel_outlined, theme),
          
        ],
      ),
    );
  }

  Widget _buildTopStatsBar() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTopStatItem(
            (_libraryStats['totalGames'] ?? 0).toString(),
            'Games',
            Icons.videogame_asset,
            theme.colorScheme.primary,
          ),
          _buildStatDivider(theme),
          _buildTopStatItem(
            (_libraryStats['ratedGames'] ?? 0).toString(),
            'Rated',
            Icons.star,
            const Color(0xFFFBBF24),
          ),
          _buildStatDivider(theme),
          _buildTopStatItem(
            (_libraryStats['backlogGames'] ?? 0).toString(),
            'Backlog',
            Icons.bookmark_border,
            const Color(0xFF8B5CF6),
          ),
          _buildStatDivider(theme),
          _buildTopStatItem(
            (_libraryStats['averageRating'] ?? 0.0).toStringAsFixed(1),
            'Avg Rating',
            Icons.trending_up,
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatItem(String value, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(ThemeData theme) {
    return Container(
      height: 40,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            theme.colorScheme.outline.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildGameSection(String title, List<Map<String, dynamic>> games, IconData icon, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${games.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Show all games in this category
                  _showCategoryGames(title, games);
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _buildHorizontalGameCard(game, theme);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHorizontalGameCard(Map<String, dynamic> gameData, ThemeData theme) {
    final gameTitle = gameData['gameTitle'] ?? 'Unknown Game';
    final gameCoverImage = gameData['gameCoverImage'] ?? '';
    final userRating = (gameData['userRating'] ?? 0.0).toDouble();
    final gameId = gameData['gameId'] ?? '';

    return GestureDetector(
      onTap: () {
        if (gameId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: gameId,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: gameCoverImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: gameCoverImage,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surface,
                            child: Icon(
                              Icons.videogame_asset,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surface,
                            child: Icon(
                              Icons.videogame_asset,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surface,
                          child: Icon(
                            Icons.videogame_asset,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              gameTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (userRating > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    color: const Color(0xFFFBBF24),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    userRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCategoryGames(String category, List<Map<String, dynamic>> games) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CategoryGamesScreen(
          category: category,
          games: games,
        ),
      ),
    );
  }
}

class _CategoryGamesScreen extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> games;

  const _CategoryGamesScreen({
    required this.category,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '$category (${games.length})',
          style: TextStyle(
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final gameData = games[index];
          return _buildFullGameItem(gameData, theme, context);
        },
      ),
    );
  }

  Widget _buildFullGameItem(Map<String, dynamic> gameData, ThemeData theme, BuildContext context) {
    final gameTitle = gameData['gameTitle'] ?? 'Unknown Game';
    final gameCoverImage = gameData['gameCoverImage'] ?? '';
    final gameDeveloper = gameData['gameDeveloper'] ?? 'Unknown Developer';
    final userRating = (gameData['userRating'] ?? 0.0).toDouble();
    final userReview = gameData['userReview'];
    final gameId = gameData['gameId'] ?? '';

    return GestureDetector(
      onTap: () {
        if (gameId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: gameId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: gameCoverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gameCoverImage,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 80,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        child: Icon(Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 80,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        child: Icon(Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 80,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      child: Icon(Icons.videogame_asset,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameDeveloper,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (userRating > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < userRating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFBBF24),
                            size: 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          userRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (userReview != null && userReview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userReview,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}