import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_zh_layout_policy.dart';

void main() {
  group('ReaderZhLayoutPolicy', () {
    const policy = ReaderZhLayoutPolicy();

    test('keeps line-start punctuation off the next line', () {
      const text = '你好，世界';
      final end = policy.adjustBreakOffset(
        text: text,
        start: 0,
        proposedEnd: 2,
      );

      expect(end, 1);
      expect(text[end], isNot('，'));
    });

    test('avoids splitting ascii words when possible', () {
      const text = '中文 abcdef 继续';
      final end = policy.adjustBreakOffset(
        text: text,
        start: 0,
        proposedEnd: 6,
      );

      expect(text.substring(0, end), '中文 ');
    });

    test('uses public punctuation fixture with layout engine', () async {
      final fixture =
          File(
            'test/fixtures/reader/zh_layout_punctuation_fixture.txt',
          ).readAsStringSync();

      final result = await const ReaderLayoutEngine().layout(
        ReaderLayoutRequest.fromParagraphs(
          chapterId: 'chapter-zh',
          chapterIndex: 0,
          paragraphs: <String>[fixture],
          spec: _spec,
          documentFingerprint: 'fixture-zh',
        ),
      );

      expect(result, isNotNull);
      for (final line in result!.pages.expand((page) => page.lines)) {
        if (line.text.isEmpty) {
          continue;
        }
        expect(policy.isLineStartProhibited(line.text[0]), isFalse);
      }
    });
  });
}

const _spec = ReaderLayoutSpec(
  contentWidth: 54,
  contentHeight: 120,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 18,
  lineHeight: 1,
  paragraphSpacing: 2,
  paragraphIndent: 0,
  letterSpacing: 0,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
  useZhLayout: true,
);
