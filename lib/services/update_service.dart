import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Update check preferences
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _skipVersionKey = 'skip_version';
  static const Duration _updateCheckInterval = Duration(hours: 6); // Check every 6 hours
  
  // Check if repository is configured
  static bool get _isRepositoryConfigured => 
      _repoOwner != 'YOUR_GITHUB_USERNAME' && 
      _repoName != 'YOUR_REPO_NAME' && 
      _repoOwner.isNotEmpty && 
      _repoName.isNotEmpty;
  
  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();
  static UpdateService get instance => _instance;

  /// Automatically check for updates and show dialog if needed
  Future<void> checkForUpdatesAndShowDialog(BuildContext context, {bool forceCheck = false}) async {
    try {
      // Check if we should skip this check
      if (!forceCheck && !await _shouldCheckForUpdates()) {
        return;
      }

      // Check for updates
      final updateInfo = await checkForUpdates();
      
      if (updateInfo != null && updateInfo.isUpdateAvailable) {
        // Check if user has skipped this version
        final prefs = await SharedPreferences.getInstance();
        final skippedVersion = prefs.getString(_skipVersionKey);
        
        if (!forceCheck && skippedVersion == updateInfo.version) {
          debugPrint('⏭️ User has skipped version ${updateInfo.version}');
          return;
        }

        // Show update dialog
        if (context.mounted) {
          await showUpdateDialogIfAvailable(context, updateInfo);
        }
      }

      // Update last check time
      await _updateLastCheckTime();
    } catch (e) {
      debugPrint('❌ Error in automatic update check: $e');
    }
  }

  /// Check if we should perform an update check based on time interval
  Future<bool> _shouldCheckForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = prefs.getInt(_lastUpdateCheckKey);
      
      if (lastCheckTime == null) {
        return true; // First time check
      }
      
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
      final now = DateTime.now();
      
      return now.difference(lastCheck) >= _updateCheckInterval;
    } catch (e) {
      debugPrint('Error checking update interval: $e');
      return true; // Default to checking
    }
  }

  /// Update the last check time
  Future<void> _updateLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error updating last check time: $e');
    }
  }

  /// Show the update dialog
  Future<void> showUpdateDialogIfAvailable(BuildContext context, UpdateInfo updateInfo) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
                child: const Icon(Icons.system_update, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Update Available!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.colorScheme.primary,
                ),
                child: Text(
                  'Version ${updateInfo.version}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              Text('Build: ${updateInfo.buildNumber}'),
              Text('Released: ${_formatDate(updateInfo.releaseDate)}'),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _formatReleaseNotes(updateInfo.releaseNotes),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await skipVersion(updateInfo.version);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Skip This Version'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                
                if (updateInfo.downloadUrl.isNotEmpty) {
                  // Show instant download dialog with progress
                  await _showDownloadDialog(context, updateInfo);
                } else {
                  await openReleasesPage();
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: Text(updateInfo.downloadUrl.isEmpty ? 'View on GitHub' : 'Download Now'),
            ),
          ],
        );
      },
    );
  }

  /// Show download dialog with real-time progress (public method)
  Future<void> showDownloadDialog(BuildContext context, UpdateInfo updateInfo) async {
    return _showDownloadDialog(context, updateInfo);
  }

  /// Show download dialog with real-time progress
  Future<void> _showDownloadDialog(BuildContext context, UpdateInfo updateInfo) async {
    double progress = 0.0;
    String status = 'Preparing download...';
    bool isCompleted = false;
    bool hasError = false;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start download immediately when dialog opens
            if (progress == 0.0 && !isCompleted && !hasError) {
              Future.microtask(() async {
                final success = await downloadAndInstallUpdate(
                  updateInfo.downloadUrl,
                  onProgress: (p) {
                    if (dialogContext.mounted) {
                      setState(() {
                        progress = p;
                      });
                    }
                  },
                  onStatusChange: (s) {
                    if (dialogContext.mounted) {
                      setState(() {
                        status = s;
                        if (s.contains('Installation started')) {
                          isCompleted = true;
                        } else if (s.contains('Error') || s.contains('failed')) {
                          hasError = true;
                        }
                      });
                    }
                  },
                );
                
                if (dialogContext.mounted) {
                  setState(() {
                    if (success) {
                      isCompleted = true;
                      status = 'Installation started! Please install the APK.';
                    } else {
                      hasError = true;
                      status = 'Download failed. Please try again or download manually.';
                    }
                  });
                  
                  // Auto-close dialog after 3 seconds if completed or failed
                  Future.delayed(const Duration(seconds: 3), () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  });
                }
              });
            }
            
            final theme = Theme.of(context);
            
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasError 
                          ? Colors.red 
                          : isCompleted 
                              ? Colors.green 
                              : theme.colorScheme.primary,
                    ),
                    child: Icon(
                      hasError 
                          ? Icons.error 
                          : isCompleted 
                              ? Icons.check_circle 
                              : Icons.download,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasError 
                          ? 'Download Failed' 
                          : isCompleted 
                              ? 'Download Complete!' 
                              : 'Downloading Update',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator
                  if (!isCompleted && !hasError) ...[
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Download completed successfully!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Download failed',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Status text
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasError) ...[
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            openReleasesPage();
                          },
                          child: const Text('Open GitHub'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(isCompleted ? 'Done' : 'Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatReleaseNotes(String notes) {
    return notes
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .replaceAll(RegExp(r'\n\s*\n'), '\n')
        .trim();
  }

  /// Skip a specific version
  Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skipVersionKey, version);
      debugPrint('⏭️ Skipped version: $version');
    } catch (e) {
      debugPrint('Error skipping version: $e');
    }
  }

  /// Clear skipped version (for testing or manual checks)
  Future<void> clearSkippedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_skipVersionKey);
      debugPrint('🗑️ Cleared skipped version');
    } catch (e) {
      debugPrint('Error clearing skipped version: $e');
    }
  }
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
    // Demo response when repository is not configured - simulate update available
    return UpdateInfo(
      version: '1.2.0',
      buildNumber: '6',
      downloadUrl: '', // Empty URL will trigger GitHub fallback
      releaseNotes: '''🚀 GameLog v1.2.0 - Major Update!

✨ New Features:
- In-app update system with automatic checking
- Enhanced UI with better animations
- Improved performance and bug fixes
- New social features and recommendations

🔧 Performance Improvements:
- Faster loading times
- Better memory management
- Optimized image caching

🐛 Bug Fixes:
- Fixed various UI issues
- Improved stability
- Better error handling

📥 Download Instructions:
Since this is a demo mode, please visit our GitHub repository to download the latest release manually.''',
      releaseDate: DateTime.now().subtract(const Duration(days: 1)),
      isUpdateAvailable: true, // Force show update for demo
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

  /// Download and install update with progress callback (Android only)
  Future<bool> downloadAndInstallUpdate(String downloadUrl, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('Preparing download...');
      
      if (downloadUrl.isEmpty) {
        debugPrint('❌ No download URL provided - opening GitHub instead');
        onStatusChange?.call('No download URL - opening GitHub');
        await openReleasesPage();
        return false;
      }

      if (!Platform.isAndroid) {
        debugPrint('❌ Auto-update only supported on Android');
        onStatusChange?.call('Auto-update only supported on Android');
        await openReleasesPage();
        return false;
      }

      debugPrint('📥 Starting download from: $downloadUrl');
      onStatusChange?.call('Checking download URL...');
      
      // Verify URL is accessible first
      final headResponse = await http.head(Uri.parse(downloadUrl)).timeout(
        const Duration(seconds: 10),
      );
      
      if (headResponse.statusCode != 200) {
        debugPrint('❌ Download URL not accessible: ${headResponse.statusCode}');
        onStatusChange?.call('Download URL not accessible');
        await openReleasesPage();
        return false;
      }
      
      onStatusChange?.call('Requesting permissions...');
      
      // Request storage permission
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        debugPrint('❌ Storage permission denied');
        onStatusChange?.call('Storage permission denied');
        return false;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint('❌ Could not access storage directory');
        onStatusChange?.call('Could not access storage');
        return false;
      }

      final filePath = '${directory.path}/gamelog_update.apk';
      final file = File(filePath);

      onStatusChange?.call('Starting download...');
      onProgress?.call(0.0);

      // Create HTTP client for streaming download
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        debugPrint('❌ Download failed: ${response.statusCode}');
        onStatusChange?.call('Download failed: ${response.statusCode}');
        await openReleasesPage();
        return false;
      }

      // Get total file size
      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;
      
      // Create file sink
      final sink = file.openWrite();
      
      try {
        // Stream download with progress updates
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            onProgress?.call(progress);
            
            final progressPercent = (progress * 100).toInt();
            final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
            final totalMB = (totalBytes / 1024 / 1024).toStringAsFixed(1);
            
            onStatusChange?.call('Downloading... $progressPercent% ($downloadedMB MB / $totalMB MB)');
          } else {
            final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
            onStatusChange?.call('Downloading... $downloadedMB MB');
          }
        }
        
        await sink.flush();
        await sink.close();
        
        debugPrint('✅ Download completed: $filePath');
        onStatusChange?.call('Download completed! Installing...');
        onProgress?.call(1.0);

        // Install the APK
        await _installApk(filePath);
        onStatusChange?.call('Installation started');
        return true;
        
      } catch (e) {
        await sink.close();
        debugPrint('❌ Download error: $e');
        onStatusChange?.call('Download error: $e');
        return false;
      } finally {
        client.close();
      }
      
    } catch (e) {
      debugPrint('❌ Error downloading update: $e');
      onStatusChange?.call('Error: $e');
      // Fallback to GitHub
      await openReleasesPage();
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