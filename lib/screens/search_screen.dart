import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
import '../services/theme_service.dart';
import 'game_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Game> _searchResults = [];
  bool _isLoading = false;
  List<Game> _recentGames = [];
  
  // Filter options
  String _selectedGenre = 'all';
  String _selectedPlatform = 'all';
  String _selectedOrdering = '-rating'; // Default to rating for better results
  RangeValues _metacriticRange = const RangeValues(0, 100);
  RangeValues _releasedYearRange = RangeValues(2020, DateTime.now().year.toDouble() + 2); // Focus on recent games including upcoming

  @override
  void initState() {
    super.initState();
    _loadRecentGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList('recent_viewed_games') ?? [];
    setState(() {
      _recentGames = gamesJson.map((json) {
        try {
          final parts = json.split('|||');
          if (parts.length >= 5) {
            return Game(
              id: parts[0],
              title: parts[1],
              coverImage: parts[2],
              developer: parts[3],
              releaseDate: parts[4],
              averageRating: parts.length > 5 ? double.tryParse(parts[5]) ?? 0.0 : 0.0,
              publisher: '',
              platforms: [],
              genres: [],
              description: '',
              totalReviews: 0,
            );
          }
        } catch (e) {
          // Skip invalid entries
        }
        return null;
      }).whereType<Game>().toList();
    });
  }

  Future<void> _saveRecentGame(Game game) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Create a simple string representation
    final gameString = '${game.id}|||${game.title}|||${game.coverImage}|||${game.developer}|||${game.releaseDate}|||${game.averageRating}';
    
    var gamesJson = prefs.getStringList('recent_viewed_games') ?? [];
    
    // Remove if exists
    gamesJson.removeWhere((g) => g.startsWith('${game.id}|||'));
    
    // Add to beginning
    gamesJson.insert(0, gameString);
    
    // Keep only 10
    if (gamesJson.length > 10) {
      gamesJson = gamesJson.take(10).toList();
    }
    
    await prefs.setStringList('recent_viewed_games', gamesJson);
    await _loadRecentGames();
  }

  Future<void> _clearRecentGames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_viewed_games');
    setState(() {
      _recentGames = [];
    });
  }

  Future<void> _removeRecentGame(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    var gamesJson = prefs.getStringList('recent_viewed_games') ?? [];
    gamesJson.removeWhere((g) => g.startsWith('$gameId|||'));
    await prefs.setStringList('recent_viewed_games', gamesJson);
    await _loadRecentGames();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchGames(query);
    });
  }

  Future<void> _searchGames(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get adult content preference
      final adultContentEnabled = await ContentFilterService.instance.isAdultContentEnabled();
      
      // Enhanced search with better ordering for popular/recent results
      final games = await IGDBService.instance.searchGames(
        query,
        limit: 40, // Get more results for better sorting
        genres: _selectedGenre != 'all' ? [_selectedGenre] : null,
        ordering: _selectedOrdering,
      );
      
      // Apply content filtering
      List<Game> filteredGames = games;
      if (!adultContentEnabled) {
        filteredGames = games.where((game) {
          // Basic content filtering based on title and description
          final title = game.title.toLowerCase();
          final description = game.description.toLowerCase();
          
          const adultKeywords = [
            'adult', 'erotic', 'nsfw', 'mature', 'sexual', 'nude', 'xxx', '18+', 'hentai'
          ];
          
          return !adultKeywords.any((keyword) => 
            title.contains(keyword) || description.contains(keyword)
          );
        }).toList();
      }

      // Enhanced result prioritization: popular and recent games first
      filteredGames.sort((a, b) {
        // First priority: rating (popular games)
        final ratingDiff = b.averageRating.compareTo(a.averageRating);
        if (ratingDiff != 0) return ratingDiff;
        
        // Second priority: release year (recent games)
        final yearA = int.tryParse(a.releaseDate) ?? 0;
        final yearB = int.tryParse(b.releaseDate) ?? 0;
        final yearDiff = yearB.compareTo(yearA);
        if (yearDiff != 0) return yearDiff;
        
        // Third priority: review count (more reviewed = more popular)
        return b.totalReviews.compareTo(a.totalReviews);
      });
      
      if (mounted) {
        setState(() {
          _searchResults = filteredGames.take(20).toList(); // Limit final results
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedGenre = 'all';
      _selectedPlatform = 'all';
      _selectedOrdering = '-rating';
      _metacriticRange = const RangeValues(0, 100);
      _releasedYearRange = RangeValues(2020, DateTime.now().year.toDouble() + 2);
    });
    _searchGames(_searchController.text);
  }



  Future<void> _openAdvancedSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AdvancedSearchScreen(
          initialGenre: _selectedGenre,
          initialPlatform: _selectedPlatform,
          initialOrdering: _selectedOrdering,
          initialMetacriticRange: _metacriticRange,
          initialReleasedYearRange: _releasedYearRange,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedGenre = result['genre'] ?? _selectedGenre;
        _selectedPlatform = result['platform'] ?? _selectedPlatform;
        _selectedOrdering = result['ordering'] ?? _selectedOrdering;
        _metacriticRange = result['metacriticRange'] ?? _metacriticRange;
        _releasedYearRange = result['releasedYearRange'] ?? _releasedYearRange;
      });
      _searchGames(_searchController.text);
    }
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Search Games',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
            onPressed: () {
              _openAdvancedSearch(context);
            },
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed header section
            _buildHeader(theme),
            _buildSearchBar(theme),
            
            // Scrollable content area
            Expanded(
              child: _buildSearchContent(theme),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search for games...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }



  Widget _buildSearchContent(ThemeData theme) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState(theme);
    }

    return _buildSearchResults(theme);
  }

  Widget _buildEmptyState(ThemeData theme) {
    if (_recentGames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Discover Amazing Games',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for your favorite games using the search bar above',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show recently viewed games
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently Viewed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: _clearRecentGames,
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentGames.map((game) => _buildRecentGameItem(game, theme)),
      ],
    );
  }

  Widget _buildRecentGameItem(Game game, ThemeData theme) {
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: game.coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.developer,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (game.averageRating > 0) ...[
                        Icon(
                          Icons.star,
                          size: 16,
                          color: ThemeService().starColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (game.releaseDate.isNotEmpty) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.releaseDate.split('-')[0],
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () => _removeRecentGame(game.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Games Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms or filters',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
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

  Widget _buildSearchResults(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), // Added bottom padding
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final game = _searchResults[index];
        return _buildGameItem(game, theme);
      },
    );
  }

  Widget _buildGameItem(Game game, ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        // Save to recent games
        await _saveRecentGame(game);
        
        // Navigate to game detail screen
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: game.coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.games, color: theme.colorScheme.onSurface, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.developer,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (game.averageRating > 0) ...[
                        Icon(
                          Icons.star,
                          size: 16,
                          color: ThemeService().starColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (game.releaseDate.isNotEmpty) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.releaseDate.split('-')[0], // Show year only
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedSearchScreen extends StatefulWidget {
  final String initialGenre;
  final String initialPlatform;
  final String initialOrdering;
  final RangeValues initialMetacriticRange;
  final RangeValues initialReleasedYearRange;

  const AdvancedSearchScreen({
    super.key,
    required this.initialGenre,
    required this.initialPlatform,
    required this.initialOrdering,
    required this.initialMetacriticRange,
    required this.initialReleasedYearRange,
  });

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  late String _selectedGenre;
  late String _selectedPlatform;
  late String _selectedOrdering;
  late RangeValues _metacriticRange;
  late RangeValues _releasedYearRange;

  final List<Map<String, String>> _genreOptions = [
    {'label': 'All Genres', 'value': 'all'},
    {'label': 'Adventure', 'value': 'Adventure'},
    {'label': 'Fighting', 'value': 'Fighting'},
    {'label': 'Indie', 'value': 'Indie'},
    {'label': 'Platform', 'value': 'Platform'},
    {'label': 'Puzzle', 'value': 'Puzzle'},
    {'label': 'Racing', 'value': 'Racing'},
    {'label': 'RPG', 'value': 'Role-playing (RPG)'},
    {'label': 'Shooter', 'value': 'Shooter'},
    {'label': 'Sport', 'value': 'Sport'},
    {'label': 'Strategy', 'value': 'Strategy'},
    {'label': 'Simulator', 'value': 'Simulator'},
  ];

  final List<Map<String, String>> _platformOptions = [
    {'label': 'All Platforms', 'value': 'all'},
    {'label': 'PC', 'value': '4'},
    {'label': 'PlayStation 5', 'value': '187'},
    {'label': 'PlayStation 4', 'value': '18'},
    {'label': 'Xbox Series X/S', 'value': '186'},
    {'label': 'Xbox One', 'value': '1'},
    {'label': 'Nintendo Switch', 'value': '7'},
    {'label': 'iOS', 'value': '3'},
    {'label': 'Android', 'value': '21'},
  ];

  final List<Map<String, String>> _orderingOptions = [
    {'label': 'Best Match', 'value': '-rating'},
    {'label': 'Most Popular', 'value': '-added'},
    {'label': 'Newest First', 'value': '-released'},
    {'label': 'Highest Rated', 'value': '-metacritic'},
    {'label': 'Name A-Z', 'value': 'name'},
    {'label': 'Name Z-A', 'value': '-name'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialGenre;
    _selectedPlatform = widget.initialPlatform;
    _selectedOrdering = widget.initialOrdering;
    _metacriticRange = widget.initialMetacriticRange;
    _releasedYearRange = widget.initialReleasedYearRange;
  }

  void _clearFilters() {
    setState(() {
      _selectedGenre = 'all';
      _selectedPlatform = 'all';
      _selectedOrdering = '-rating';
      _metacriticRange = const RangeValues(0, 100);
      _releasedYearRange = RangeValues(2020, DateTime.now().year.toDouble() + 2);
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop({
      'genre': _selectedGenre,
      'platform': _selectedPlatform,
      'ordering': _selectedOrdering,
      'metacriticRange': _metacriticRange,
      'releasedYearRange': _releasedYearRange,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Advanced Search',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear All',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'Genre',
                    _buildGenreSelector(theme),
                    theme,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Platform',
                    _buildPlatformSelector(theme),
                    theme,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Sort By',
                    _buildOrderingSelector(theme),
                    theme,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Metacritic Score',
                    _buildMetacriticSlider(theme),
                    theme,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Release Year',
                    _buildReleaseYearSlider(theme),
                    theme,
                  ),
                ],
              ),
            ),
          ),
          _buildBottomActions(theme),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildGenreSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: _genreOptions.map((genre) {
          final isSelected = _selectedGenre == genre['value'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGenre = genre['value']!;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    genre['label']!,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlatformSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: _platformOptions.map((platform) {
          final isSelected = _selectedPlatform == platform['value'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlatform = platform['value']!;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    platform['label']!,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderingSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: _orderingOptions.map((ordering) {
          final isSelected = _selectedOrdering == ordering['value'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedOrdering = ordering['value']!;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ordering['label']!,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetacriticSlider(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${_metacriticRange.start.round()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                'Max: ${_metacriticRange.end.round()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _metacriticRange,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.outline.withValues(alpha: 0.3),
            labels: RangeLabels(
              _metacriticRange.start.round().toString(),
              _metacriticRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _metacriticRange = values);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseYearSlider(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'From: ${_releasedYearRange.start.round()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                'To: ${_releasedYearRange.end.round()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _releasedYearRange,
            min: 1990,
            max: (DateTime.now().year + 2).toDouble(),
            divisions: (DateTime.now().year + 2 - 1990),
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.outline.withValues(alpha: 0.3),
            labels: RangeLabels(
              _releasedYearRange.start.round().toString(),
              _releasedYearRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _releasedYearRange = values);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.outline),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}