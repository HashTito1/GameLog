import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'forum_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  String? _libraryPlaylistId;

  List<Widget> get _screens => [
    const HomeScreen(),
    const DiscoverScreen(),
    const SearchScreen(),
    const ForumScreen(),
    LibraryScreen(initialPlaylistId: _libraryPlaylistId),
    ProfileScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    _onTabTapped(index);
  }

  void switchToLibraryPlaylist(String playlistId) {
    setState(() {
      _libraryPlaylistId = playlistId;
    });
    _onTabTapped(4); // Switch to library tab (now index 4)
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      return;
    }
    
    // Clear library playlist ID when switching away from library
    if (_currentIndex == 4 && index != 4) {
      _libraryPlaylistId = null;
    }
    
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    _animationController.forward().then((_) => _animationController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: _currentIndex == 0, // Only allow pop if on home tab
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _onTabTapped(0); // Navigate to home tab
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: Container(
          height: 58, // Reduced from 65
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10, // Reduced from 12
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_filled, 'Home', 0, theme),
                _buildNavItem(Icons.explore, 'Discover', 1, theme),
                _buildNavItem(Icons.search, 'Search', 2, theme),
                _buildNavItem(Icons.forum, 'Forum', 3, theme),
                _buildNavItem(Icons.bookmark, 'Library', 4, theme),
                _buildNavItem(Icons.person, 'Profile', 5, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ThemeData theme) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44, // Reduced from 50
        height: 44, // Reduced from 50
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isActive ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 4, // Reduced from 6
              offset: const Offset(0, 1), // Reduced from 2
            ),
          ] : null,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20, // Reduced from 22
        ),
      ),
    );
  }
}