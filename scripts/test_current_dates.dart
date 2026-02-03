void main() {
  final now = DateTime.now();
  print('🗓️ Current Date Analysis:');
  print('Current year: ${now.year}');
  print('Current date: ${now.toString().split(' ')[0]}');
  
  print('\n📅 GOTY Logic:');
  final gotyYear = now.year - 1;
  print('GOTY year (current - 1): $gotyYear');
  
  print('\n📅 Popular Games Logic (last 3 years):');
  final threeYearsAgo = now.subtract(const Duration(days: 1095));
  print('Three years ago: ${threeYearsAgo.year}');
  print('Date range: ${threeYearsAgo.year} to ${now.year}');
  
  print('\n📅 Trending Games Logic (last 2 years):');
  final twoYearsAgo = now.subtract(const Duration(days: 730));
  print('Two years ago: ${twoYearsAgo.year}');
  print('Date range: ${twoYearsAgo.year} to ${now.year}');
  
  print('\n🎯 Expected Results:');
  print('- GOTY should show: $gotyYear games');
  print('- Popular should show: ${threeYearsAgo.year}-${now.year} games');
  print('- Trending should show: ${twoYearsAgo.year}-${now.year} games');
  
  print('\n⚠️ Potential Issues:');
  if (gotyYear == 2025) {
    print('✅ GOTY year is correct (2025)');
  } else {
    print('❌ GOTY year is wrong: $gotyYear (should be 2025)');
  }
  
  if (threeYearsAgo.year <= 2023 && now.year >= 2026) {
    print('✅ Popular games range includes recent years');
  } else {
    print('❌ Popular games range might be too narrow');
  }
}