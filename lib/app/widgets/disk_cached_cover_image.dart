import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache/cover_image_disk_cache.dart';

class DiskCachedCoverImage extends StatelessWidget {
  const DiskCachedCoverImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String? imageUrl;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = (imageUrl ?? '').trim();
    if (normalizedUrl.isEmpty) {
      return fallback;
    }

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      cacheKey: normalizedUrl,
      cacheManager: CoverImageDiskCache.instance.cacheManager,
      httpHeaders: CoverImageDiskCache.defaultHttpHeaders,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
