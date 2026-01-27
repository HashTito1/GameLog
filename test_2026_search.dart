// Quick test to verify 2026 games show up in search
import 'lib/services/rawg_service.dart';

void main() async {
  final rawgService = RAWGService.instance;
  
  print('Testing 2026 game search...');
  
  // Test search for GTA VI (2026 game)
  final gtaResults = await rawgService.searchGamesWithFilters(
    query: 'Grand Theft Auto VI',
    releasedAfter: '2026-01-01',
    releasedBefore: '2026-12-31',
    limit: 10,
  );
  
  print('Found ${gtaResults.length} results for GTA VI in 2026');
  for (final game in gtaResults) {
    print('- ${game.title} (${game.releaseDate})');
  }
  
  // Test search for Elder Scrolls VI (2026 game)
  final elderScrollsResults = await rawgService.searchGamesWithFilters(
    query: 'Elder Scrolls VI',
    releasedAfter: '2026-01-01',
    releasedBefore: '2026-12-31',
    limit: 10,
  );
  
  print('\nFound ${elderScrollsResults.length} results for Elder Scrolls VI in 2026');
  for (final game in elderScrollsResults) {
    print('- ${game.title} (${game.releaseDate})');
  }
  
  // Test general 2026 search
  final all2026Results = await rawgService.searchGamesWithFilters(
    query: '',
    releasedAfter: '2026-01-01',
    releasedBefore: '2026-12-31',
    limit: 10,
  );
  
  print('\nFound ${all2026Results.length} total games for 2026');
  for (final game in all2026Results) {
    print('- ${game.title} (${game.releaseDate})');
  }
}