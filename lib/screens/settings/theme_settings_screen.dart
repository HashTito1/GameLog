import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();
        final currentConfig = themeService.currentThemeConfig;
        
        return Scaffold(
          backgroundColor: currentConfig.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Themes',
              style: TextStyle(
                color: currentConfig.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: currentConfig.surfaceColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: currentConfig.textColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          currentConfig.primaryColor.withValues(alpha: 0.2),
                          currentConfig.accentColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: currentConfig.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: currentConfig.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.palette,
                            color: currentConfig.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personalize Your Experience',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: currentConfig.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose from our collection of beautiful themes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: currentConfig.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Available Themes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: currentConfig.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9, // Reduced to give more height for text
                    ),
                    itemCount: ThemeService.themes.length,
                    itemBuilder: (context, index) {
                      final themeKey = ThemeService.themes.keys.elementAt(index);
                      final themeConfig = ThemeService.themes[themeKey]!;
                      final isSelected = themeService.currentTheme == themeKey;
                      
                      return _buildThemeCard(
                        themeKey,
                        themeConfig,
                        isSelected,
                        themeService,
                        currentConfig,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: currentConfig.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentConfig.cardColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: currentConfig.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Theme changes apply instantly across the entire app. Your preference is automatically saved.',
                            style: TextStyle(
                              fontSize: 14,
                              color: currentConfig.secondaryTextColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeCard(
    String themeKey,
    ThemeConfig themeConfig,
    bool isSelected,
    ThemeService themeService,
    ThemeConfig currentConfig,
  ) {
    return GestureDetector(
      onTap: () async {
        await themeService.setTheme(themeKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Theme changed to ${themeConfig.name}'),
              backgroundColor: themeConfig.primaryColor,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12), // Reduced from 16
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeConfig.backgroundColor,
              themeConfig.surfaceColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? themeConfig.primaryColor
                : themeConfig.cardColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themeConfig.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Icon section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeConfig.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                themeConfig.icon,
                color: themeConfig.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            
            // Text section - using Expanded to take available space
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    themeConfig.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: themeConfig.textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      themeConfig.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: themeConfig.secondaryTextColor,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3, // Increased from 2 to allow more text
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status section
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeConfig.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeConfig.cardColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tap to apply',
                  style: TextStyle(
                    color: themeConfig.secondaryTextColor,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



