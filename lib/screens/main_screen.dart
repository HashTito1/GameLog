import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
// Forum functionality disabled - keeping import commented
// import 'forum_screen.dart';
import '../services/update_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  // Tabs are built the first time they're opened and then kept alive, so
  // switching back is instant and doesn't reload their data.
  final Set<int> _openedTabs = {0};
  late AnimationController _animationController;
  String? _libraryPlaylistId;

  List<Widget> get _screens => [
    const HomeScreen(),
    const DiscoverScreen(),
    const SearchScreen(),
    // Forum disabled - keeping code but removing from navigation
    // const ForumScreen(),
    LibraryScreen(initialPlaylistId: _libraryPlaylistId),
    ProfileScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
  ];

  @override
  void initState() {
    super.initState();
    _animationController= AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    // Quietly check GitHub for new releases (launch, resume, every few hours).
    UpdateService.instance.startAutoChecks(() => context);
  }

  @override
  void dispose() {
    UpdateService.instance.stopAutoChecks();
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
    _onTabTapped(3); // Switch to library tab (now index 3, forum removed)
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      return;
    }
    
    // Clear library playlist ID when switching away from library
    if (_currentIndex == 3 && index != 3) { // Library is now index 3
      _libraryPlaylistId = null;
    }
    
    setState(() {
      _currentIndex = index;
      _openedTabs.add(index);
    });
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < _screens.length; i++)
              if (_openedTabs.contains(i))
                IgnorePointer(
                  ignoring: i != _currentIndex,
                  // The fade itself must keep ticking, so only the tab's own
                  // content is paused (TickerMode) while it's hidden.
                  child: AnimatedOpacity(
                    opacity: i == _currentIndex ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedSlide(
                      offset: i == _currentIndex ? Offset.zero : const Offset(0, 0.015),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: TickerMode(
                        enabled: i == _currentIndex,
                        child: _screens[i],
                      ),
                    ),
                  ),
                ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 22,
                color: states.contains(WidgetState.selected)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_filled), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
              NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
              NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}