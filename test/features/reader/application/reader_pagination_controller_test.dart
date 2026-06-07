import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  group('ReaderPaginationController', () {
    const controller = ReaderPaginationController();
    const spec = ReaderPaginationSpec(
      contentWidth: 320,
      contentHeight: 480,
      contentRectLeft: 18,
      contentRectTop: 18,
      pagePaddingTop: 18,
      pagePaddingRight: 18,
      pagePaddingBottom: 18,
      pagePaddingLeft: 18,
      pinnedHeaderHeight: 40,
      paragraphSpacing: 12,
      paragraphIndent: 2,
      lineHeight: 1.72,
      fontSize: 18,
      letterSpacing: 0.02,
      textFullJustifyEnabled: false,
      bodyTextItalicEnabled: false,
      fontWeightLevel: ReaderFontWeightLevel.regular,
      fontWeightValue: null,
      fontSource: ReaderFontSource.system,
      systemFontPreset: ReaderSystemFontPreset.defaultSans,
      fontFamilyKey: null,
    );

    test('builds stable signature through pagination resolver', () {
      final first = controller.buildSignature(
        chapterId: 'chapter-1',
        spec: spec,
      );
      final second = controller.buildSignature(
        chapterId: 'chapter-1',
        spec: spec,
      );

      expect(first, second);
      expect(first, contains('chapter-1'));
    });

    test('reuses existing pages for unchanged signature', () {
      final signature = controller.buildSignature(
        chapterId: 'chapter-1',
        spec: spec,
      );
      final plan = controller.buildEnsurePlan(
        spec: spec,
        chapterId: 'chapter-1',
        currentState: ReaderPaginationSessionState(signature: signature),
        hasExistingPages: true,
        currentProgressRatio: 0.42,
      );

      expect(plan.decision, ReaderPaginationEnsureDecision.reuseExistingPages);
      expect(plan.preservedRatio, closeTo(0.42, 0.0001));
    });

    test('skips invalid viewport before pagination', () {
      const invalidSpec = ReaderPaginationSpec(
        contentWidth: 10,
        contentHeight: 20,
        contentRectLeft: 0,
        contentRectTop: 0,
        pagePaddingTop: 0,
        pagePaddingRight: 0,
        pagePaddingBottom: 0,
        pagePaddingLeft: 0,
        pinnedHeaderHeight: 0,
        paragraphSpacing: 12,
        paragraphIndent: 2,
        lineHeight: 1.72,
        fontSize: 18,
        letterSpacing: 0.02,
        textFullJustifyEnabled: false,
        bodyTextItalicEnabled: false,
        fontWeightLevel: ReaderFontWeightLevel.regular,
        fontWeightValue: null,
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
        fontFamilyKey: null,
      );

      final plan = controller.buildEnsurePlan(
        spec: invalidSpec,
        chapterId: 'chapter-1',
        currentState: const ReaderPaginationSessionState(),
        hasExistingPages: false,
        currentProgressRatio: 0.8,
      );

      expect(plan.decision, ReaderPaginationEnsureDecision.skipInvalidViewport);
      expect(plan.shouldPaginate, isFalse);
    });
  });
}
