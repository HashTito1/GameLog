import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Theme constants and utilities for consistent theming across the app
class ThemeConstants {
  // Prevent instantiation
  ThemeConstants._();

  /// Get the current theme service instance
  static ThemeService get _themeService => ThemeService();

  /// Common colors that should remain consistent across themes
  static const Color starColor = Color(0xFFFBBF24); // Gold for star ratings
  static const Color favoriteColor = Color(0xFFEC4899); // Pink for favorites
  static const Color warningColor = Color(0xFFF59E0B); // Orange for warnings
  static const Color errorColor = Color(0xFFEF4444); // Red for errors
  static const Color successColor = Color(0xFF10B981); // Green for success

  /// Get theme-aware colors
  static Color get primaryColor => _themeService.currentThemeConfig.primaryColor;
  static Color get backgroundColor => _themeService.currentThemeConfig.backgroundColor;
  static Color get surfaceColor => _themeService.currentThemeConfig.surfaceColor;
  static Color get cardColor => _themeService.currentThemeConfig.cardColor;
  static Color get textColor => _themeService.currentThemeConfig.textColor;
  static Color get secondaryTextColor => _themeService.currentThemeConfig.secondaryTextColor;
  static Color get accentColor => _themeService.currentThemeConfig.accentColor;

  /// Common widget styles
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: cardColor.withValues(alpha: 0.3),
    ),
  );

  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
    color: primaryColor,
    borderRadius: BorderRadius.circular(12),
  );

  static TextStyle get headingStyle => TextStyle(
    color: textColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get bodyStyle => TextStyle(
    color: textColor,
    fontSize: 14,
  );

  static TextStyle get captionStyle => TextStyle(
    color: secondaryTextColor,
    fontSize: 12,
  );

  /// Common padding and margins
  static const EdgeInsets screenPadding = EdgeInsets.all(20);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets smallPadding = EdgeInsets.all(8);

  /// Common border radius
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  /// Helper method to get a themed CircularProgressIndicator
  static Widget getProgressIndicator({double? strokeWidth}) {
    return CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
      strokeWidth: strokeWidth ?? 4.0,
    );
  }

  /// Helper method to get a themed SnackBar
  static SnackBar getSnackBar(String message, {Color? backgroundColor}) {
    return SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  /// Helper method to get themed dialog decoration
  static BoxDecoration get dialogDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(largeBorderRadius),
  );
}