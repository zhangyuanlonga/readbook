import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  group('ReaderPaginationSpecResolver', () {
    const layoutResolver = ReaderLayoutResolver();
    const resolver = ReaderPaginationSpecResolver();

    test('derives pagination spec from stable content rect and typography', () {
      const settings = ReaderSettings(
        fontSize: 19,
        lineHeight: 1.82,
        paragraphSpacing: 16,
        paragraphIndent: 2,
        letterSpacing: 0.08,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        fontSource: ReaderFontSource.custom,
        fontFamilyKey: 'reader_custom_font',
        bodyMarginMode: ReaderBodyMarginMode.custom,
        bodyMarginTop: 18,
        bodyMarginBottom: 20,
        bodyMarginLeft: 16,
        bodyMarginRight: 24,
      );

      final surfaceMetrics = layoutResolver.resolveSurfaceMetrics(
        settings: settings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );
      final spec = resolver.resolve(
        settings: settings,
        surfaceMetrics: surfaceMetrics,
      );

      expect(spec.contentWidth, 350);
      expect(spec.contentHeight, 640);
      expect(spec.contentRectLeft, 16);
      expect(spec.contentRectTop, 70);
      expect(spec.pagePaddingTop, 18);
      expect(spec.pagePaddingBottom, 20);
      expect(spec.fontSize, 19);
      expect(spec.lineHeight, 1.82);
      expect(spec.paragraphSpacing, 16);
      expect(spec.paragraphIndent, 2);
      expect(spec.letterSpacing, closeTo(0.08, 0.0001));
      expect(spec.textFullJustifyEnabled, isFalse);
      expect(spec.bodyTextItalicEnabled, isFalse);
      expect(spec.fontWeightLevel, ReaderFontWeightLevel.medium);
      expect(spec.fontWeightValue, isNull);
      expect(spec.fontSource, ReaderFontSource.custom);
      expect(spec.systemFontPreset, ReaderSystemFontPreset.defaultSans);
      expect(spec.fontFamilyKey, 'reader_custom_font');
    });

    test(
      'builds signature from pagination spec and changes with surface metrics',
      () {
        const settings = ReaderSettings(
          bodyMarginMode: ReaderBodyMarginMode.custom,
          bodyMarginTop: 18,
          bodyMarginBottom: 20,
          bodyMarginLeft: 16,
          bodyMarginRight: 24,
        );

        final baseSurface = layoutResolver.resolveSurfaceMetrics(
          settings: settings,
          viewportSize: const Size(390, 844),
          safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
          pinnedHeaderHeight: 52,
          scrollBottomReserve: 14,
          pagedBottomReserve: 96,
        );
        final footerChangedSurface = layoutResolver.resolveSurfaceMetrics(
          settings: settings,
          viewportSize: const Size(390, 844),
          safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
          pinnedHeaderHeight: 52,
          scrollBottomReserve: 14,
          pagedBottomReserve: 120,
        );

        final baseSpec = resolver.resolve(
          settings: settings,
          surfaceMetrics: baseSurface,
        );
        final footerChangedSpec = resolver.resolve(
          settings: settings,
          surfaceMetrics: footerChangedSurface,
        );

        final baseSignature = resolver.buildSignature(
          chapterId: 'chapter_1',
          spec: baseSpec,
        );
        final footerChangedSignature = resolver.buildSignature(
          chapterId: 'chapter_1',
          spec: footerChangedSpec,
        );

        expect(baseSignature, isNot(equals(footerChangedSignature)));
      },
    );

    test('signature changes with font preset and exact font weight', () {
      const baseSettings = ReaderSettings(
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
        fontWeightLevel: ReaderFontWeightLevel.regular,
      );
      const changedSettings = ReaderSettings(
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.serif,
        fontWeightLevel: ReaderFontWeightLevel.regular,
        fontWeightValue: 650,
        bodyTextItalicEnabled: true,
      );

      final baseSurface = layoutResolver.resolveSurfaceMetrics(
        settings: baseSettings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );
      final changedSurface = layoutResolver.resolveSurfaceMetrics(
        settings: changedSettings,
        viewportSize: const Size(390, 844),
        safeInsets: const EdgeInsets.only(top: 12, bottom: 18),
        pinnedHeaderHeight: 52,
        scrollBottomReserve: 14,
        pagedBottomReserve: 96,
      );

      final baseSignature = resolver.buildSignature(
        chapterId: 'chapter_2',
        spec: resolver.resolve(
          settings: baseSettings,
          surfaceMetrics: baseSurface,
        ),
      );
      final changedSignature = resolver.buildSignature(
        chapterId: 'chapter_2',
        spec: resolver.resolve(
          settings: changedSettings,
          surfaceMetrics: changedSurface,
        ),
      );

      expect(baseSignature, isNot(equals(changedSignature)));
    });
  });
}
