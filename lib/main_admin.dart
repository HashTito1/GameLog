import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_auth_service.dart';
import 'services/admin_service.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/admin_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase might already be initialized, which is fine
    debugPrint('Firebase initialization: $e');
  }

  // Initialize super admin system
  await AdminService.initializeSuperAdmin();
  
  runApp(const GameLogAdminApp());
}

class GameLogAdminApp extends StatelessWidget {
  const GameLogAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameLogs Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Admin theme color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AdminAuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminAuthWrapper extends StatefulWidget {
  const AdminAuthWrapper({super.key});

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await FirebaseAuthService.instance.initialize();
    
    // Listen to auth changes
    FirebaseAuthService.instance.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {
        _isLoggedIn = FirebaseAuthService.instance.isLoggedIn;
        _isLoading = FirebaseAuthService.instance.isLoading;
      });
    }
  }

  @override
  void dispose() {
    FirebaseAuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      return const AdminAccessChecker();
    } else {
      return const WelcomeScreen();
    }
  }
}

class AdminAccessChecker extends StatefulWidget {
  const AdminAccessChecker({super.key});

  @override
  State<AdminAccessChecker> createState() => _AdminAccessCheckerState();
}

class _AdminAccessCheckerState extends State<AdminAccessChecker> {
  bool _isLoading = true;
  bool _hasAdminAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      // First try to initialize super admin if needed
      await AdminService.instance.initializeSuperAdminIfNeeded();
      
      final isAdmin = await AdminService.instance.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _hasAdminAccess = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAdminAccess = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAdminAccess) {
      return _buildAccessDenied(context);
    }

    return const AdminMainScreen();
  }

  Widget _buildAccessDenied(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuthService().currentUser;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Admin Access Required',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This is the GameLogs Admin dashboard. Only authorized administrators can access this application.',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current User:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser?.username ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuthService().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkAdminAccess,
                child: const Text('Retry Access Check'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}