import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  group('Reader experience baseline', () {
    const layoutResolver = ReaderLayoutResolver();
    const specResolver = ReaderPaginationSpecResolver();

    test('background changes do not affect pagination spec content area', () {
      const baseSettings = ReaderSettings(
        bodyMarginTop: 18,
        bodyMarginBottom: 20,
        bodyMarginLeft: 16,
        bodyMarginRight: 24,
      );
      const themedSettings = ReaderSettings(
        bodyMarginTop: 18,
        bodyMarginBottom: 20,
        bodyMarginLeft: 16,
        bodyMarginRight: 24,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
        backgroundImageBase64: 'reader_bg',
      );

      final baseSurface = layoutResolver.resolveSurfaceMetrics(
        settings: baseSettings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );
      final themedSurface = layoutResolver.resolveSurfaceMetrics(
        settings: themedSettings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );

      final baseSpec = specResolver.resolve(
        settings: baseSettings,
        surfaceMetrics: baseSurface,
      );
      final themedSpec = specResolver.resolve(
        settings: themedSettings,
        surfaceMetrics: themedSurface,
      );

      expect(themedSpec.contentWidth, baseSpec.contentWidth);
      expect(themedSpec.contentHeight, baseSpec.contentHeight);
      expect(themedSpec.pagePaddingTop, baseSpec.pagePaddingTop);
      expect(themedSpec.pagePaddingBottom, baseSpec.pagePaddingBottom);
    });

    test(
      'logical position keeps approximate ratio when switching paged to scroll',
      () {
        final document = ReaderDocument(
          blocks: const [
            ReaderTitleBlock(text: '第一章'),
            ReaderTextBlock(text: '这是第一段正文。'),
            ReaderTextBlock(text: '这是第二段正文，用来模拟分页与滚动切换。'),
            ReaderTextBlock(text: '这是第三段正文。'),
          ],
        );
        final pagedPosition = ReaderLogicalPosition.fromDocument(
          document: document,
          chapterIndex: 2,
          chapterPositionRatio: 0.58,
          pageIndex: 4,
        );
        final scrollPosition = pagedPosition.copyWith(clearPageIndex: true);

        expect(
          scrollPosition.approximateRatio(document),
          closeTo(pagedPosition.approximateRatio(document), 0.0001),
        );
        expect(scrollPosition.pageIndex, isNull);
      },
    );
  });
}
