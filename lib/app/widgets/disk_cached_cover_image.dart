import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../composition/app_providers.dart';
import '../../core/cache/cover_image_disk_cache.dart';

class DiskCachedCoverImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedUrl = (imageUrl ?? '').trim();
    if (normalizedUrl.isEmpty) {
      return fallback;
    }

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      cacheKey: normalizedUrl,
      cacheManager: ref.watch(appCoverImageDiskCacheProvider).cacheManager,
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
