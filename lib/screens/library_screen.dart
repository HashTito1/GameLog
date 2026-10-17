import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/library_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/event_bus.dart';
import '../models/library_status.dart';
import 'game_detail_screen.dart';
import 'main_screen.dart';
import 'playlist_screen.dart';

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
  
  // Playlists tab
  List<Map<String, dynamic>> _playlists = [];
  bool _playlistsLoaded = false;
  String? _pendingPlaylistId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Asked to show a playlist: switch to Playlists and open it once loaded.
    if (widget.initialPlaylistId != null) {
      _tabController.index = 1;
      _pendingPlaylistId = widget.initialPlaylistId;
    }
    
    _loadLibrary();
    _setupEventListeners();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialPlaylistId;
    if (id != null && id != oldWidget.initialPlaylistId) {
      _tabController.animateTo(1);
      _pendingPlaylistId = id;
      _openPendingPlaylist();
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
      _loadPlaylists();
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

  // ---------------------------------------------------------------------------
  // Playlists tab
  // ---------------------------------------------------------------------------

  Future<void> _loadPlaylists() async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) return;
    final playlists = await UserDataService.getUserPlaylistsWithGamesFiltered(user.uid, currentUserId: user.uid);
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _playlistsLoaded = true;
    });
    _openPendingPlaylist();
  }

  /// A playlist asked for from elsewhere (e.g. a shared link) opens once
  /// playlists have loaded.
  void _openPendingPlaylist() {
    final id = _pendingPlaylistId;
    if (id == null || !_playlistsLoaded) return;
    _pendingPlaylistId = null;
    final playlist = _playlists.where((p) => p['id'] == id).firstOrNull;
    if (playlist != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPlaylist(playlist));
    }
  }

  Future<void> _openPlaylist(Map<String, dynamic> playlist) async {
final changed= await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => PlaylistScreen(playlist: playlist, libraryGames: _libraryGames)),
    );
    if (changed == true) _loadPlaylists();
  }

  Future<void> _createPlaylist() async {
    if (await showPlaylistEditor(context)) _loadPlaylists();
  }

  void _playlistActions(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    final isPublic = playlist['isPublic'] == true;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              tileColor: Colors.transparent,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () async {
                Navigator.pop(sheet);
                if (await showPlaylistEditor(context, playlist: playlist)) _loadPlaylists();
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(isPublic ? Icons.lock_outline_rounded : Icons.public_rounded),
              title: Text(isPublic ? 'Make private' : 'Make public'),
              subtitle: Text(isPublic ? 'Hide it from your profile' : 'Show it on your profile as a recommendation'),
              onTap: () {
                Navigator.pop(sheet);
                _togglePlaylistPrivacy(playlist);
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              title: Text('Delete playlist', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(sheet);
                _deletePlaylist(playlist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlaylistPrivacy(Map<String, dynamic> playlist) async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) return;
    final next = !(playlist['isPublic'] == true);
    setState(() => playlist['isPublic'] = next);
    try {
      await UserDataService.updatePlaylistPrivacy(user.uid, playlist['id'], next);
    } catch (e) {
      if (!mounted) return;
      setState(() => playlist['isPublic'] = !next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not change privacy. Try again.')));
    }
  }

  Future<void> _deletePlaylist(Map<String, dynamic> playlist) async {
    final user = FirebaseAuthService().currentUser;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('"${playlist['name']}" will be deleted. The games stay in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || user == null) return;
    setState(() => _playlists.remove(playlist));
    try {
      await UserDataService.deletePlaylist(userId: user.uid, playlistId: playlist['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete it. Try again.')));
      _loadPlaylists();
    }
  }

  Widget _buildPlaylistsTab() {
    final theme = Theme.of(context);
    if (!_playlistsLoaded) return const Center(child: CircularProgressIndicator());
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    if (_playlists.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPlaylists,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.queue_music_rounded, size: 44, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text('No playlists yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Group games into collections like "Cozy weekend" or "Best co-op". Make one public to recommend it on your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: muted),
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton.icon(
                onPressed: _createPlaylist,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create playlist'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    '${_playlists.length} ${_playlists.length == 1 ? 'playlist' : 'playlists'}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: muted),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: 1 /
                    (1 + (10 + _textSlot(15) + _textSlot(12.5) + 2) / ((MediaQuery.sizeOf(context).width - 32 - 14) / 2)),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildPlaylistCard(theme, _playlists[i]),
                childCount: _playlists.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(ThemeData theme, Map<String, dynamic> playlist) {
    final count = List.from(playlist['games'] ?? const []).length;
    final isPublic = playlist['isPublic'] == true;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return GestureDetector(
      // Opaque so the whole card (cover images included) is tappable.
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlaylist(playlist),
      onLongPress: () => _playlistActions(playlist),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlaylistCover(playlist: playlist, size: constraints.maxWidth),
            const SizedBox(height: 10),
            Text(
              (playlist['name'] ?? 'Untitled').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Icon(isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 13, color: muted),
                const SizedBox(width: 4),
                Text('$count ${count == 1 ? 'game' : 'games'}', style: TextStyle(fontSize: 12.5, height: 1.3, color: muted)),
              ],
            ),
          ],
        ),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text(total == 1 ? 'game' : 'games', style: TextStyle(color: muted)),
              const Spacer(),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
              const SizedBox(width: 3),
              Text(avg > 0 ? avg.toStringAsFixed(1) : '–', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(' avg · $rated rated', style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
          const SizedBox(height: 10),
          // How the library splits across categories (colours match the chips).
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final s in LibraryStatus.libraryOrder)
                    if (counts[s]! > 0) Expanded(flex: counts[s]!, child: Container(color: s.color)),
                ],
              ),
            ),
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
      behavior: HitTestBehavior.opaque,
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
