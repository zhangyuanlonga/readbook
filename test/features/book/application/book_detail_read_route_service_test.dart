import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_read_route_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';

void main() {
  group('BookDetailReadRouteService', () {
    final service = BookDetailReadRouteService(
      readerEntryRouteResolver: const ReaderEntryRouteResolver(),
    );

    test('filters readable chapters and resolves latest readable chapter', () {
      final chapters = <Chapter>[
        const Chapter(
          id: 'volume_1',
          bookId: 'book_1',
          title: '卷一',
          chapterUrl: '',
          index: 0,
          isVolume: true,
        ),
        const Chapter(
          id: 'chapter_1',
          bookId: 'book_1',
          title: '第一章',
          chapterUrl: 'https://reader.test/1',
          index: 1,
        ),
        const Chapter(
          id: 'chapter_2',
          bookId: 'book_1',
          title: '第二章',
          chapterUrl: 'https://reader.test/2',
          index: 2,
        ),
      ];

      expect(service.readableChapters(chapters), hasLength(2));
      expect(service.latestReadableChapter(chapters)?.id, 'chapter_2');
    });

    test('returns null route when chapter is not readable', () {
      const chapter = Chapter(
        id: 'volume_1',
        bookId: 'book_1',
        title: '卷一',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      );

      final route = service.buildChapterRoute(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://detail.test/book-1',
        chapter: chapter,
      );

      expect(route, isNull);
    });

    test('builds reader route for readable chapter', () {
      const chapter = Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://reader.test/1',
        index: 0,
      );

      final route = service.buildChapterRoute(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://detail.test/book-1',
        chapter: chapter,
      );

      expect(route, contains('/reader/book_1/chapter_1'));
    });
  });
}
