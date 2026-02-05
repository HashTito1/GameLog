import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_auth_service.dart';
import 'services/theme_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first (with error handling for duplicate initialization)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized, continue
    if (kDebugMode) {
            // Error handled
    }
  }
  
  // Initialize services
  await FirebaseAuthService().initialize();
  await ThemeService().initialize();
  
  runApp(const GameLogApp());
}

class GameLogApp extends StatelessWidget {
  const GameLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();
        final themeData = themeService.getThemeData();
        
        return MaterialApp(
          title: 'GameLog',
          debugShowCheckedModeBanner: false,
          theme: themeData.copyWith(
            textTheme: GoogleFonts.interTextTheme(
              themeData.textTheme.apply(
                bodyColor: themeService.currentThemeConfig.textColor,
                displayColor: themeService.currentThemeConfig.textColor,
              ),
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isFirstTime = true;
  bool _isCheckingFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    
    setState(() {
      _isFirstTime = !hasSeenWelcome;
      _isCheckingFirstTime = false;
    });
  }

  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    setState(() {
      _isFirstTime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingFirstTime) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ThemeService().currentThemeConfig.primaryColor),
          ),
        ),
      );
    }

    if (_isFirstTime) {
      return WelcomeScreen(onWelcomeComplete: _markWelcomeSeen);
    }

    return AnimatedBuilder(
      animation: FirebaseAuthService(),
      builder: (context, child) {
        final authService = FirebaseAuthService();
        
        if (authService.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ThemeService().currentThemeConfig.primaryColor),
              ),
            ),
          );
        }
        
        if (authService.isLoggedIn) {
          return const MainScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}


