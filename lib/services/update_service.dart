import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/update_dialog.dart';

/// The newest published GitHub release, compared against the running app.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final int downloadSize;
  final String releaseNotes;
  final DateTime releaseDate;
  final String releasePageUrl;
  final bool isUpdateAvailable;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
    this.downloadSize = 0,
    this.releasePageUrl = UpdateService.releasesPageUrl,
    this.isUpdateAvailable = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, {bool isUpdateAvailable = false}) {
    final assets = json['assets'] as List<dynamic>? ?? const [];
    final apk = _userApk(assets);
    return UpdateInfo(
      version: (json['tag_name'] ?? '').toString().replaceFirst(RegExp('^[vV]'), ''),
      downloadUrl: apk?['browser_download_url'] ?? '',
      downloadSize: (apk?['size'] as num?)?.toInt() ?? 0,
      releaseNotes: (json['body'] ?? '').toString().trim(),
      releaseDate: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      releasePageUrl: json['html_url'] ?? UpdateService.releasesPageUrl,
      isUpdateAvailable: isUpdateAvailable,
    );
  }

  /// Releases can carry both the user and admin APKs; never hand the admin
  /// build to regular users.
  @visibleForTesting
  static String userApkUrl(List<dynamic> assets) =>
      _userApk(assets)?['browser_download_url'] ?? '';

  static Map<String, dynamic>? _userApk(List<dynamic> assets) {
    for (final asset in assets) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk') && !name.contains('admin')) {
        return Map<String, dynamic>.from(asset as Map);
      }
    }
    return null;
  }
}

/// Checks GitHub releases for a newer build and offers to download it.
///
/// Once [startAutoChecks] is called the app checks quietly on launch, when it
/// comes back to the foreground, and periodically while open (throttled to
/// [_autoCheckInterval]); a dialog only appears when there is something new.
class UpdateService with WidgetsBindingObserver {
  static const String _repo = 'HashTito1/GameLog';
  static const String releasesPageUrl = 'https://github.com/$_repo/releases';
  static const String _latestReleaseApi = 'https://api.github.com/repos/$_repo/releases/latest';

  static const String _lastCheckKey = 'last_update_check';
  static const String _skipVersionKey = 'skip_version';
  static const Duration _autoCheckInterval = Duration(hours: 3);
  static const MethodChannel _installChannel = MethodChannel('com.example.gamelog/update');

  static final UpdateService instance = UpdateService._();
  factory UpdateService() => instance;
  UpdateService._();

  BuildContext Function()? _contextProvider;
  Timer? _timer;
  bool _checking = false;
  bool _dialogShowing = false;

  /// Start background checks. [contextProvider] must return a mounted context
  /// under the app's Navigator (or null-check before use).
  void startAutoChecks(BuildContext Function() contextProvider) {
    _contextProvider = contextProvider;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _timer?.cancel();
    _timer = Timer.periodic(_autoCheckInterval, (_) => _autoCheck());
    // Let the first frame and sign-in settle before hitting the network.
    Future.delayed(const Duration(seconds: 3), _autoCheck);
  }

  void stopAutoChecks() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _contextProvider = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoCheck();
  }

  Future<void> _autoCheck() async {
    if (_checking || _dialogShowing || _contextProvider == null) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastCheckKey);
      if (last != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _autoCheckInterval) {
        return;
      }

      final info = await checkForUpdates();
      if (info == null) return; // offline or GitHub unavailable: retry next time
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (!info.isUpdateAvailable || prefs.getString(_skipVersionKey) == info.version) return;

      final context = _contextProvider?.call();
      if (context != null && context.mounted) {
        await showUpdateDialog(context, info);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    } finally {
      _checking = false;
    }
  }

  /// Show the "update available" dialog (also used by Settings > About).
  Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
    if (_dialogShowing) return;
    _dialogShowing = true;
    try {
      final current = (await getCurrentVersionInfo())['version'] ?? '';
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => UpdateAvailableDialog(info: info, currentVersion: current),
      );
    } finally {
      _dialogShowing = false;
    }
  }

  /// Fetch the latest published release. Returns null if it can't be reached.
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'GameLog-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        // No published (non-prerelease) release yet.
        return UpdateInfo(version: '', downloadUrl: '', releaseNotes: '', releaseDate: DateTime.now());
      }
      if (response.statusCode != 200) {
        debugPrint('Update check: GitHub returned ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final packageInfo = await PackageInfo.fromPlatform();
      final latest = UpdateInfo.fromJson(json);
      return UpdateInfo.fromJson(
        json,
        isUpdateAvailable: latest.version.isNotEmpty &&
            isNewerVersion(latest.version, '0', packageInfo.version, '0'),
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipVersionKey, version);
  }

  /// True when [remoteVersion] is newer than [currentVersion]. Versions are
  /// dotted numbers ("1.2.3", "v1.2.2.1"); build numbers break ties.
  /// Anything unparseable is treated as not newer.
  @visibleForTesting
  static bool isNewerVersion(String remoteVersion, String remoteBuild, String currentVersion, String currentBuild) {
    final remote = _parseVersion(remoteVersion);
    final current = _parseVersion(currentVersion);
    if (remote == null || current == null) return false;

    final length = remote.length > current.length ? remote.length : current.length;
    for (var i = 0; i < length; i++) {
      final r = i < remote.length ? remote[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (r != c) return r > c;
    }
    return (int.tryParse(remoteBuild) ?? 0) > (int.tryParse(currentBuild) ?? 0);
  }

  static List<int>? _parseVersion(String version) {
    final clean = version.trim().replaceFirst(RegExp('^[vV]'), '').split(RegExp('[+-]')).first;
    final parts = clean.split('.').map(int.tryParse).toList();
    if (parts.isEmpty || parts.contains(null)) return null;
    return parts.cast<int>();
  }

  /// Download the APK to the app cache, reporting progress (0..1, or null when
  /// the size is unknown). Returns the downloaded file.
  Future<File> downloadUpdate(
    UpdateInfo info, {
    required void Function(double? progress, int receivedBytes) onProgress,
    bool Function()? isCancelled,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/gamelog-${info.version}.apk');

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(info.downloadUrl)));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${response.statusCode})');
      }
      final total = response.contentLength ?? info.downloadSize;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) throw const _DownloadCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : null, received);
        }
      } finally {
        await sink.close();
      }
      return file;
    } catch (e) {
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Hand the APK to Android's package installer. Returns false if the user
  /// didn't allow GameLog to install apps.
  Future<bool> installApk(File apk) async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) return false;
    await _installChannel.invokeMethod('installApk', {'filePath': apk.path});
    return true;
  }

  /// Open a URL (the APK or the releases page) in the browser.
  Future<void> openInBrowser([String url = releasesPageUrl]) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }

  Future<void> openReleasesPage() => openInBrowser();

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
      return {'version': '', 'buildNumber': '', 'appName': 'GameLog', 'packageName': ''};
    }
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}

/// Whether [error] came from the user cancelling a download.
bool isDownloadCancelled(Object error) => error is _DownloadCancelled;
