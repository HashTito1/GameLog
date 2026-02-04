import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify GitHub API for update checking
Future<void> main() async {
  print('🔍 Testing GitHub API for GameLog updates...\n');
  
  const String repoOwner = 'HashTito1';
  const String repoName = 'GameLog';
  const String branch = 'Update-test-branch';
  
  try {
    // Test GitHub API endpoint
    final url = 'https://api.github.com/repos/$repoOwner/$repoName/releases';
    print('📡 Calling: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GameLog-App',
      },
    ).timeout(const Duration(seconds: 10));

    print('📊 Response Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final List<dynamic> releases = json.decode(response.body);
      print('✅ Found ${releases.length} releases');
      
      if (releases.isEmpty) {
        print('⚠️  No releases found in repository');
        print('💡 Create a release on GitHub to test the update system');
        return;
      }
      
      print('\n📋 Available Releases:');
      for (int i = 0; i < releases.length && i < 5; i++) {
        final release = releases[i];
        final tagName = release['tag_name'] ?? 'Unknown';
        final targetBranch = release['target_commitish'] ?? 'Unknown';
        final isPrerelease = release['prerelease'] ?? false;
        final publishedAt = release['published_at'] ?? 'Unknown';
        final assets = release['assets'] as List? ?? [];
        
        print('  ${i + 1}. $tagName');
        print('     Branch: $targetBranch');
        print('     Prerelease: $isPrerelease');
        print('     Published: $publishedAt');
        print('     Assets: ${assets.length}');
        
        if (assets.isNotEmpty) {
          for (final asset in assets) {
            final name = asset['name'] ?? 'Unknown';
            final downloadUrl = asset['browser_download_url'] ?? '';
            final size = asset['size'] ?? 0;
            print('       - $name (${(size / 1024 / 1024).toStringAsFixed(1)} MB)');
            print('         URL: $downloadUrl');
          }
        }
        print('');
      }
      
      // Check for test branch releases
      print('🔍 Looking for $branch releases...');
      final testBranchReleases = releases.where((release) => 
        release['target_commitish'] == branch || release['prerelease'] == true
      ).toList();
      
      if (testBranchReleases.isNotEmpty) {
        print('✅ Found ${testBranchReleases.length} test branch releases');
        final latest = testBranchReleases.first;
        print('📦 Latest test release: ${latest['tag_name']}');
        
        final assets = latest['assets'] as List? ?? [];
        if (assets.isNotEmpty) {
          final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );
          
          if (apkAsset != null) {
            print('✅ APK found: ${apkAsset['name']}');
            print('📥 Download URL: ${apkAsset['browser_download_url']}');
            
            // Test if download URL is accessible
            try {
              final headResponse = await http.head(
                Uri.parse(apkAsset['browser_download_url']),
              ).timeout(const Duration(seconds: 5));
              
              if (headResponse.statusCode == 200) {
                print('✅ Download URL is accessible');
              } else {
                print('❌ Download URL returned: ${headResponse.statusCode}');
              }
            } catch (e) {
              print('❌ Download URL test failed: $e');
            }
          } else {
            print('⚠️  No APK file found in latest release');
          }
        } else {
          print('⚠️  No assets found in latest release');
        }
      } else {
        print('⚠️  No test branch releases found');
        print('💡 Create a release targeting $branch to enable updates');
      }
      
    } else if (response.statusCode == 404) {
      print('❌ Repository not found');
      print('💡 Check if repository exists: https://github.com/$repoOwner/$repoName');
    } else {
      print('❌ API Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Error testing GitHub API: $e');
    print('💡 Check internet connection and repository configuration');
  }
  
  print('\n🔗 Repository URL: https://github.com/$repoOwner/$repoName');
  print('🔗 Releases URL: https://github.com/$repoOwner/$repoName/releases');
}