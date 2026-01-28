import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String version;
  final String buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;
  final bool isUpdateAvailable;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
    required this.isUpdateAvailable,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['tag_name'] ?? '1.0.0',
      buildNumber: json['name'] ?? '1',
      downloadUrl: json['assets']?.isNotEmpty == true 
          ? json['assets'][0]['browser_download_url'] ?? ''
          : '',
      releaseNotes: json['body'] ?? 'No release notes available.',
      releaseDate: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      isUpdateAvailable: false, // Will be set by comparison logic
    );
  }
}

class UpdateService {
  // GitHub repository configuration
  static const String _githubApiUrl = 'https://api.github.com/repos';
  static const String _repoOwner = 'HashTito1'; // GitHub username
  static const String _repoName = 'GameLog'; // Repository name
  static const String _branch = 'Update-test-branch'; // The test branch to check for updates
  
  // Check if repository is configured
  static bool get _isRepositoryConfigured => 
      _repoOwner != 'YOUR_GITHUB_USERNAME' && _repoName != 'YOUR_REPO_NAME';
  
  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();
  static UpdateService get instance => _instance;

  /// Check for updates from the GitHub test branch
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      debugPrint('🔍 Checking for updates from GitHub test branch...');
      
      // Check if repository is configured
      if (!_isRepositoryConfigured) {
        debugPrint('⚠️ Repository not configured - using demo response');
        return _createDemoUpdateInfo();
      }
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;
      
      debugPrint('📱 Current version: $currentVersion ($currentBuildNumber)');
      
      // Check for latest release on test branch
      final url = '$_githubApiUrl/$_repoOwner/$_repoName/releases';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'GameLog-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        
        if (releases.isEmpty) {
          debugPrint('❌ No releases found');
          return null;
        }

        // Find the latest release from test branch or latest release
        Map<String, dynamic>? latestRelease;
        for (final release in releases) {
          if (release['target_commitish'] == _branch || release['prerelease'] == true) {
            latestRelease = release;
            break;
          }
        }
        
        // If no test branch release found, use the latest release
        if (latestRelease == null && releases.isNotEmpty) {
          latestRelease = releases.first;
        }
        
        if (latestRelease == null) {
          debugPrint('❌ No suitable releases found');
          return null;
        }
        
        final updateInfo = UpdateInfo.fromJson(latestRelease);
        
        // Compare versions to determine if update is available
        final isUpdateAvailable = _isNewerVersion(
          updateInfo.version, 
          updateInfo.buildNumber, 
          currentVersion, 
          currentBuildNumber,
        );
        
        debugPrint('🆕 Latest version: ${updateInfo.version} (${updateInfo.buildNumber})');
        debugPrint('✅ Update available: $isUpdateAvailable');
        
        return UpdateInfo(
          version: updateInfo.version,
          buildNumber: updateInfo.buildNumber,
          downloadUrl: updateInfo.downloadUrl,
          releaseNotes: updateInfo.releaseNotes,
          releaseDate: updateInfo.releaseDate,
          isUpdateAvailable: isUpdateAvailable,
        );
      } else {
        debugPrint('❌ Failed to check for updates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      return null;
    }
  }

  /// Create a demo update info for when repository is not configured
  UpdateInfo _createDemoUpdateInfo() {
    // Demo response when repository is not configured  
    return UpdateInfo(
      version: '1.0.0',
      buildNumber: '1',
      downloadUrl: '',
      releaseNotes: 'Repository not configured. Please set up GitHub repository information in UpdateService to enable real update checking.',
      releaseDate: DateTime.now(),
      isUpdateAvailable: false,
    );
  }

  /// Compare version strings to determine if an update is available
  bool _isNewerVersion(String remoteVersion, String remoteBuild, String currentVersion, String currentBuild) {
    try {
      // Remove 'v' prefix if present
      final cleanRemoteVersion = remoteVersion.replaceFirst('v', '');
      final cleanCurrentVersion = currentVersion.replaceFirst('v', '');
      
      // Parse version numbers (e.g., "1.2.3" -> [1, 2, 3])
      final remoteParts = cleanRemoteVersion.split('.').map(int.parse).toList();
      final currentParts = cleanCurrentVersion.split('.').map(int.parse).toList();
      
      // Ensure both have same number of parts
      while (remoteParts.length < 3) remoteParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);
      
      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      
      // If versions are equal, compare build numbers
      final remoteBuildNum = int.tryParse(remoteBuild) ?? 0;
      final currentBuildNum = int.tryParse(currentBuild) ?? 0;
      
      return remoteBuildNum > currentBuildNum;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Download and install update (Android only)
  Future<bool> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('❌ Auto-update only supported on Android');
        return false;
      }

      debugPrint('📥 Starting download from: $downloadUrl');
      
      // Request storage permission
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        debugPrint('❌ Storage permission denied');
        return false;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint('❌ Could not access storage directory');
        return false;
      }

      final filePath = '${directory.path}/gamelog_update.apk';
      final file = File(filePath);

      // Download the APK
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('✅ Download completed: $filePath');

        // Install the APK
        await _installApk(filePath);
        return true;
      } else {
        debugPrint('❌ Download failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error downloading update: $e');
      return false;
    }
  }

  /// Install APK file (Android only)
  Future<void> _installApk(String filePath) async {
    try {
      // Request install permission for Android 8.0+
      if (Platform.isAndroid) {
        final permission = await Permission.requestInstallPackages.request();
        if (!permission.isGranted) {
          debugPrint('❌ Install permission denied');
          return;
        }
      }

      // Use platform channel to install APK
      const platform = MethodChannel('com.example.gamelog/update');
      await platform.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      debugPrint('❌ Error installing APK: $e');
      // Fallback: open file manager to let user install manually
      await _openFileManager(filePath);
    }
  }

  /// Open file manager to let user install APK manually
  Future<void> _openFileManager(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('❌ Error opening file manager: $e');
    }
  }

  /// Open GitHub releases page in browser
  Future<void> openReleasesPage() async {
    try {
      String url;
      if (_isRepositoryConfigured) {
        url = 'https://github.com/$_repoOwner/$_repoName/releases';
      } else {
        // Fallback to a generic GitHub search for GameLog repositories
        url = 'https://github.com/search?q=gamelog+flutter&type=repositories';
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Error opening releases page: $e');
    }
  }

  /// Get current app version info
  Future<Map<String, String>> getCurrentVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
      };
    } catch (e) {
      debugPrint('❌ Error getting version info: $e');
      return {
        'version': '1.0.0',
        'buildNumber': '1',
        'appName': 'GameLog',
        'packageName': 'com.example.gamelog',
      };
    }
  }
}