import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static const String _profileImagesDir = 'profile_images';
  static const String _bannerImagesDir = 'banner_images';

  // Get the app's documents directory
  static Future<Directory> _getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }

  // Create directories if they Don\'t exist
  static Future<void> _ensureDirectoriesExist() async {
    final appDir = await _getAppDirectory();
    
    final profileDir = Directory('${appDir.path}/$_profileImagesDir');
    final bannerDir = Directory('${appDir.path}/$_bannerImagesDir');
    
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    
    if (!await bannerDir.exists()) {
      await bannerDir.create(recursive: true);
    }
  }

  // Save image to persistent storage
  static Future<String?> saveImage({
    required Uint8List imageBytes,
    required String userId,
    required bool isProfilePicture,
  }) async {
    try {
                  await _ensureDirectoriesExist();
      
      final appDir = await _getAppDirectory();
      final subDir = isProfilePicture ? _profileImagesDir : _bannerImagesDir;
      final fileName = '$userId${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${appDir.path}/$subDir/$fileName';
      
                        final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      // Verify file was written
      if (kDebugMode) {
              }
      
      return filePath;
    } catch (e) {
            if (kDebugMode) {
                // Error handled
    }
      return null;
    }
  }

  // Get image path for a user
  static Future<String?> getImagePath({
    required String userId,
    required bool isProfilePicture,
  }) async {
    try {
      final appDir = await _getAppDirectory();
      final subDir = isProfilePicture ? _profileImagesDir : _bannerImagesDir;
      final directory = Directory('${appDir.path}/$subDir');
      
                  if (!await directory.exists()) {
                return null;
      }
      
      // Find the most recent image for this user
      final files = await directory.list().toList();
      final userFiles = files
          .whereType<File>()
          .where((file) => file.path.contains(userId))
          .toList();
      
      // for (final file in userFiles) {
      // } // unused loop
      
      if (userFiles.isEmpty) {
        return null;
      }
      
      // Sort by modification time (most recent first)
      userFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      final selectedFile = userFiles.first.path;
            return selectedFile;
    } catch (e) {
      if (kDebugMode) {
                // Error handled
    }
      return null;
    }
  }

  // Delete old images for a user (keep only the most recent)
  static Future<void> cleanupOldImages({
    required String userId,
    required bool isProfilePicture,
  }) async {
    try {
      final appDir = await _getAppDirectory();
      final subDir = isProfilePicture ? _profileImagesDir : _bannerImagesDir;
      final directory = Directory('${appDir.path}/$subDir');
      
      if (!await directory.exists()) {
        return;
      }
      
      final files = await directory.list().toList();
      final userFiles = files
          .whereType<File>()
          .where((file) => file.path.contains(userId))
          .toList();
      
      if (userFiles.length <= 1) {
        return; // Keep at least one file
      }
      
      // Sort by modification time (most recent first)
      userFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Delete all but the most recent
      for (int i = 1; i < userFiles.length; i++) {
        await userFiles[i].delete();
      }
    } catch (e) {
      if (kDebugMode) {
                // Error handled
    }
    }
  }

  // Delete all images for a user
  static Future<void> deleteUserImages({
    required String userId,
    required bool isProfilePicture,
  }) async {
    try {
      final appDir = await _getAppDirectory();
      final subDir = isProfilePicture ? _profileImagesDir : _bannerImagesDir;
      final directory = Directory('${appDir.path}/$subDir');
      
      if (!await directory.exists()) {
        return;
      }
      
      final files = await directory.list().toList();
      final userFiles = files
          .whereType<File>()
          .where((file) => file.path.contains(userId))
          .toList();
      
      for (final file in userFiles) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
                // Error handled
    }
    }
  }

  // Check if image exists
  static Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }
    
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
      // Error handled
    }
  }
}


