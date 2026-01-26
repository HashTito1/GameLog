import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/rawg_service.dart';
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
  bool _showFilters = false;
  
  // Filter options
  String _selectedGenre = 'all';
  String _selectedPlatform = 'all';
  String _selectedOrdering = 'relevance';
  RangeValues _metacriticRange = const RangeValues(0, 100);
  RangeValues _releasedYearRange = const RangeValues(1990, 2024);

  final List<Map<String, String>> _genreOptions = [
    {'label': 'All Genres', 'value': 'all'},
    {'label': 'Action', 'value': 'action'},
    {'label': 'Adventure', 'value': 'adventure'},
    {'label': 'RPG', 'value': 'role-playing-games-rpg'},
    {'label': 'Strategy', 'value': 'strategy'},
    {'label': 'Indie', 'value': 'indie'},
    {'label': 'Shooter', 'value': 'shooter'},
    {'label': 'Puzzle', 'value': 'puzzle'},
    {'label': 'Racing', 'value': 'racing'},
    {'label': 'Sports', 'value': 'sports'},
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
    {'label': 'Relevance', 'value': 'relevance'},
    {'label': 'Name', 'value': 'name'},
    {'label': 'Release Date', 'value': '-released'},
    {'label': 'Rating', 'value': '-rating'},
    {'label': 'Metacritic Score', 'value': '-metacritic'},
    {'label': 'Added', 'value': '-added'},
  ];

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
      final games = await RAWGService.instance.searchGamesWithFilters(
        query: query,
        genre: _selectedGenre != 'all' ? _selectedGenre : null,
        platform: _selectedPlatform != 'all' ? _selectedPlatform : null,
        ordering: _selectedOrdering,
        metacriticMin: _metacriticRange.start.round(),
        metacriticMax: _metacriticRange.end.round(),
        releasedAfter: '${_releasedYearRange.start.round()}-01-01',
        releasedBefore: '${_releasedYearRange.end.round()}-12-31',
      );
      
      if (mounted) {
        setState(() {
          _searchResults = games;
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
      _selectedOrdering = 'relevance';
      _metacriticRange = const RangeValues(0, 100);
      _releasedYearRange = const RangeValues(1990, 2024);
    });
    _searchGames(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: const Text(
          'Search Games',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showFilters) _buildFilters(),
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search for games...',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Color(0xFF6366F1)),
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
            max: 2024,
            divisions: 34,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF374151),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              onChanged: onChanged,
              dropdownColor: const Color(0xFF374151),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
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

  Widget _buildSearchContent() {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for Games',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a game title to start searching',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No Games Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms or filters',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final game = _searchResults[index];
        return _buildGameItem(game);
      },
    );
  }

  Widget _buildGameItem(Game game) {
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
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: game.coverImage.isNotEmpty
                  ? Image.network(
                      game.coverImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.games, color: Colors.white, size: 24),
                        );
                      },
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.games, color: Colors.white, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.developer,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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
                          color: const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (game.releaseDate.isNotEmpty) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.releaseDate.split('-')[0], // Show year only
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
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