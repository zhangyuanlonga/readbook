import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_resolver.dart';

void main() {
  group('ReaderLayoutResolver', () {
    const resolver = ReaderLayoutResolver();

    test('derives paged layout metrics from clamped settings', () {
      const settings = ReaderSettings(
        bodyMarginMode: ReaderBodyMarginMode.custom,
        bodyMarginTop: 52,
        bodyMarginBottom: -4,
        bodyMarginLeft: 12,
        bodyMarginRight: 44,
        infoHeaderMarginTop: -5,
        infoHeaderMarginBottom: 5,
        infoHeaderMarginLeft: 50,
        infoHeaderMarginRight: 6,
        infoFooterMarginTop: 2,
        infoFooterMarginBottom: 60,
        infoFooterMarginLeft: 4,
        infoFooterMarginRight: -2,
      );

      final metrics = resolver.resolvePagedMetrics(
        settings: settings,
        viewportSize: const Size(400, 800),
        safeInsets: const EdgeInsets.only(top: 18, bottom: 16),
        pinnedHeaderHeight: 46,
        bottomProgressReserve: 24,
      );

      expect(metrics.bodyPadding, const EdgeInsets.fromLTRB(12, 40, 40, 0));
      expect(metrics.headerPadding, const EdgeInsets.fromLTRB(40, 0, 6, 5));
      expect(metrics.footerPadding, const EdgeInsets.fromLTRB(4, 2, 0, 40));
      expect(
        metrics.effectivePagePadding,
        const EdgeInsets.fromLTRB(12, 40, 40, 0),
      );
      expect(metrics.pagedHeaderReserve, 0);
      expect(metrics.pagedFooterReserve, 40);
      expect(metrics.contentWidth, 348);
      expect(metrics.contentHeight, 674);
    });

    test('builds scroll body padding with safe bottom and extra reserve', () {
      const settings = ReaderSettings(
        bodyMarginMode: ReaderBodyMarginMode.custom,
        bodyMarginTop: 10,
        bodyMarginBottom: 12,
        bodyMarginLeft: 14,
        bodyMarginRight: 16,
      );

      final padding = resolver.resolveScrollableBodyPadding(
        settings: settings,
        safeInsets: const EdgeInsets.only(bottom: 20),
        extraBottomPadding: 96,
      );

      expect(padding, const EdgeInsets.fromLTRB(14, 10, 16, 128));
    });

    test('resolves unified surface metrics for scroll and paged layouts', () {
      const settings = ReaderSettings(
        bodyMarginMode: ReaderBodyMarginMode.custom,
        bodyMarginTop: 18,
        bodyMarginBottom: 20,
        bodyMarginLeft: 16,
        bodyMarginRight: 24,
        infoHeaderMarginTop: 4,
        infoHeaderMarginBottom: 6,
        infoHeaderMarginLeft: 8,
        infoHeaderMarginRight: 10,
        infoFooterMarginTop: 3,
        infoFooterMarginBottom: 5,
        infoFooterMarginLeft: 7,
        infoFooterMarginRight: 9,
      );

      final metrics = resolver.resolveSurfaceMetrics(
        settings: settings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );

      expect(metrics.bodyPadding, const EdgeInsets.fromLTRB(16, 18, 24, 20));
      expect(metrics.headerPadding, const EdgeInsets.fromLTRB(8, 4, 10, 6));
      expect(metrics.footerPadding, const EdgeInsets.fromLTRB(7, 3, 9, 5));
      expect(
        metrics.scrollBodyPadding,
        const EdgeInsets.fromLTRB(16, 18, 24, 52),
      );
      expect(
        metrics.effectivePagePadding,
        const EdgeInsets.fromLTRB(16, 18, 24, 20),
      );
      expect(metrics.pagedHeaderReserve, 0);
      expect(metrics.pagedFooterReserve, 114);
      expect(metrics.contentWidth, 350);
      expect(metrics.contentHeight, 640);
      expect(metrics.contentRect, const Rect.fromLTWH(16, 70, 350, 640));
    });
  });
}
