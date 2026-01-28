import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImgBBStorageService {
  // ImgBB API configuration
  // Get your free API key from: https://api.imgbb.com/
  static const String _apiKey = 'aa0abfd2154201a3e8cd5ed7a11adbf8';
  static const String _uploadEndpoint = 'https://api.imgbb.com/1/upload';
  
  /// Upload profile picture to ImgBB
  static Future<String?> uploadProfilePicture({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting ImgBB profile picture upload for user: $userId');
        print('Image size: ${imageBytes.length} bytes');
      }
      
      // Generate unique filename
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Upload to ImgBB
      final downloadUrl = await _uploadToImgBB(
        imageBytes: imageBytes,
        fileName: fileName,
      );
      
      if (kDebugMode) {
        print('ImgBB profile picture uploaded successfully: $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error uploading profile picture to ImgBB: $e');
        print('Stack trace: $stackTrace');
      }
      
      throw Exception('Failed to upload profile picture to ImgBB: ${e.toString()}');
    }
  }
  
  /// Upload banner image to ImgBB
  static Future<String?> uploadBannerImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting ImgBB banner image upload for user: $userId');
        print('Image size: ${imageBytes.length} bytes');
      }
      
      // Generate unique filename
      final fileName = 'banner_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Upload to ImgBB
      final downloadUrl = await _uploadToImgBB(
        imageBytes: imageBytes,
        fileName: fileName,
      );
      
      if (kDebugMode) {
        print('ImgBB banner image uploaded successfully: $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error uploading banner image to ImgBB: $e');
        print('Stack trace: $stackTrace');
      }
      
      throw Exception('Failed to upload banner image to ImgBB: ${e.toString()}');
    }
  }
  
  /// Core upload method to ImgBB
  static Future<String?> _uploadToImgBB({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      // Convert image bytes to base64
      final base64Image = base64Encode(imageBytes);
      
      // Create form data
      final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));
      
      // Add API key and image data
      request.fields['key'] = _apiKey;
      request.fields['image'] = base64Image;
      request.fields['name'] = fileName;
      
      if (kDebugMode) {
        print('Uploading to ImgBB...');
      }
      
      // Send request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (kDebugMode) {
        print('ImgBB response status: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          final url = responseData['data']['url'] as String?;
          
          if (kDebugMode) {
            print('ImgBB upload successful: $url');
          }
          
          return url;
        } else {
          throw Exception('ImgBB API error: ${responseData['error']['message']}');
        }
      } else {
        if (kDebugMode) {
          print('ImgBB upload failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        
        throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ImgBB upload error: $e');
      }
      rethrow;
    }
  }
  
  /// Check if a URL is an ImgBB URL
  static bool isImgBBUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('i.ibb.co') || url.contains('imgbb.com');
  }
  
  /// Get optimized ImgBB URL (ImgBB doesn't support transformations, returns original)
  static String getOptimizedUrl(String originalUrl, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
  }) {
    // ImgBB doesn't support URL transformations, return original
    return originalUrl;
  }
  
  /// Get profile picture URL (no optimization available)
  static String getProfilePictureUrl(String? originalUrl, {int size = 200}) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    return originalUrl;
  }
  
  /// Get banner image URL (no optimization available)
  static String getBannerImageUrl(String? originalUrl, {int? width, int? height}) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    return originalUrl;
  }
}