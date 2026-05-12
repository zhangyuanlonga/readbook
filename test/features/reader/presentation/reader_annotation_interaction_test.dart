import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/reader/presentation/reader_annotated_text.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_annotation_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveTappedAnnotationRange', () {
    test('returns smallest overlapping annotation at tap position', () {
      const textStyle = TextStyle(fontSize: 18, height: 1.6);
      final result = resolveTappedAnnotationRange(
        ranges: const <ReaderTextAnnotationRange>[
          ReaderTextAnnotationRange(
            0,
            4,
            hasHighlight: true,
            isBold: false,
            isUnderline: false,
            isWavy: false,
          ),
          ReaderTextAnnotationRange(
            1,
            2,
            hasHighlight: true,
            isBold: true,
            isUnderline: false,
            isWavy: false,
          ),
        ],
        displayText: '测试文本',
        indentLength: 0,
        rawTextLength: 4,
        localPosition: const Offset(24, 8),
        maxWidth: 300,
        textStyle: textStyle,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
      );

      expect(result, isNotNull);
      expect(result!.start, 1);
      expect(result.end, 2);
      expect(result.isBold, isTrue);
    });

    test('accounts for paragraph indent when mapping display offsets', () {
      const textStyle = TextStyle(fontSize: 18, height: 1.6);
      final result = resolveTappedAnnotationRange(
        ranges: const <ReaderTextAnnotationRange>[
          ReaderTextAnnotationRange(
            0,
            1,
            hasHighlight: true,
            isBold: false,
            isUnderline: true,
            isWavy: false,
          ),
        ],
        displayText: '　　正文',
        indentLength: 2,
        rawTextLength: 2,
        localPosition: const Offset(36, 8),
        maxWidth: 300,
        textStyle: textStyle,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
      );

      expect(result, isNotNull);
      expect(result!.start, 0);
      expect(result.end, 1);
    });
  });
}
