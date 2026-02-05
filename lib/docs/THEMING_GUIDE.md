# Theming Guide for GameLog App

This guide ensures consistent theming across all components of the GameLog app.

## Theme Service Usage

### Import the Theme Service
```dart
import '../services/theme_service.dart';
```

### Getting Theme Colors

#### Primary Theme Colors
```dart
// Use these for main UI elements
ThemeService().currentThemeConfig.primaryColor     // Main brand color
ThemeService().currentThemeConfig.backgroundColor  // Screen background
ThemeService().currentThemeConfig.surfaceColor     // Card/surface background
ThemeService().currentThemeConfig.cardColor        // Card borders/accents
ThemeService().currentThemeConfig.textColor        // Primary text
ThemeService().currentThemeConfig.secondaryTextColor // Secondary text
ThemeService().currentThemeConfig.accentColor      // Accent elements
```

#### Special Colors (Consistent Across Themes)
```dart
ThemeService().starColor      // Gold for star ratings (0xFFFBBF24)
ThemeService().favoriteColor  // Pink for favorites (0xFFEC4899)
ThemeService().successColor   // Green for success (0xFF10B981)
ThemeService().warningColor   // Orange for warnings (0xFFF59E0B)
ThemeService().errorColor     // Red for errors (0xFFEF4444)
```

### Using Flutter's Theme System

#### Accessing Theme in Build Method
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  
  return Container(
    color: theme.scaffoldBackgroundColor,
    child: Text(
      'Hello',
      style: TextStyle(color: theme.colorScheme.onSurface),
    ),
  );
}
```

#### Common Theme Properties
```dart
theme.colorScheme.primary           // Primary color
theme.colorScheme.surface           // Surface color
theme.colorScheme.onSurface         // Text on surface
theme.colorScheme.outline           // Border/outline color
theme.scaffoldBackgroundColor       // Background color
theme.cardColor                     // Card color
```

## DO NOT Use Hardcoded Colors

### ❌ Wrong - Hardcoded Colors
```dart
Container(
  color: Color(0xFF6366F1),  // DON'T DO THIS
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.white),  // DON'T DO THIS
  ),
)
```

### ✅ Correct - Theme Colors
```dart
Container(
  color: theme.colorScheme.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: theme.colorScheme.onPrimary),
  ),
)
```

## Common UI Elements

### Progress Indicators
```dart
// Use theme-aware progress indicator
CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
)
```

### Star Ratings
```dart
Icon(
  Icons.star,
  color: ThemeService().starColor,  // Always use this for stars
  size: 16,
)
```

### Favorite Icons
```dart
Icon(
  Icons.favorite,
  color: ThemeService().favoriteColor,  // Always use this for favorites
  size: 20,
)
```

### Buttons
```dart
// ElevatedButton automatically uses theme colors
ElevatedButton(
  onPressed: () {},
  child: Text('Button'),
)

// For custom buttons
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.primary,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    'Custom Button',
    style: TextStyle(color: theme.colorScheme.onPrimary),
  ),
)
```

### Cards
```dart
Card(
  // Card automatically uses theme colors
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Card content',
      style: TextStyle(color: theme.colorScheme.onSurface),
    ),
  ),
)
```

### Dialogs
```dart
AlertDialog(
  // Dialog automatically uses theme colors
  title: Text('Title'),
  content: Text('Content'),
  actions: [
    TextButton(
      onPressed: () {},
      child: Text('OK'),  // Automatically uses primary color
    ),
  ],
)
```

### SnackBars
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Message'),
    backgroundColor: theme.colorScheme.primary,  // Use theme color
  ),
);
```

## Theme-Aware Widgets

### Text Styles
```dart
Text(
  'Heading',
  style: theme.textTheme.headlineMedium?.copyWith(
    color: theme.colorScheme.onSurface,
  ),
)

Text(
  'Body text',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface,
  ),
)

Text(
  'Caption',
  style: theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.outline,
  ),
)
```

### Input Fields
```dart
TextField(
  // TextField automatically uses theme colors from inputDecorationTheme
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint',
  ),
)
```

### Switches
```dart
Switch(
  value: value,
  onChanged: onChanged,
  // Switch automatically uses theme colors from switchTheme
)
```

## Checklist for Theme Compliance

- [ ] No hardcoded Color() values
- [ ] Use theme.colorScheme.* for colors
- [ ] Use ThemeService().starColor for star ratings
- [ ] Use ThemeService().favoriteColor for favorite icons
- [ ] Use ThemeService().warningColor for warnings
- [ ] Use ThemeService().errorColor for errors
- [ ] Use ThemeService().successColor for success states
- [ ] Progress indicators use theme.colorScheme.primary
- [ ] All text uses theme-aware colors
- [ ] All containers/decorations use theme colors
- [ ] Import ThemeService where needed

## Testing Themes

To ensure your UI works with all themes:

1. Go to Settings > Theme Settings
2. Test your screen with each available theme:
   - Midnight (default)
   - Ocean
   - Forest
   - Sunset
   - Purple Rain
   - Cyberpunk
   - Light Mode

Make sure all elements are visible and properly colored in each theme.