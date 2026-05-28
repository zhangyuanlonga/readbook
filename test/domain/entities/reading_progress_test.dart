import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingProgress', () {
    test('supports toJson and fromJson with chapter position ratio', () {
      final progress = ReadingProgress(
        bookId: 'book_1',
        sourceId: 'src_1',
        detailUrl: 'https://example.com/book/1',
        chapterId: 'c_1',
        chapterUrl: 'https://example.com/book/1/c1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
        chapterPositionRatio: 0.42,
        logicalPosition: const ReaderLogicalPosition(
          chapterIndex: 0,
          blockIndex: 3,
          offsetInBlock: 10,
          chapterPositionRatio: 0.42,
          pageIndex: 2,
          totalPageCount: 8,
          viewportMode: 'textPaged',
        ),
        positionSnapshot: const ReaderPositionSnapshot(
          viewportMode: 'textPaged',
          pageIndex: 2,
          pageCount: 8,
        ),
      );

      final json = progress.toJson();
      final restored = ReadingProgress.fromJson(json);

      expect(restored.bookId, progress.bookId);
      expect(restored.chapterTitle, progress.chapterTitle);
      expect(restored.chapterPositionRatio, 0.42);
      expect(restored.logicalPosition, isNotNull);
      expect(restored.logicalPosition!.blockIndex, 3);
      expect(restored.logicalPosition!.pageIndex, 2);
      expect(restored.logicalPosition!.totalPageCount, 8);
      expect(restored.positionSnapshot, isNotNull);
      expect(restored.positionSnapshot!.viewportMode, 'textPaged');
      expect(restored.positionSnapshot!.pageCount, 8);
    });

    test('preserves audio snapshot fields through json roundtrip', () {
      final progress = ReadingProgress(
        bookId: 'book_audio',
        sourceId: 'src_audio',
        detailUrl: 'https://example.com/book/audio',
        chapterId: 'chapter_audio',
        chapterUrl: 'https://example.com/book/audio/chapter',
        chapterTitle: '听书章节',
        chapterIndex: 3,
        updatedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
        chapterPositionRatio: 0.25,
        positionSnapshot: const ReaderPositionSnapshot(
          viewportMode: 'audio',
          audioPositionMs: 32000,
          audioDurationMs: 180000,
          audioSpeed: 1.5,
        ),
      );

      final restored = ReadingProgress.fromJson(progress.toJson());

      expect(restored.positionSnapshot, isNotNull);
      expect(restored.positionSnapshot!.viewportMode, 'audio');
      expect(restored.positionSnapshot!.audioPositionMs, 32000);
      expect(restored.positionSnapshot!.audioDurationMs, 180000);
      expect(restored.positionSnapshot!.audioSpeed, 1.5);
    });

    test('rejects legacy payload without chapter position ratio', () {
      expect(
        () => ReadingProgress.fromJson({
          'bookId': 'book_legacy',
          'sourceId': 'src_legacy',
          'detailUrl': 'https://example.com/book/legacy',
          'chapterId': 'c_1',
          'chapterUrl': 'https://example.com/book/legacy/c1',
          'chapterTitle': '第一章',
          'chapterIndex': 1,
          'updatedAt': '2026-02-12T12:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('clamps ratio into valid range', () {
      final restored = ReadingProgress.fromJson({
        'bookId': 'book_legacy',
        'sourceId': 'src_legacy',
        'detailUrl': 'https://example.com/book/legacy',
        'chapterId': 'c_1',
        'chapterUrl': 'https://example.com/book/legacy/c1',
        'chapterTitle': '第一章',
        'chapterIndex': 1,
        'updatedAt': '2026-02-12T12:00:00.000Z',
        'chapterPositionRatio': 1.9,
      });

      expect(restored.chapterPositionRatio, 1);
    });
  });
}
