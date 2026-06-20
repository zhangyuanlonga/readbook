import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_document_render_model.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_text_block_presentation.dart';

void main() {
  group('resolveReaderTextBlockPresentation', () {
    test('formats paragraph with indent and justify setting', () {
      final resolved = resolveReaderTextBlockPresentation(
        settings: const ReaderSettings(
          paragraphIndent: 2,
          textFullJustifyEnabled: true,
        ),
        primaryTextColor: Colors.black,
        secondaryTextColor: Colors.grey,
        item: const ReaderRenderTextItem(
          text: '正文',
          kind: ReaderRenderTextKind.paragraph,
          paragraphIndex: 0,
        ),
        isLast: false,
      );

      expect(resolved.displayText, '　　正文');
      expect(resolved.indentLength, 2);
      expect(resolved.textAlign, TextAlign.justify);
      expect(resolved.spacingAfter, closeTo(6.012, 0.001));
    });

    test('formats title and footnote with dedicated semantics', () {
      final title = resolveReaderTextBlockPresentation(
        settings: const ReaderSettings(),
        primaryTextColor: Colors.black,
        secondaryTextColor: Colors.grey,
        item: const ReaderRenderTextItem(
          text: '第一章',
          kind: ReaderRenderTextKind.title,
          paragraphIndex: 0,
        ),
        isLast: false,
      );
      final footnote = resolveReaderTextBlockPresentation(
        settings: const ReaderSettings(),
        primaryTextColor: Colors.black,
        secondaryTextColor: Colors.grey,
        item: const ReaderRenderTextItem(
          text: '脚注内容',
          kind: ReaderRenderTextKind.footnote,
          paragraphIndex: 1,
        ),
        isLast: true,
      );

      expect(title.displayText, '第一章');
      expect(title.textStyle.fontWeight, FontWeight.w800);
      expect(title.spacingAfter, 12);
      expect(footnote.displayText, '注: 脚注内容');
      expect(footnote.textAlign, TextAlign.start);
      expect(footnote.spacingAfter, 0);
    });
  });
}
