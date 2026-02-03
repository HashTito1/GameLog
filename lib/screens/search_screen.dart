import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/content_filter_service.dart';
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
  List<Game> _popularGames = [];
  bool _isLoading = false;
  bool _showFilters = false;
  bool _isLoadingPopular = false;
  
  // Filter options
  String _selectedGenre = 'all';
  String _selectedPlatform = 'all';
  String _selectedOrdering = '-rating'; // Default to rating for better results
  RangeValues _metacriticRange = const RangeValues(0, 100);
  RangeValues _releasedYearRange = RangeValues(2020, DateTime.now().year.toDouble() + 2); // Focus on recent games including upcoming

  // Quick filter options
  final List<Map<String, String>> _quickFilters = [
    {'label': 'Popular', 'ordering': '-rating', 'icon': 'star'},
    {'label': 'Recent', 'ordering': '-released', 'icon': 'schedule'},
    {'label': 'Top Rated', 'ordering': '-metacritic', 'icon': 'trending_up'},
    {'label': 'Most Played', 'ordering': '-added', 'icon': 'people'},
  ];

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
    _loadPopularGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPopularGames() async {
    setState(() => _isLoadingPopular = true);
    try {
      final adultContentEnabled = await ContentFilterService.instance.isAdultContentEnabled();
      final games = await IGDBService.instance.getPopularGames(
        limit: 20,
        includeAdultContent: adultContentEnabled,
      );
      if (mounted) {
        setState(() {
          _popularGames = games;
          _isLoadingPopular = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPopular = false);
      }
    }
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

  void _applyQuickFilter(String ordering) {
    setState(() {
      _selectedOrdering = ordering;
      _showFilters = false; // Hide filters after applying quick filter
    });
    _searchGames(_searchController.text);
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
      child: Row(
        children: [
          Text(
            'Search Games',
            style: TextStyle(
              fontSize: 18, // Reduced from 20
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              color: theme.colorScheme.onSurface,
              size: 22, // Slightly smaller icon
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            padding: const EdgeInsets.all(8), // Reduced padding
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40), // Smaller button
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
            _buildQuickFilters(theme),
            
            // Scrollable content area
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Filters section (if shown)
                  if (_showFilters)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFilters(),
                      ),
                    ),
                  
                  // Main content
                  SliverFillRemaining(
                    child: _buildSearchContent(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters(ThemeData theme) {
    return Container(
      height: 45, // Reduced from 50
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Added bottom margin
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickFilters.length,
        itemBuilder: (context, index) {
          final filter = _quickFilters[index];
          final isSelected = _selectedOrdering == filter['ordering'];
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconData(filter['icon']!),
                    size: 14, // Reduced from 16
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filter['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11, // Reduced from 12
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _applyQuickFilter(filter['ordering']!);
                }
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary,
              side: BorderSide(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
            ),
          );
        },
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'schedule':
        return Icons.schedule;
      case 'trending_up':
        return Icons.trending_up;
      case 'people':
        return Icons.people;
      default:
        return Icons.games;
    }
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Reduced vertical margins
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced vertical padding
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: Text(
                  'Clear All',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Genre and Platform dropdowns
          Row(
            children: [
              Expanded(
                child: _buildDropdownFilter(
                  'Genre',
                  _selectedGenre,
                  _genreOptions,
                  (value) {
                    setState(() => _selectedGenre = value!);
                    _searchGames(_searchController.text);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFilter(
                  'Platform',
                  _selectedPlatform,
                  _platformOptions,
                  (value) {
                    setState(() => _selectedPlatform = value!);
                    _searchGames(_searchController.text);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Ordering dropdown
          _buildDropdownFilter(
            'Sort By',
            _selectedOrdering,
            _orderingOptions,
            (value) {
              setState(() => _selectedOrdering = value!);
              _searchGames(_searchController.text);
            },
          ),
          const SizedBox(height: 16),
          
          // Metacritic score range
          const Text(
            'Metacritic Score',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          RangeSlider(
            values: _metacriticRange,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: const Color(0xFF6366F1),
            inactiveColor: const Color(0xFF374151),
            labels: RangeLabels(
              _metacriticRange.start.round().toString(),
              _metacriticRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _metacriticRange = values);
            },
            onChangeEnd: (values) {
              _searchGames(_searchController.text);
            },
          ),
          
          // Release year range
          const Text(
            'Release Year',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          RangeSlider(
            values: _releasedYearRange,
            min: 1990,
            max: (DateTime.now().year + 2).toDouble(), // Dynamic max year (current year + 2 for upcoming games)
            divisions: (DateTime.now().year + 2 - 1990), // Dynamic division count
            activeColor: const Color(0xFF6366F1),
            inactiveColor: const Color(0xFF374151),
            labels: RangeLabels(
              _releasedYearRange.start.round().toString(),
              _releasedYearRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _releasedYearRange = values);
            },
            onChangeEnd: (values) {
              _searchGames(_searchController.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
    String label,
    String selectedValue,
    List<Map<String, String>> options,
    ValueChanged<String?> onChanged,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              onChanged: onChanged,
              dropdownColor: theme.colorScheme.surface,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
              isExpanded: true,
              items: options.map((option) => DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['label']!),
              )).toList(),
            ),
          ),
        ),
      ],
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // Search prompt section
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
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
                  'Search for your favorite games or explore popular titles below',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Popular games section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Popular Games',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 400, // Fixed height to prevent overflow
                child: _isLoadingPopular
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      )
                    : _popularGames.isEmpty
                        ? Center(
                            child: Text(
                              'No popular games available',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _popularGames.length,
                            itemBuilder: (context, index) {
                              return _buildGameItem(_popularGames[index], theme);
                            },
                          ),
              ),
            ],
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
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
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFFBBF24),
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