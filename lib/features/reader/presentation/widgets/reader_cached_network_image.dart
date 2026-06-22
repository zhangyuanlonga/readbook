import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/cache/cover_image_disk_cache.dart';
import '../reader_icons.dart';

typedef ReaderCachedImagePlaceholder =
    Widget Function(BuildContext context, String url);

typedef ReaderCachedImageErrorBuilder =
    Widget Function(BuildContext context, String url, Object error);

enum ReaderCachedImageScope {
  readerContent,
  readerManga,
  readerThemeBackground,
}

class ReaderCachedNetworkImage extends StatelessWidget {
  const ReaderCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.scope = ReaderCachedImageScope.readerContent,
    this.cacheKey,
    this.headers = const <String, String>{},
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorBuilder,
    this.traceEnabled = true,
  });

  final String imageUrl;
  final ReaderCachedImageScope scope;
  final String? cacheKey;
  final Map<String, String> headers;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final ReaderCachedImagePlaceholder? placeholder;
  final ReaderCachedImageErrorBuilder? errorBuilder;
  final bool traceEnabled;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey ?? imageUrl,
      cacheManager: CoverImageDiskCache.instance.cacheManager,
      httpHeaders: headers.isEmpty ? null : headers,
      fit: fit,
      filterQuality: filterQuality,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      imageBuilder: (context, imageProvider) {
        _trace('success');
        return Image(
          image: imageProvider,
          fit: fit,
          filterQuality: filterQuality,
        );
      },
      placeholder: placeholder ?? _defaultPlaceholder,
      errorWidget: (context, url, error) {
        _trace('error', error: error);
        final builder = errorBuilder;
        if (builder != null) {
          return builder(context, url, error);
        }
        return _defaultErrorWidget(context);
      },
    );
  }

  Widget _defaultPlaceholder(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.errorContainer.withValues(alpha: 0.16),
      child: Icon(ReaderIcons.brokenImage, color: colorScheme.error),
    );
  }

  void _trace(String status, {Object? error}) {
    if (!traceEnabled) {
      return;
    }
    developer.Timeline.instantSync(
      'reader.image.cache',
      arguments: <String, Object?>{
        'status': status,
        'scope': scope.name,
        'url': imageUrl,
        'cacheKey': cacheKey ?? imageUrl,
        'hasHeaders': headers.isNotEmpty,
        if (cacheWidth != null) 'cacheWidth': cacheWidth,
        if (cacheHeight != null) 'cacheHeight': cacheHeight,
        if (error != null) 'error': error.toString(),
      },
    );
  }
}
