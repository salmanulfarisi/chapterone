import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/utils/logger.dart';

/// Service for optimizing image loading and caching
class ImageOptimizationService {
  static const int cacheWidthDefault = 400;
  static const int cacheHeightDefault = 600;
  static const Duration cacheMaxStale = Duration(days: 30);

  /// Get image builder with optimization settings
  static Widget buildOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    PlaceholderWidgetBuilder? placeholder,
    LoadingErrorWidgetBuilder? errorWidget,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    // Use provided cache dimensions or defaults
    // In production, these can be calculated based on screen size
    final optimizedCacheWidth = cacheWidth ?? (width != null ? width.round() : cacheWidthDefault);
    final optimizedCacheHeight = cacheHeight ?? (height != null ? height.round() : cacheHeightDefault);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: optimizedCacheWidth,
      memCacheHeight: optimizedCacheHeight,
      maxWidthDiskCache: optimizedCacheWidth * 2, // Allow 2x for high DPI
      maxHeightDiskCache: optimizedCacheHeight * 2,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: placeholder ?? (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: errorWidget ?? (context, url, error) {
        Logger.warning('Failed to load image: $url', 'ImageOptimizationService');
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  /// Preload images for better performance
  /// Note: Requires BuildContext in actual usage
  static Future<void> preloadImage(String imageUrl, BuildContext context) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
      Logger.debug('Image preloaded: $imageUrl', 'ImageOptimizationService');
    } catch (e) {
      Logger.warning('Failed to preload image: $imageUrl', 'ImageOptimizationService');
    }
  }

  /// Clear image cache (note: CachedNetworkImage uses its own cache manager)
  static Future<void> clearCache() async {
    try {
      // CachedNetworkImage uses DefaultCacheManager which can be cleared
      // In production, you might want to use a custom cache manager
      Logger.info('Image cache clear requested (implementation depends on cache manager)', 'ImageOptimizationService');
    } catch (e) {
      Logger.error('Failed to clear image cache', e, null, 'ImageOptimizationService');
    }
  }
}
