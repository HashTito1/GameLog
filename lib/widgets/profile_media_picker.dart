import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_media_service.dart';

/// What the picture is for: decides the GIF shape and size.
enum ProfileMediaKind {
  avatar(1.0, 320, 'profile picture'),
  banner(2.0, 600, 'banner');

  final double aspect;
  final int gifWidth;
  final String label;
  const ProfileMediaKind(this.aspect, this.gifWidth, this.label);
}

/// Bottom sheet: photo or GIF from the gallery, a camera photo, or a GIF made
/// from a video. Returns bytes ready to upload, or null if cancelled.
Future<Uint8List?> pickProfileMedia(BuildContext context, ProfileMediaKind kind) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      Widget option(String value, IconData icon, String title, String subtitle) => ListTile(
            tileColor: Colors.transparent,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            onTap: () => Navigator.pop(sheet, value),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Change ${kind.label}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            option('gallery', Icons.photo_library_outlined, 'Photo or GIF', 'Animated GIFs stay animated'),
            option('camera', Icons.photo_camera_outlined, 'Take a photo', 'Use your camera'),
            option('video', Icons.movie_creation_outlined, 'Make a GIF from a video', 'Pick a few seconds of any video'),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return null;

  try {
    switch (choice) {
      case 'gallery':
        return await ProfileMediaService.pickImage(source: ImageSource.gallery, maxSide: kind == ProfileMediaKind.avatar ? 800 : 1600);
      case 'camera':
        return await ProfileMediaService.pickImage(source: ImageSource.camera, maxSide: kind == ProfileMediaKind.avatar ? 800 : 1600);
      case 'video':
        final path = await ProfileMediaService.pickVideo();
        if (path == null || !context.mounted) return null;
        return await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(builder: (context) => VideoToGifScreen(videoPath: path, kind: kind)),
        );
    }
  } on MediaTooLargeException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that file. Try another one.')));
    }
  }
  return null;
}

/// Choose a few seconds of a video, preview the GIF, then use it.
class VideoToGifScreen extends StatefulWidget {
  final String videoPath;
  final ProfileMediaKind kind;

  const VideoToGifScreen({super.key, required this.videoPath, required this.kind});

  @override
  State<VideoToGifScreen> createState() => _VideoToGifScreenState();
}

class _VideoToGifScreenState extends State<VideoToGifScreen> {
  static const _lengths = [2, 3, 4, 5];

  int _durationMs = 0;
  double _startMs = 0;
  int _lengthS = 3;
  Uint8List? _gif;
  bool _working = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ms = await ProfileMediaService.videoDurationMs(widget.videoPath);
      if (!mounted) return;
      setState(() {
        _durationMs = ms;
        if (ms > 0 && ms < _lengthS * 1000) _lengthS = (ms / 1000).floor().clamp(1, 5);
      });
      _make();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read that video.');
    }
  }

  int get _maxStart => (_durationMs - _lengthS * 1000).clamp(0, _durationMs);

  Future<void> _make() async {
    final generation = ++_generation;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final gif = await ProfileMediaService.videoToGif(
        path: widget.videoPath,
        startMs: _startMs.round(),
        durationMs: _lengthS * 1000,
        aspect: widget.kind.aspect,
        width: widget.kind.gifWidth,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _gif = gif;
        _working = false;
      });
    } catch (e) {
      debugPrint('GIF creation failed: $e');
      if (!mounted || generation != _generation) return;
      setState(() {
        _working = false;
        _error = 'Could not make a GIF from this part of the video.';
      });
    }
  }

  String _clock(num ms) {
    final s = (ms / 1000).floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final gif = _gif;
    final tooBig = gif != null && gif.length > ProfileMediaService.maxGifBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a GIF', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Preview in the shape it will be shown.
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.kind == ProfileMediaKind.avatar ? 200 : 16),
              child: SizedBox(
                width: widget.kind == ProfileMediaKind.avatar ? 220 : double.infinity,
                child: AspectRatio(
                  aspectRatio: widget.kind.aspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
                      if (gif != null) Image.memory(gif, fit: BoxFit.cover, gaplessPlayback: true),
                      if (_working)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _error ??
                  (_working
                      ? 'Making your GIF…'
                      : gif == null
                          ? ''
                          : '${(gif.length / 1024 / 1024).toStringAsFixed(1)} MB · ${_lengthS}s loop'),
              style: TextStyle(color: _error != null || tooBig ? theme.colorScheme.error : muted),
            ),
          ),
          const SizedBox(height: 24),
          if (_durationMs > 0) ...[
            Row(
              children: [
                const Text('Start', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_clock(_startMs)} – ${_clock(_startMs + _lengthS * 1000)}', style: TextStyle(color: muted)),
              ],
            ),
            Slider(
              value: _startMs.clamp(0, _maxStart.toDouble()),
              max: _maxStart.toDouble() <= 0 ? 1 : _maxStart.toDouble(),
              onChanged: _maxStart <= 0 ? null : (v) => setState(() => _startMs = v),
              onChangeEnd: (_) => _make(),
            ),
            const SizedBox(height: 8),
            const Text('Length', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in _lengths)
                  ChoiceChip(
                    label: Text('${s}s'),
                    selected: _lengthS == s,
                    onSelected: s * 1000 > _durationMs && s != _lengths.first
                        ? null
                        : (_) {
                            setState(() {
                              _lengthS = s;
                              _startMs = _startMs.clamp(0, _maxStart.toDouble());
                            });
                            _make();
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: gif == null || _working || tooBig ? null : () => Navigator.pop(context, gif),
              icon: const Icon(Icons.check_rounded),
              label: Text(tooBig ? 'Too big — pick a shorter part' : 'Use as ${widget.kind.label}'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
