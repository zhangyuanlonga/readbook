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
            borderRadius: BorderRadius.all(Radius.circular(8)),
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
    expect(widget.width, 80);
    expect(widget.height, 120);
    expect(widget.memCacheWidth, 160);
    expect(widget.memCacheHeight, 240);
    expect(widget.fadeInDuration, Duration.zero);
    expect(widget.fadeOutDuration, Duration.zero);

    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byType(CachedNetworkImage),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(8)));

    final element = tester.element(find.byType(CachedNetworkImage));
    final placeholder = widget.placeholder!(
      element,
      'https://example.com/cover.jpg',
    );
    final error = widget.errorWidget!(
      element,
      'https://example.com/cover.jpg',
      Exception('load failed'),
    );

    expect(placeholder, isA<Text>());
    expect((placeholder as Text).data, 'fallback-cover');
    expect(error, isA<Text>());
    expect((error as Text).data, 'fallback-cover');
  });
}
