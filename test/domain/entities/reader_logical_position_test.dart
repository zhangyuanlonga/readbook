import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderLogicalPosition', () {
    final document = ReaderDocument(
      blocks: const [
        ReaderTitleBlock(text: '第一章'),
        ReaderTextBlock(text: '这是一段正文'),
        ReaderImageBlock(imageUrl: 'https://example.com/1.png'),
        ReaderTextBlock(text: '这一段正文更长一些，用来测试块内偏移恢复。'),
      ],
    );

    test('roundtrips ratio against document blocks', () {
      for (final ratio in <double>[0.0, 0.2, 0.5, 0.8, 1.0]) {
        final position = ReaderLogicalPosition.fromDocument(
          document: document,
          chapterIndex: 2,
          chapterPositionRatio: ratio,
        );

        expect(position.chapterIndex, 2);
        expect(position.approximateRatio(document), closeTo(ratio, 0.08));
      }
    });

    test('uses fallback ratio when document is empty', () {
      const position = ReaderLogicalPosition(
        chapterIndex: 1,
        blockIndex: 3,
        offsetInBlock: 9,
        chapterPositionRatio: 0.64,
      );

      expect(
        position.approximateRatio(ReaderDocument(blocks: const [])),
        closeTo(0.64, 0.0001),
      );
    });

    test('supports json serialization and page index clearing', () {
      final position = ReaderLogicalPosition.fromJson({
        'chapterIndex': 3,
        'blockIndex': 4,
        'offsetInBlock': 12,
        'chapterPositionRatio': 0.58,
        'pageIndex': 7,
      });

      expect(position.pageIndex, 7);
      expect(position.copyWith(clearPageIndex: true).pageIndex, isNull);
      expect(position.toJson()['blockIndex'], 4);
    });
  });
}
