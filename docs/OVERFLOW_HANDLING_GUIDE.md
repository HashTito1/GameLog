# Overflow Handling Guide

This guide explains how to handle overflowing elements in the GameLog Flutter app using the custom overflow widgets and responsive design patterns.

## Overview

The app includes comprehensive overflow handling through custom widgets that prevent UI breaking when content exceeds available space. This is especially important for:

- Long game titles
- Developer names and release dates
- Genre and platform lists
- Review text and descriptions
- User-generated content

## Available Widgets

### 1. OverflowWidgets.ellipsisText()

Handles text overflow with ellipsis and optional tooltips.

```dart
OverflowWidgets.ellipsisText(
  'Very Long Game Title That Might Overflow',
  style: TextStyle(fontSize: 16, color: Colors.white),
  maxLines: 2,
  showTooltip: true,
)
```

**Parameters:**
- `text`: The text to display
- `style`: Text styling
- `maxLines`: Maximum number of lines (default: 1)
- `textAlign`: Text alignment
- `showTooltip`: Show tooltip on hover/long press (default: true)
- `tooltipMessage`: Custom tooltip message

### 2. OverflowWidgets.expandableText()

Creates expandable text for long descriptions.

```dart
OverflowWidgets.expandableText(
  game.description,
  style: TextStyle(fontSize: 14, color: Colors.grey),
  maxLines: 3,
  expandText: 'Show more',
  collapseText: 'Show less',
)
```

**Parameters:**
- `text`: The text content
- `style`: Text styling
- `maxLines`: Initial maximum lines to show
- `expandText`: Text for expand button
- `collapseText`: Text for collapse button
- `linkColor`: Color for expand/collapse links

### 3. OverflowWidgets.scrollableChips()

Creates a horizontal scrollable list of chips.

```dart
OverflowWidgets.scrollableChips(
  game.genres,
  chipColor: Color(0xFF6366F1),
  textColor: Colors.white,
  height: 40.0,
)
```

**Parameters:**
- `items`: List of strings for chips
- `chipColor`: Background color of chips
- `textColor`: Text color
- `fontSize`: Font size
- `padding`: Chip padding
- `spacing`: Space between chips
- `height`: Container height

### 4. OverflowWidgets.wrapChips()

Creates a wrap layout with overflow handling for chips.

```dart
OverflowWidgets.wrapChips(
  game.genres,
  maxItems: 6,
  chipColor: Color(0xFF6366F1),
  overflowText: '+{count} more',
)
```

**Parameters:**
- `items`: List of strings for chips
- `maxItems`: Maximum chips to show before overflow
- `overflowText`: Text pattern for overflow indicator
- Other styling parameters similar to scrollableChips

### 5. OverflowWidgets.flexibleRow()

Creates a flexible row that wraps to next line when needed.

```dart
OverflowWidgets.flexibleRow(
  children: [
    Icon(Icons.star),
    Text('Rating'),
    Text('4.5'),
  ],
  spacing: 8.0,
  runSpacing: 4.0,
)
```

### 6. ResponsiveGrid

A responsive grid that adapts to screen size.

```dart
ResponsiveGrid(
  children: gameWidgets,
  mobileColumns: 2,
  tabletColumns: 3,
  desktopColumns: 4,
  spacing: 16.0,
)
```

### 7. ResponsiveListTile

A list tile that adapts its layout based on screen size.

```dart
ResponsiveListTile(
  leading: gameImage,
  title: OverflowWidgets.ellipsisText(game.title),
  subtitle: OverflowWidgets.ellipsisText(game.developer),
  trailing: addButton,
  onTap: () => navigateToGame(game),
)
```

## Implementation Examples

### Game Detail Screen

```dart
// Title with overflow handling
OverflowWidgets.ellipsisText(
  game.title,
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  maxLines: 2,
)

// Genre chips with overflow
OverflowWidgets.wrapChips(
  game.genres,
  maxItems: 6,
  chipColor: Color(0xFF6366F1),
)

// Expandable description
OverflowWidgets.expandableText(
  game.description,
  maxLines: 4,
)
```

### Search Results

```dart
// Game title in search results
OverflowWidgets.ellipsisText(
  game.title,
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  maxLines: 2,
)

// Developer and release date
OverflowWidgets.ellipsisText(
  '${game.developer} • ${game.releaseDate}',
  style: TextStyle(color: Colors.grey),
)
```

### Library Screen

```dart
// Flexible row for status and hours played
OverflowWidgets.flexibleRow(
  children: [
    StatusChip(status: game.status),
    if (game.hoursPlayed != null)
      Flexible(
        child: OverflowWidgets.ellipsisText(
          '${game.hoursPlayed}h played',
          style: TextStyle(color: Colors.grey),
        ),
      ),
  ],
)
```

## Responsive Design Patterns

### Screen Size Detection

```dart
// Check screen size
if (ResponsiveLayout.isMobile(context)) {
  // Mobile layout
} else if (ResponsiveLayout.isTablet(context)) {
  // Tablet layout
} else {
  // Desktop layout
}

// Get responsive values
final fontSize = ResponsiveLayout.getResponsiveValue(
  context,
  mobile: 14.0,
  tablet: 16.0,
  desktop: 18.0,
);
```

### Responsive Grid Columns

```dart
final columns = ResponsiveLayout.getResponsiveGridCount(context);
// Returns: 2 for mobile, 3 for tablet, 4 for desktop
```

## Best Practices

### 1. Always Handle Text Overflow

```dart
// ❌ Bad - can cause overflow
Text(game.title)

// ✅ Good - handles overflow
OverflowWidgets.ellipsisText(game.title, maxLines: 2)
```

### 2. Use Flexible Widgets in Rows

```dart
// ❌ Bad - can cause overflow
Row(
  children: [
    Text(longText),
    Icon(Icons.star),
  ],
)

// ✅ Good - prevents overflow
Row(
  children: [
    Expanded(
      child: OverflowWidgets.ellipsisText(longText),
    ),
    Icon(Icons.star),
  ],
)
```

### 3. Limit Chip Lists

```dart
// ❌ Bad - unlimited chips can overflow
Wrap(children: allGenres.map((g) => Chip(label: Text(g))).toList())

// ✅ Good - limited with overflow indicator
OverflowWidgets.wrapChips(allGenres, maxItems: 5)
```

### 4. Use Expandable Text for Long Content

```dart
// ❌ Bad - long text takes too much space
Text(longDescription)

// ✅ Good - expandable with preview
OverflowWidgets.expandableText(longDescription, maxLines: 3)
```

### 5. Responsive Layouts

```dart
// ❌ Bad - fixed layout
GridView.count(crossAxisCount: 2, children: items)

// ✅ Good - responsive grid
ResponsiveGrid(
  mobileColumns: 2,
  tabletColumns: 3,
  desktopColumns: 4,
  children: items,
)
```

## Testing Overflow Scenarios

### Test Cases to Consider

1. **Very Long Game Titles**: "The Elder Scrolls V: Skyrim - Legendary Edition - Game of the Year Edition"
2. **Long Developer Names**: "Bethesda Game Studios and ZeniMax Online Studios"
3. **Many Genres**: Action, Adventure, RPG, Open World, Fantasy, Single Player, Multiplayer, Co-op
4. **Long Descriptions**: Full game descriptions from IGDB
5. **Different Screen Sizes**: Test on mobile, tablet, and desktop
6. **Different Languages**: Test with languages that have longer words

### Manual Testing

1. Use long test data in your mock objects
2. Test on different screen orientations
3. Test with system font scaling enabled
4. Test with different screen densities

## Performance Considerations

1. **Tooltip Performance**: Disable tooltips for frequently scrolled lists if needed
2. **Expandable Text**: Use sparingly in long lists
3. **Chip Scrolling**: Consider virtualization for very long lists
4. **Image Loading**: Always provide proper constraints for network images

## Migration Guide

To update existing screens:

1. Import the overflow widgets: `import '../widgets/overflow_widgets.dart';`
2. Replace `Text` widgets with `OverflowWidgets.ellipsisText()`
3. Replace `Wrap` with genre/platform chips with `OverflowWidgets.wrapChips()`
4. Replace long descriptions with `OverflowWidgets.expandableText()`
5. Use `OverflowWidgets.flexibleRow()` instead of `Row` where overflow might occur
6. Test thoroughly on different screen sizes

This comprehensive overflow handling ensures your app looks great and functions properly across all devices and content scenarios.