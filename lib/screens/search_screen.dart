import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
import '../services/theme_service.dart';
import 'category_games_screen.dart';
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
  // Filter options
  String _selectedGenre = 'all';
  String _selectedPlatform = 'all';
  String _selectedOrdering = '-rating'; // Default to rating for better results
  RangeValues _metacriticRange = const RangeValues(0, 100);
  RangeValues _releasedYearRange = RangeValues(1990, DateTime.now().year.toDouble() + 2); // Focus on recent games including upcoming

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
      final ratingFiltered = _metacriticRange.start > 0 || _metacriticRange.end < 100;
      final games = await IGDBService.instance.searchGames(
        query,
        limit: 40, // Get more results for better sorting
        genres: _selectedGenre != 'all' ? [_selectedGenre] : null,
        platforms: _selectedPlatform != 'all' ? [_selectedPlatform] : null,
        ordering: _selectedOrdering,
        // searchGames takes a 0-10 scale and converts to IGDB's 0-100.
        metacriticMin: ratingFiltered ? _metacriticRange.start / 10 : null,
        metacriticMax: ratingFiltered ? _metacriticRange.end / 10 : null,
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

      // Release-year filter: only applied once the user narrows the range, so
      // games with no release year aren't hidden by default.
      final fullYearRange = _releasedYearRange.start <= 1990 &&
          _releasedYearRange.end >= DateTime.now().year + 2;
      if (!fullYearRange) {
        filteredGames = filteredGames.where((game) {
          final year = int.tryParse(game.releaseDate);
          return year != null &&
              year >= _releasedYearRange.start.round() &&
              year <= _releasedYearRange.end.round();
        }).toList();
      }

      int year(Game g) => int.tryParse(g.releaseDate) ?? 0;
      // Sort by the user's choice. IGDB's text search ignores sort order, so
      // this is where the "Sort by" filter takes effect.
      switch (_selectedOrdering) {
        case '-released':
          filteredGames.sort((a, b) => year(b).compareTo(year(a)));
          break;
        case 'name':
          filteredGames.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case '-name':
          filteredGames.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
          break;
        case '-added':
          filteredGames.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
          break;
        case '-metacritic':
          filteredGames.sort((a, b) => b.averageRating.compareTo(a.averageRating));
          break;
        default:
          // Best match: rating, then recency, then number of reviews.
          filteredGames.sort((a, b) {
            final ratingDiff = b.averageRating.compareTo(a.averageRating);
            if (ratingDiff != 0) return ratingDiff;
            final yearDiff = year(b).compareTo(year(a));
            if (yearDiff != 0) return yearDiff;
            return b.totalReviews.compareTo(a.totalReviews);
          });
      }
      
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
      _releasedYearRange = RangeValues(1990, DateTime.now().year.toDouble() + 2);
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

  // Shortcuts shown before the user types; each opens an existing category list.
  static const _browseCategories = [
    ('Trending', 'trending', Icons.local_fire_department),
    ('Popular', 'popular', Icons.trending_up),
    ('Best of last year', 'goty', Icons.emoji_events),
    ('RPG', 'rpg', Icons.auto_stories),
    ('Shooter', 'shooter', Icons.sports_esports),
    ('Adventure', 'adventure', Icons.explore),
    ('Strategy', 'strategy', Icons.psychology),
    ('Indie', 'indie', Icons.palette),
  ];

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Browse',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Or type a game name above',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: [
            for (final (label, type, icon) in _browseCategories)
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryGamesScreen(
                        categoryTitle: type == 'goty' ? 'Best of ${DateTime.now().year - 1}' : label,
                        categoryType: type,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(icon, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
      onTap: () {
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
                    game.subtitle,
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
    {'label': 'PC', 'value': 'PC (Microsoft Windows)'},
    {'label': 'PlayStation 5', 'value': 'PlayStation 5'},
    {'label': 'PlayStation 4', 'value': 'PlayStation 4'},
    {'label': 'Xbox Series X/S', 'value': 'Xbox Series X|S'},
    {'label': 'Xbox One', 'value': 'Xbox One'},
    {'label': 'Nintendo Switch', 'value': 'Nintendo Switch'},
    {'label': 'iOS', 'value': 'iOS'},
    {'label': 'Android', 'value': 'Android'},
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
      _releasedYearRange = RangeValues(1990, DateTime.now().year.toDouble() + 2);
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