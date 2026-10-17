import 'package:flutter/material.dart';

/// Where a game sits in your library. One definition used by the game page's
/// "Add to library" sheet, the Library screen and the stats.
enum LibraryStatus {
  playing('playing', 'Playing', 'Games you\'re playing right now', Icons.sports_esports_rounded, Color(0xFF10B981)),
  want('want', 'Want', 'Games you want to get and play', Icons.favorite_rounded, Color(0xFFEC4899)),
  backlog('backlog', 'Backlog', 'Games you have but haven\'t started', Icons.bookmark_rounded, Color(0xFF8B5CF6)),
  completed('completed', 'Completed', 'Games you\'ve finished', Icons.emoji_events_rounded, Color(0xFFF5B83D)),
  dropped('dropped', 'Dropped', 'Games you stopped playing', Icons.do_not_disturb_on_rounded, Color(0xFFEF4444));

  /// Value stored in Firestore.
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const LibraryStatus(this.value, this.label, this.description, this.icon, this.color);

  /// Order used for the "Add to library" sheet: plans first, then progress.
  static const List<LibraryStatus> pickerOrder = [want, backlog, playing, completed, dropped];

  /// Order used for the Library screen: what you're playing first.
  static const List<LibraryStatus> libraryOrder = [playing, want, backlog, completed, dropped];

  static LibraryStatus? fromValue(String? value) {
    switch (value) {
      case 'playing':
        return playing;
      case 'want':
        return want;
      case 'backlog':
      // Older app versions saved these for "plan to play"; they always showed
      // under Backlog, so they stay there.
      case 'want_to_play':
      case 'planToPlay':
        return backlog;
      case 'completed':
        return completed;
      case 'dropped':
        return dropped;
      default:
        return null;
    }
  }

  /// Category for a library entry. Rated games without an explicit status
  /// (older entries, or games you only rated) count as Completed.
  static LibraryStatus forEntry(Map<String, dynamic> entry) {
    return fromValue(entry['status'] as String?) ?? completed;
  }
}
