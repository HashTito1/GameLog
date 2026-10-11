import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Profile and banner images stored in Firebase Storage under
/// users/{userId}/. Access is enforced by storage.rules.
class HybridImageStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile picture and return its download URL
  static Future<String?> uploadProfilePicture({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      return await _upload(userId: userId, kind: 'profile', imageBytes: imageBytes);
    } catch (e) {
      throw Exception('Failed to upload profile picture to cloud storage: $e');
    }
  }

  /// Upload banner image and return its download URL
  static Future<String?> uploadBannerImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      return await _upload(userId: userId, kind: 'banner', imageBytes: imageBytes);
    } catch (e) {
      throw Exception('Failed to upload banner image to cloud storage: $e');
    }
  }

  static Future<String> _upload({
    required String userId,
    required String kind,
    required Uint8List imageBytes,
  }) async {
    // Unique name per upload so cached copies of the old image never linger.
    final ref = _storage
        .ref('users/$userId/${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Check if URL is a Firebase Storage URL
  static bool isCloudStorageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('firebasestorage.googleapis.com') ||
        url.contains('.firebasestorage.app');
  }

  /// Delete the previous profile picture after a successful replacement
  static Future<void> deleteOldProfilePicture(String? oldImageUrl) =>
      _deleteIfOwned(oldImageUrl);

  /// Delete the previous banner image after a successful replacement
  static Future<void> deleteOldBannerImage(String? oldImageUrl) =>
      _deleteIfOwned(oldImageUrl);

  static Future<void> _deleteIfOwned(String? url) async {
    // Older images hosted elsewhere (e.g. ImgBB) can't be deleted from here.
    if (!isCloudStorageUrl(url)) return;
    try {
      await _storage.refFromURL(url!).delete();
    } catch (e) {
      debugPrint('Could not delete old image: $e');
    }
  }
}
