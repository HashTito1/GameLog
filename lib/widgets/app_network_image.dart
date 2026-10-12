import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// CachedNetworkImage with app-wide defaults: a quiet placeholder while
/// loading, a neutral fallback instead of the red error box, and self-healing
/// when a cached file is broken (e.g. a download cut off by a flaky network).
/// The bad file is evicted so the next attempt downloads it again.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  /// URLs already evicted, so a failing image isn't evicted on every rebuild.
  static final Set<String> _evicted = {};

  Widget _box(BuildContext context, {bool failed = false}) {
    final color = Theme.of(context).colorScheme.onSurface;
    final side = [width, height].whereType<double>().fold<double?>(null, (a, b) => a == null ? b : (a < b ? a : b));
    return Container(
      width: width,
      height: height,
      color: color.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: failed
          ? Icon(
              Icons.videogame_asset_outlined,
              size: side == null ? 24 : (side * 0.4).clamp(12, 40),
              color: color.withValues(alpha: 0.3),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget?.call(context, imageUrl, 'empty url') ?? _box(context, failed: true);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: placeholder ?? (context, url) => _box(context),
      errorWidget: (context, url, error) {
        if (_evicted.add(url)) {
          CachedNetworkImage.evictFromCache(url);
        }
        return errorWidget?.call(context, url, error) ?? _box(context, failed: true);
      },
    );
  }
}
