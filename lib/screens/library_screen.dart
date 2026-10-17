import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/igdb_service.dart';
import '../services/event_bus.dart';
import '../models/library_status.dart';
import 'game_detail_screen.dart';
import 'main_screen.dart';

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

  // Games tab: category filter (null = All), search and sort.
  LibraryStatus? _filter;
  String _query = '';
  bool _searching = false;
  _LibrarySort _sort = _LibrarySort.recent;
  final _searchController = TextEditingController();
  StreamSubscription<LibraryUpdatedEvent>? _libraryUpdateSubscription;
  StreamSubscription<RatingSubmittedEvent>? _ratingSubmittedSubscription;
  
  late TabController _tabController;
  
  // Track expanded playlists
  final Set<String> _expandedPlaylists = <String>{};

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

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialPlaylistId;
    if (id != null && id != oldWidget.initialPlaylistId) {
      setState(() {
        _tabController.index = 1;
        _expandedPlaylists.add(id);
      });
    }
  }

  void _setupEventListeners() {
    _libraryUpdateSubscription = EventBus().on<LibraryUpdatedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null && event.userId == currentUser.uid) {
        _loadLibrary();
      }
    });
    
    _ratingSubmittedSubscription = EventBus().on<RatingSubmittedEvent>().listen((event) {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser != null) {
        _loadLibrary();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      final results = await Future.wait([
        LibraryService.instance.getUserLibrary(currentUser.uid),
        LibraryService.instance.getUserLibraryStats(currentUser.uid),
      ]);
      final library = results[0] as List<Map<String, dynamic>>;
      final stats = results[1] as Map<String, dynamic>;

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
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGamesTab(),
                        _buildPlaylistsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search your library',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _searching = false;
                _query = '';
                _searchController.clear();
              }),
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Text(
            'Library',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              _tabController.animateTo(0);
              setState(() => _searching = true);
            },
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          PopupMenuButton<_LibrarySort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final sort in _LibrarySort.values)
                CheckedPopupMenuItem(value: sort, checked: sort == _sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Games'),
          Tab(text: 'Playlists'),
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

                  if (context.mounted && mounted) {
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
                  if (context.mounted) {
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
                            color: const Color(0xFF6366F1),
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
                                  ? AppNetworkImage(
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

                  if (context.mounted && mounted) {
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
                  if (context.mounted) {
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();

              try {
                await _deletePlaylist(playlist['id']);

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Playlist "${playlist['name']}" deleted'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
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
                  ? AppNetworkImage(
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
                                              
                                              if (!context.mounted) return;
                                              setDialogState(() {});

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${game.title} added to playlist'),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
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
        
        if (!mounted) return;
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
      if (!mounted) return;
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

  // ---------------------------------------------------------------------------
  // Games tab
  // ---------------------------------------------------------------------------

  static const double _tileWidth = 116;
  static const double _tileCover = _tileWidth * 4 / 3;

  List<Map<String, dynamic>> _gamesIn(LibraryStatus? status) {
    final q = _query.trim().toLowerCase();
    final games = _libraryGames.where((g) {
      if (status != null && LibraryStatus.forEntry(g) != status) return false;
      if (q.isNotEmpty && !(g['gameTitle'] ?? '').toString().toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    int millis(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : (v is num ? v.toInt() : 0);
    double rating(Map<String, dynamic> g) => ((g['userRating'] ?? 0) as num).toDouble();
    switch (_sort) {
      case _LibrarySort.title:
        games.sort((a, b) => (a['gameTitle'] ?? '').toString().toLowerCase().compareTo((b['gameTitle'] ?? '').toString().toLowerCase()));
      case _LibrarySort.rating:
        games.sort((a, b) => rating(b).compareTo(rating(a)));
      case _LibrarySort.release:
        games.sort((a, b) => (b['gameReleaseDate'] ?? '').toString().compareTo((a['gameReleaseDate'] ?? '').toString()));
      case _LibrarySort.recent:
        games.sort((a, b) => millis(b['dateUpdated']).compareTo(millis(a['dateUpdated'])));
    }
    return games;
  }

  Map<LibraryStatus, int> get _counts {
    final counts = {for (final s in LibraryStatus.values) s: 0};
    for (final g in _libraryGames) {
      final s = LibraryStatus.forEntry(g);
      counts[s] = counts[s]! + 1;
    }
    return counts;
  }

  Widget _buildGamesTab() {
    final theme = Theme.of(context);
    if (_libraryGames.isEmpty) {
      return RefreshIndicator(onRefresh: _loadLibrary, child: _buildEmptyState());
    }
    final counts = _counts;
    final filtering = _filter != null || _query.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_query.isEmpty) SliverToBoxAdapter(child: _buildOverview(theme, counts)),
          SliverToBoxAdapter(child: _buildFilterChips(theme, counts)),
          if (filtering) ..._buildGrid(theme) else ..._buildSections(theme),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildOverview(ThemeData theme, Map<LibraryStatus, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final rated = _libraryStats['ratedGames'] ?? 0;
    final avg = ((_libraryStats['averageRating'] ?? 0.0) as num).toDouble();
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12.5, color: muted)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.onSurface.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              stat('$total', total == 1 ? 'game' : 'games'),
              stat('$rated', 'rated'),
              stat(avg > 0 ? avg.toStringAsFixed(1) : '–', 'avg rating'),
            ],
          ),
          const SizedBox(height: 16),
          // How the library splits across categories.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final s in LibraryStatus.libraryOrder)
                    if (counts[s]! > 0)
                      Expanded(flex: counts[s]!, child: Container(color: s.color)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final s in LibraryStatus.libraryOrder)
                if (counts[s]! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('${s.label} ${counts[s]}', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, Map<LibraryStatus, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    Widget chip({required String label, required int count, required bool selected, Color? color, IconData? icon, required VoidCallback onTap}) {
      final accent = color ?? theme.colorScheme.primary;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.18) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          shape: StadiumBorder(side: BorderSide(color: selected ? accent : Colors.transparent, width: 1.2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: selected ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      )),
                  const SizedBox(width: 6),
                  Text('$count',
                      style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        children: [
          chip(label: 'All', count: total, selected: _filter == null, onTap: () => setState(() => _filter = null)),
          for (final s in LibraryStatus.libraryOrder)
            chip(
              label: s.label,
              count: counts[s]!,
              selected: _filter == s,
              color: s.color,
              icon: s.icon,
              onTap: () => setState(() => _filter = _filter == s ? null : s),
            ),
        ],
      ),
    );
  }

  /// "All" view: one horizontal row per category.
  List<Widget> _buildSections(ThemeData theme) {
    return [
      for (final s in LibraryStatus.libraryOrder)
        if (_gamesIn(s).isNotEmpty)
          SliverToBoxAdapter(
            child: Builder(builder: (context) {
              final games = _gamesIn(s);
              return Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(s.icon, size: 17, color: s.color),
                          ),
                          const SizedBox(width: 10),
                          Text(s.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Text('${games.length}',
                              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _filter = s),
                            child: Text('See all', style: TextStyle(color: s.color)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: _tileCover + 8 + _textSlot(13, lines: 2) + 4,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: games.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => SizedBox(width: _tileWidth, child: _buildTile(theme, games[i])),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
    ];
  }

  /// Filtered or searched view: a grid of covers.
  List<Widget> _buildGrid(ThemeData theme) {
    final games = _gamesIn(_filter);
    if (games.isEmpty) {
      final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
            child: Column(
              children: [
                Icon(_filter?.icon ?? Icons.search_off_rounded, size: 52, color: _filter?.color.withValues(alpha: 0.7) ?? muted),
                const SizedBox(height: 12),
                Text(
                  _query.trim().isNotEmpty
                      ? 'No games match "${_query.trim()}".'
                      : 'Nothing in ${_filter!.label} yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _query.trim().isNotEmpty
                      ? 'Try another title.'
                      : 'Open any game and tap Add to library to put it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            // cover (3:4) + gap + two title lines
            childAspectRatio: 1 / (4 / 3 + (8 + _textSlot(13, lines: 2) + 4) / ((MediaQuery.sizeOf(context).width - 32 - 24) / 3)),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildTile(theme, games[i], showStatus: _filter == null),
            childCount: games.length,
          ),
        ),
      ),
    ];
  }

  double _textSlot(double fontSize, {int lines = 1}) =>
      MediaQuery.textScalerOf(context).scale(fontSize) * 1.3 * lines + 1;

  Widget _buildTile(ThemeData theme, Map<String, dynamic> game, {bool showStatus = false}) {
    final title = (game['gameTitle'] ?? 'Unknown game').toString();
    final cover = (game['gameCoverImage'] ?? '').toString();
    final rating = ((game['userRating'] ?? 0) as num).toDouble();
    final status = LibraryStatus.forEntry(game);

    return GestureDetector(
      onTap: () => _openGame(game),
      onLongPress: () => _showGameActions(game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(imageUrl: cover, fit: BoxFit.cover),
                ),
                if (rating > 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (showStatus)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
                      child: Icon(status.icon, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _textSlot(13, lines: 2),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _openGame(Map<String, dynamic> game) {
    final gameId = (game['gameId'] ?? '').toString();
    if (gameId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: gameId)));
  }

  /// Long-press: move a game to another category, open it or remove it.
  void _showGameActions(Map<String, dynamic> game) {
    final theme = Theme.of(context);
    final current = LibraryStatus.forEntry(game);
    final title = (game['gameTitle'] ?? 'this game').toString();
    final cover = (game['gameCoverImage'] ?? '').toString();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppNetworkImage(imageUrl: cover, width: 44, height: 59, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Move to', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in LibraryStatus.pickerOrder)
                    ChoiceChip(
                      avatar: Icon(s.icon, size: 16, color: s == current ? Colors.white : s.color),
                      label: Text(s.label),
                      selected: s == current,
                      showCheckmark: false,
                      selectedColor: s.color,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: s == current ? Colors.white : theme.colorScheme.onSurface,
                      ),
                      onSelected: (_) {
                        Navigator.pop(sheet);
                        if (s != current) _moveGame(game, s);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: Colors.transparent,
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open game'),
                onTap: () {
                  Navigator.pop(sheet);
                  _openGame(game);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: Colors.transparent,
                leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                title: Text('Remove from library', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.pop(sheet);
                  _removeGame(game);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveGame(Map<String, dynamic> game, LibraryStatus status) async {
    final me = FirebaseAuthService().currentUser;
    if (me == null) return;
    final previous = game['status'];
    // Move it on screen straight away; put it back if saving fails.
    setState(() => game['status'] = status.value);
    try {
      await LibraryService.instance.setStatus(me.uid, game, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to ${status.label}'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => game['status'] = previous);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not move it. Try again.')));
    }
  }

  Future<void> _removeGame(Map<String, dynamic> game) async {
    final me = FirebaseAuthService().currentUser;
    final gameId = (game['gameId'] ?? '').toString();
    if (me == null || gameId.isEmpty) return;
    final rated = ((game['userRating'] ?? 0) as num) > 0;
    final title = (game['gameTitle'] ?? 'This game').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text(rated ? 'This also deletes your rating and review of $title.' : '$title will be removed from your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final index = _libraryGames.indexOf(game);
    setState(() => _libraryGames.remove(game));
    try {
      await LibraryService.instance.removeGameFromLibrary(me.uid, gameId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _libraryGames.insert(index.clamp(0, _libraryGames.length), game));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove it. Try again.')));
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.collections_bookmark_rounded, size: 44, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Your library is empty',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Track what you want, what you\'re playing and what you\'ve finished. Open any game and tap Add to library.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: () => context.findAncestorStateOfType<MainScreenState>()?.switchToTab(2),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find games'),
          ),
        ),
      ],
    );
  }
}

enum _LibrarySort {
  recent('Recently updated'),
  title('Title (A–Z)'),
  rating('Your rating'),
  release('Release date');

  final String label;
  const _LibrarySort(this.label);
}
