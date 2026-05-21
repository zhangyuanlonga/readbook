import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderPaginationEngine', () {
    const engine = ReaderPaginationEngine();
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

    test('buildEnsurePlan reuses existing pages for unchanged signature', () {
      final plan = engine.buildEnsurePlan(
        const ReaderPaginationEnsureRequest(
          spec: spec,
          signature: 'chapter-a|sig',
          currentState: ReaderPaginationSessionState(
            signature: 'chapter-a|sig',
          ),
          hasExistingPages: true,
          currentProgressRatio: 0.42,
        ),
      );

      expect(plan.decision, ReaderPaginationEnsureDecision.reuseExistingPages);
      expect(plan.preservedRatio, closeTo(0.42, 0.0001));
    });

    test(
      'paginateParagraphs returns paged slices for text paragraphs',
      () async {
        final result = await engine.paginateParagraphs(
          ReaderPaginationRequest(
            paragraphs: <String>['第一段正文 ' * 40, '第二段正文 ' * 36],
            spec: spec,
            paragraphStyle: const TextStyle(fontSize: 18, height: 1.72),
          ),
        );

        expect(result, isNotNull);
        expect(result!.pages, isNotEmpty);
        expect(result.pages.first, isNotEmpty);
        expect(result.pages.first.first.paragraphIndex, 0);
      },
    );

    test(
      'paragraph models can force repagination with custom spacing',
      () async {
        const compactSpec = ReaderPaginationSpec(
          contentWidth: 320,
          contentHeight: 40,
          contentRectLeft: 18,
          contentRectTop: 18,
          pagePaddingTop: 18,
          pagePaddingRight: 18,
          pagePaddingBottom: 18,
          pagePaddingLeft: 18,
          pinnedHeaderHeight: 40,
          paragraphSpacing: 0,
          paragraphIndent: 0,
          lineHeight: 1.2,
          fontSize: 10,
          letterSpacing: 0,
          textFullJustifyEnabled: false,
          bodyTextItalicEnabled: false,
          fontWeightLevel: ReaderFontWeightLevel.regular,
          fontWeightValue: null,
          fontSource: ReaderFontSource.system,
          systemFontPreset: ReaderSystemFontPreset.defaultSans,
          fontFamilyKey: null,
        );

        final baseline = await engine.paginateParagraphs(
          ReaderPaginationRequest(
            paragraphs: const <String>['甲', '乙'],
            spec: compactSpec,
            paragraphStyle: const TextStyle(fontSize: 10, height: 1.2),
          ),
        );
        final styled = await engine.paginateParagraphs(
          ReaderPaginationRequest(
            paragraphs: const <String>['甲', '乙'],
            spec: compactSpec,
            paragraphStyle: const TextStyle(fontSize: 10, height: 1.2),
            paragraphModels: const <ReaderPaginationParagraph>[
              ReaderPaginationParagraph(
                text: '甲',
                paragraphStyle: TextStyle(fontSize: 10, height: 1.2),
                spacingAfter: 20,
              ),
              ReaderPaginationParagraph(
                text: '乙',
                paragraphStyle: TextStyle(fontSize: 10, height: 1.2),
              ),
            ],
          ),
        );

        expect(baseline, isNotNull);
        expect(styled, isNotNull);
        expect(baseline!.pages, hasLength(1));
        expect(styled!.pages, hasLength(2));
      },
    );

    test(
      'paginateParagraphs keeps working when yielding aggressively',
      () async {
        final result = await engine.paginateParagraphs(
          ReaderPaginationRequest(
            paragraphs: <String>['测试正文 ' * 320],
            spec: spec,
            paragraphStyle: const TextStyle(fontSize: 18, height: 1.72),
            yieldInterval: Duration.zero,
          ),
        );

        expect(result, isNotNull);
        expect(result!.pages.length, greaterThan(1));
        expect(result.pages.first, isNotEmpty);
      },
    );

    test(
      'paginateParagraphs keeps working for very long paragraphs with default yield policy',
      () async {
        final result = await engine.paginateParagraphs(
          ReaderPaginationRequest(
            paragraphs: <String>['超长正文 ' * 2400],
            spec: spec,
            paragraphStyle: const TextStyle(fontSize: 18, height: 1.72),
          ),
        );

        expect(result, isNotNull);
        expect(result!.pages.length, greaterThan(1));
      },
    );
  });
}
