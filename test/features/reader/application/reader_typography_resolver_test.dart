import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_typography_resolver.dart';

void main() {
  group('ReaderTypographyResolver', () {
    const resolver = ReaderTypographyResolver();

    test('uses system preset and italic style for body text', () {
      final style = resolver.resolveBodyStyle(
        settings: const ReaderSettings(
          fontSource: ReaderFontSource.system,
          systemFontPreset: ReaderSystemFontPreset.serif,
          bodyTextItalicEnabled: true,
        ),
        color: Colors.black,
      );

      expect(style.fontFamily, 'serif');
      expect(style.fontStyle, FontStyle.italic);
    });

    test('prefers exact font weight value over preset level', () {
      final style = resolver.resolveBodyStyle(
        settings: const ReaderSettings(
          fontWeightLevel: ReaderFontWeightLevel.light,
          fontWeightValue: 700,
        ),
        color: Colors.black,
      );

      expect(style.fontWeight, FontWeight.w700);
    });

    test('emits text shadow when enabled', () {
      final style = resolver.resolveBodyStyle(
        settings: const ReaderSettings(
          bodyTextShadowEnabled: true,
          bodyTextShadowColorValue: 0x88224466,
          bodyTextShadowBlurRadius: 12,
          bodyTextShadowOffsetDx: 2,
          bodyTextShadowOffsetDy: -1,
        ),
        color: Colors.black,
      );

      expect(style.shadows, isNotNull);
      expect(style.shadows, hasLength(1));
      expect(style.shadows!.first.color, const Color(0x88224466));
      expect(style.shadows!.first.blurRadius, 12);
      expect(style.shadows!.first.offset, const Offset(2, -1));
    });

    test('emits dashed underline with custom decoration color', () {
      final style = resolver.resolveBodyStyle(
        settings: const ReaderSettings(
          bodyTextDecorationStyle: ReaderBodyTextDecorationStyle.dashed,
          bodyTextDecorationColorValue: 0xFF3366CC,
          bodyTextUnderlineThickness: 3.5,
        ),
        color: Colors.black,
      );

      expect(style.decoration, TextDecoration.none);
      expect(style.decorationStyle, TextDecorationStyle.dashed);
      expect(style.decorationColor, const Color(0xFF3366CC));
      expect(style.decorationThickness, 3.5);
    });

    test('emits line height and letter spacing from typography settings', () {
      final style = resolver.resolveBodyStyle(
        settings: const ReaderSettings(
          fontSize: 20,
          lineHeight: 1.95,
          letterSpacing: 0.18,
        ),
        color: Colors.black,
      );

      expect(style.fontSize, 20);
      expect(style.height, 1.95);
      expect(style.letterSpacing, closeTo(0.18, 0.0001));
    });
  });
}
