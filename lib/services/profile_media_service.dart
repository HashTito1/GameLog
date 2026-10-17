import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Picks, prepares and converts images for profile pictures and banners.
///
/// GIFs are uploaded untouched so they stay animated; other photos are
/// scaled down and re-encoded as JPEG. Videos can be turned into a short
/// looping GIF.
class ProfileMediaService {
  static final ImagePicker _picker = ImagePicker();
  static const MethodChannel _media = MethodChannel('com.example.gamelog/media');

  /// Animated GIFs larger than this are refused: they load slowly for
  /// everyone who sees the profile.
  static const int maxGifBytes = 8 * 1024 * 1024;

  static bool isGif(Uint8List bytes) =>
      bytes.length > 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38;

  /// Pick a photo or GIF from the gallery (or a photo from the camera) and
  /// return bytes ready to upload.
  static Future<Uint8List?> pickImage({required ImageSource source, int maxSide = 1600}) async {
    // No size limits here: the picker would re-encode GIFs to JPEG and lose
    // the animation. Resizing happens below for non-GIFs.
    final file = await _picker.pickImage(source: source, requestFullMetadata: false);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (isGif(bytes)) {
      if (bytes.length > maxGifBytes) {
        throw const MediaTooLargeException('That GIF is over 8 MB. Pick a smaller one.');
      }
      return bytes;
    }
    return _downscaleToJpeg(bytes, maxSide);
  }

  static Future<Uint8List> _downscaleToJpeg(Uint8List bytes, int maxSide) async {
    // Native decode at the target size (fast), then JPEG in a background
    // isolate.
    final probe = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(probe);
    final w = descriptor.width, h = descriptor.height;
    final scale = (w > h ? w : h) > maxSide ? maxSide / (w > h ? w : h) : 1.0;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (w * scale).round(),
      targetHeight: (h * scale).round(),
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = await compute(_encodeJpeg, (rgba!.buffer.asUint8List(), image.width, image.height));
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    probe.dispose();
    return result;
  }

  static Uint8List _encodeJpeg((Uint8List, int, int) args) {
    final (rgba, width, height) = args;
    final image = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4);
    return img.encodeJpg(image, quality: 85);
  }

  static Future<String?> pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    return file?.path;
  }

  static Future<int> videoDurationMs(String path) async {
    final ms = await _media.invokeMethod<int>('videoDuration', {'path': path});
    return ms ?? 0;
  }

  /// Turn [durationMs] of a video starting at [startMs] into a looping GIF.
  /// [aspect] is the width/height the GIF is cropped to (1 for avatars).
  static Future<Uint8List> videoToGif({
    required String path,
    required int startMs,
    required int durationMs,
    required double aspect,
    required int width,
    int fps = 10,
  }) async {
    final height= (width / aspect).round();
    final frames = await _media.invokeListMethod<Uint8List>('extractFrames', {
      'path': path,
      'startMs': startMs,
      'durationMs': durationMs,
      'fps': fps,
      'width': width,
      'height': height,
    });
    if (frames == null || frames.isEmpty) {
      throw const MediaTooLargeException('Could not read frames from that video.');
    }
    return compute(_encodeGif, (frames, width, height, fps));
  }

  /// Frames arrive as RGBA already cropped and scaled on the Android side.
  static Uint8List _encodeGif((List<Uint8List>, int, int, int) args) {
    final (frames, width, height, fps) = args;
    final encoder = img.GifEncoder(repeat: 0, samplingFactor: 10, quantizerType: img.QuantizerType.octree);
    final delay = (100 / fps).round(); // hundredths of a second
    for (final frame in frames) {
      if (frame.length != width * height * 4) continue;
      // Video frames have no real transparency, but Android can hand them
      // over with alpha 0, which the GIF would show as see-through. (Copy
      // first: buffers from the platform channel are read-only.)
      final rgba = Uint8List.fromList(frame);
      for (var i = 3; i < rgba.length; i += 4) {
        rgba[i] = 255;
      }
      encoder.addFrame(
        img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4),
        duration: delay,
      );
    }
    return encoder.finish()!;
  }
}

class MediaTooLargeException implements Exception {
  final String message;
  const MediaTooLargeException(this.message);
  @override
  String toString() => message;
}
