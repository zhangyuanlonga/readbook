import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/disk_cached_cover_image.dart';
import 'package:shuxiang_reading_next/core/cache/cover_image_disk_cache.dart';

void main() {
  testWidgets('falls back immediately when cover url is empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DiskCachedCoverImage(
            imageUrl: ' ',
            fallback: Text('fallback-cover'),
          ),
        ),
      ),
    );

    expect(find.text('fallback-cover'), findsOneWidget);
  });

  testWidgets('uses cached network image with the shared cache manager', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DiskCachedCoverImage(
            imageUrl: 'https://example.com/cover.jpg',
            fallback: Text('fallback-cover'),
            width: 80,
            height: 120,
            cacheWidth: 160,
            cacheHeight: 240,
          ),
        ),
      ),
    );

    final widget = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      widget.cacheManager,
      same(CoverImageDiskCache.instance.cacheManager),
    );
    expect(widget.httpHeaders, CoverImageDiskCache.defaultHttpHeaders);
    expect(widget.memCacheWidth, 160);
    expect(widget.memCacheHeight, 240);
  });
}
