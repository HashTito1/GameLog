import 'package:flutter/foundation.dart';
import 'imgbb_storage_service.dart';

/// Cloud-only image storage service using ImgBB with caching
class HybridImageStorageService {
  
  /// Upload profile picture - cloud storage only (ImgBB)
  static Future<String?> uploadProfilePicture({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      if (kDebugMode) {
        print('Uploading profile picture to ImgBB cloud storage...');
      }
      
      final imgbbUrl = await ImgBBStorageService.uploadProfilePicture(
        userId: userId,
        imageBytes: imageBytes,
      );
      
      if (imgbbUrl != null) {
        if (kDebugMode) {
          print('Cloud storage upload successful: $imgbbUrl');
        }
        return imgbbUrl;
      } else {
        throw Exception('ImgBB upload returned null URL');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cloud storage upload failed: $e');
      }
      throw Exception('Failed to upload profile picture to cloud storage: ${e.toString()}');
    }
  }
  
  /// Upload banner image - cloud storage only (ImgBB)
  static Future<String?> uploadBannerImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      if (kDebugMode) {
        print('Uploading banner image to ImgBB cloud storage...');
      }
      
      final imgbbUrl = await ImgBBStorageService.uploadBannerImage(
        userId: userId,
        imageBytes: imageBytes,
      );
      
      if (imgbbUrl != null) {
        if (kDebugMode) {
          print('Cloud storage upload successful: $imgbbUrl');
        }
        return imgbbUrl;
      } else {
        throw Exception('ImgBB upload returned null URL');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cloud storage upload failed: $e');
      }
      throw Exception('Failed to upload banner image to cloud storage: ${e.toString()}');
    }
  }
  
  /// Check if URL is a cloud storage URL (ImgBB)
  static bool isCloudStorageUrl(String? url) {
    return ImgBBStorageService.isImgBBUrl(url);
  }
  
  /// Delete old image (ImgBB doesn't support deletion via API)
  static Future<void> deleteOldProfilePicture(String? oldImageUrl) async {
    if (oldImageUrl == null || oldImageUrl.isEmpty) return;
    
    if (kDebugMode) {
      print('Note: ImgBB does not support image deletion via API');
      print('Old image will remain accessible: $oldImageUrl');
    }
    
    // ImgBB doesn't support deletion via API
    // Images remain accessible but this is acceptable for most use cases
  }
  
  /// Delete old banner image (ImgBB doesn't support deletion via API)
  static Future<void> deleteOldBannerImage(String? oldImageUrl) async {
    if (oldImageUrl == null || oldImageUrl.isEmpty) return;
    
    if (kDebugMode) {
      print('Note: ImgBB does not support image deletion via API');
      print('Old image will remain accessible: $oldImageUrl');
    }
    
    // ImgBB doesn't support deletion via API
    // Images remain accessible but this is acceptable for most use cases
  }
}