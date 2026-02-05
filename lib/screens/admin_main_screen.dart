import 'package:flutter/material.dart';
import 'dart:async';
import '../services/admin_service.dart';
import '../services/firebase_auth_service.dart';
import 'admin_user_management_screen.dart';
import 'admin_forum_moderation_screen.dart';
import 'admin_content_moderation_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
  }

  Future<void> _checkSuperAdminStatus() async {
    final isSuperAdmin = await AdminService.instance.isCurrentUserSuperAdmin();
    if (mounted) {
      setState(() {
        _isSuperAdmin = isSuperAdmin;
      });
    }
  }

  List<Widget> get _screens => [
    const AdminDashboardTab(),
    // Forum moderation disabled - keeping code but removing from navigation
    // const AdminForumModerationScreen(),
    const AdminContentModerationScreen(),
    if (_isSuperAdmin) const AdminUserManagementScreen(),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    // Forum tab removed
    // const BottomNavigationBarItem(
    //   icon: Icon(Icons.forum),
    //   label: 'Forum',
    // ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.content_paste),
      label: 'Content',
    ),
    if (_isSuperAdmin)
      const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'Admins',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        items: _navItems,
      ),
    );
  }
}

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  Map<String, dynamic>? _stats;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Refresh dashboard every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadDashboard();
      }
    });
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final isSuperAdmin = await AdminService.instance.isCurrentUserSuperAdmin();
      final stats = await AdminService.instance.getModerationStats();
      
      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuperAdmin;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuthService().currentUser;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            tooltip: 'Refresh Dashboard',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuthService().logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(theme, currentUser),
                  const SizedBox(height: 16),
                  if (_stats != null) _buildStatsCards(theme),
                  const SizedBox(height: 16),
                  _buildQuickActions(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, dynamic currentUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSuperAdmin ? Icons.admin_panel_settings : Icons.security,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSuperAdmin ? 'Welcome, Super Admin!' : 'Welcome, Admin!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      currentUser?.username ?? 'Administrator',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isSuperAdmin 
                ? 'You have full super admin access to manage the GameLogs community and other administrators.'
                : 'You have admin access to moderate the GameLogs community.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.white.withValues(alpha: 0.7),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Auto-refreshes every 30 seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Community Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.update,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Last updated: ${DateTime.now().toString().substring(11, 19)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6, // Increased from 1.5 to give more height
          children: [
            _buildStatCard(
              theme,
              'Total Users',
              _stats!['totalUsers'].toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildStatCard(
              theme,
              'Forum Posts',
              _stats!['totalForumPosts'].toString(),
              Icons.forum,
              Colors.green,
            ),
            _buildStatCard(
              theme,
              'Game Ratings',
              _stats!['totalGameRatings'].toString(),
              Icons.star,
              Colors.orange,
            ),
            _buildStatCard(
              theme,
              'Banned Users',
              _stats!['totalBannedUsers'].toString(),
              Icons.block,
              Colors.red,
            ),
            if (_isSuperAdmin)
              _buildStatCard(
                theme,
                'Total Admins',
                _stats!['totalAdmins'].toString(),
                Icons.admin_panel_settings,
                Colors.purple,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16 to 12
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28, // Reduced from 32 to 28
            color: color,
          ),
          const SizedBox(height: 6), // Reduced from 8 to 6
          Text(
            value,
            style: TextStyle(
              fontSize: 22, // Reduced from 24 to 22
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2), // Reduced from default to 2
          Text(
            title,
            style: TextStyle(
              fontSize: 11, // Reduced from 12 to 11
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // Allow text to wrap if needed
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildActionTile(
                theme,
                'Content Moderation',
                'Review ratings, comments, and user reports',
                Icons.content_paste,
                () {
                  // Switch to content tab
                  if (mounted) {
                    final parentState = context.findAncestorStateOfType<_AdminMainScreenState>();
                    parentState?.setState(() {
                      parentState._currentIndex = 1; // Content is now index 1 (forum removed)
                    });
                  }
                },
              ),
              if (_isSuperAdmin) ...[
                const Divider(),
                _buildActionTile(
                  theme,
                  'Admin Management',
                  'Add or remove administrator privileges',
                  Icons.admin_panel_settings,
                  () {
                    // Switch to admins tab
                    if (mounted) {
                      final parentState = context.findAncestorStateOfType<_AdminMainScreenState>();
                      parentState?.setState(() {
                        parentState._currentIndex = 2; // Admins is now index 2
                      });
                    }
                  },
                ),
              ],
              const Divider(),
              _buildActionTile(
                theme,
                'System Logs',
                'View admin actions and system events',
                Icons.history,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('System logs feature coming soon!')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(ThemeData theme, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}