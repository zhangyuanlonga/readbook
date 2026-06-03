import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_toc_snapshot.dart';

void main() {
  group('ReaderTocSnapshot', () {
    test('supports toJson and fromJson roundtrip', () {
      final snapshot = ReaderTocSnapshot(
        bookId: 'book_1',
        sourceId: 'source-a',
        detailUrl: 'https://example.com/book/1',
        title: '凡人修仙传',
        author: '忘语',
        coverUrl: 'https://example.com/cover.jpg',
        chapters: const <Chapter>[
          Chapter(
            id: 'chapter_1',
            bookId: 'book_1',
            title: '第一章',
            chapterUrl: 'https://example.com/book/1/ch1',
            index: 0,
          ),
        ],
        updatedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
      );

      final restored = ReaderTocSnapshot.fromJson(snapshot.toJson());

      expect(restored.bookId, snapshot.bookId);
      expect(restored.sourceId, snapshot.sourceId);
      expect(restored.title, snapshot.title);
      expect(restored.chapters, hasLength(1));
      expect(restored.chapters.first.id, 'chapter_1');
      expect(
        restored.updatedAt,
        DateTime.parse('2026-06-03T12:00:00.000Z'),
      );
    });

    test('falls back to empty chapter list when payload is missing chapters', () {
      final restored = ReaderTocSnapshot.fromJson(<String, dynamic>{
        'bookId': 'book_1',
        'sourceId': 'source-a',
        'detailUrl': 'https://example.com/book/1',
        'title': '凡人修仙传',
        'updatedAt': '2026-06-03T12:00:00.000Z',
      });

      expect(restored.chapters, isEmpty);
    });
  });
}
