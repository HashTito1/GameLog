import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  String _currentTheme = 'midnight';
  String get currentTheme => _currentTheme;

  // Available themes
  static const Map<String, ThemeConfig> themes = {
    'midnight': ThemeConfig(
      name: 'Midnight',
      description: 'Deep dark theme with blue accents',
      primaryColor: Color(0xFF6366F1),
      backgroundColor: Color(0xFF0F172A),
      surfaceColor: Color(0xFF1F2937),
      cardColor: Color(0xFF374151),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF9CA3AF),
      accentColor: Color(0xFF8B5CF6),
      icon: Icons.nightlight_round,
    ),
    'ocean': ThemeConfig(
      name: 'Ocean',
      description: 'Cool blue tones from the deep sea',
      primaryColor: Color(0xFF0EA5E9),
      backgroundColor: Color(0xFF0C1B2E),
      surfaceColor: Color(0xFF1E3A5F),
      cardColor: Color(0xFF2D5A87),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF94A3B8),
      accentColor: Color(0xFF06B6D4),
      icon: Icons.waves,
    ),
    'forest': ThemeConfig(
      name: 'Forest',
      description: 'Natural green for calm vibes',
      primaryColor: Color(0xFF10B981),
      backgroundColor: Color(0xFF0F1B0F),
      surfaceColor: Color(0xFF1F2F1F),
      cardColor: Color(0xFF2F4F2F),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF94A3B8),
      accentColor: Color(0xFF34D399),
      icon: Icons.forest,
    ),
    'sunset': ThemeConfig(
      name: 'Sunset',
      description: 'Warm orange like a sunset',
      primaryColor: Color(0xFFF59E0B),
      backgroundColor: Color(0xFF1F1611),
      surfaceColor: Color(0xFF2F2419),
      cardColor: Color(0xFF4F3F2F),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF94A3B8),
      accentColor: Color(0xFFEF4444),
      icon: Icons.wb_sunny,
    ),
    'purple': ThemeConfig(
      name: 'Purple Rain',
      description: 'Rich purple with elegance',
      primaryColor: Color(0xFF8B5CF6),
      backgroundColor: Color(0xFF1A0F2E),
      surfaceColor: Color(0xFF2D1B4E),
      cardColor: Color(0xFF4C2F7C),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF94A3B8),
      accentColor: Color(0xFFA855F7),
      icon: Icons.auto_awesome,
    ),
    'cyberpunk': ThemeConfig(
      name: 'Cyberpunk',
      description: 'Neon pink and cyan vibes',
      primaryColor: Color(0xFFEC4899),
      backgroundColor: Color(0xFF0F0F0F),
      surfaceColor: Color(0xFF1F1F1F),
      cardColor: Color(0xFF2F2F2F),
      textColor: Colors.white,
      secondaryTextColor: Color(0xFF94A3B8),
      accentColor: Color(0xFF06D6A0),
      icon: Icons.electric_bolt,
    ),
    'light': ThemeConfig(
      name: 'Light Mode',
      description: 'Clean and bright interface',
      primaryColor: Color(0xFF6366F1),
      backgroundColor: Color(0xFFF8FAFC),
      surfaceColor: Colors.white,
      cardColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF1F2937),
      secondaryTextColor: Color(0xFF6B7280),
      accentColor: Color(0xFF8B5CF6),
      icon: Icons.light_mode,
    ),
  };

  ThemeConfig get currentThemeConfig => themes[_currentTheme] ?? themes['midnight']!;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString('selected_theme') ?? 'midnight';
    notifyListeners();
  }

  Future<void> setTheme(String themeKey) async {
    if (themes.containsKey(themeKey)) {
      _currentTheme = themeKey;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_theme', themeKey);
      notifyListeners();
    }
  }

  ThemeData getThemeData() {
    final config = currentThemeConfig;
    final isLight = _currentTheme == 'light';
    
    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primaryColor,
        brightness: isLight ? Brightness.light : Brightness.dark,
        primary: config.primaryColor,
        secondary: config.accentColor,
        surface: config.surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: config.textColor,
        outline: config.secondaryTextColor,
        surfaceContainerHighest: config.cardColor,
      ),
      scaffoldBackgroundColor: config.backgroundColor,
      cardColor: config.cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: config.surfaceColor,
        foregroundColor: config.textColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: config.textColor),
        actionsIconTheme: IconThemeData(color: config.textColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: config.primaryColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: config.primaryColor,
          side: BorderSide(color: config.primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: config.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.cardColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.cardColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: config.secondaryTextColor),
        hintStyle: TextStyle(color: config.secondaryTextColor),
      ),
      cardTheme: CardThemeData(
        color: config.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: config.cardColor.withValues(alpha: 0.3)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: config.surfaceColor,
        titleTextStyle: TextStyle(
          color: config.textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: config.secondaryTextColor,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: config.primaryColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.primaryColor;
          }
          return config.secondaryTextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.primaryColor.withValues(alpha: 0.3);
          }
          return config.cardColor;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: config.primaryColor,
        linearTrackColor: config.cardColor,
        circularTrackColor: config.cardColor,
      ),
      iconTheme: IconThemeData(
        color: config.textColor,
      ),
      primaryIconTheme: IconThemeData(
        color: config.primaryColor,
      ),
      dividerTheme: DividerThemeData(
        color: config.cardColor,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: config.surfaceColor,
        selectedItemColor: config.primaryColor,
        unselectedItemColor: config.secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: config.primaryColor,
        unselectedLabelColor: config.secondaryTextColor,
        indicatorColor: config.primaryColor,
        dividerColor: config.cardColor,
      ),
      listTileTheme: ListTileThemeData(
        textColor: config.textColor,
        iconColor: config.textColor,
        tileColor: config.surfaceColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: config.cardColor,
        labelStyle: TextStyle(color: config.textColor),
        side: BorderSide(color: config.cardColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Helper methods for common theme colors
  Color get starColor => const Color(0xFFFBBF24); // Keep gold for stars
  Color get favoriteColor => const Color(0xFFEC4899); // Keep pink for favorites
  Color get successColor => const Color(0xFF10B981); // Green for success
  Color get warningColor => const Color(0xFFF59E0B); // Orange for warnings
  Color get errorColor => const Color(0xFFEF4444); // Red for errors
}

class ThemeConfig {
  final String name;
  final String description;
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final IconData icon;

  const ThemeConfig({
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.icon,
  });
}