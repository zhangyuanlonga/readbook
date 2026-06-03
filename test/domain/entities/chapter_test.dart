import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';

void main() {
  group('Chapter', () {
    test('supports toJson and fromJson roundtrip', () {
      const chapter = Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/book/1/ch1',
        index: 0,
        executionContext: 'server',
      );

      final restored = Chapter.fromJson(chapter.toJson());

      expect(restored.id, chapter.id);
      expect(restored.bookId, chapter.bookId);
      expect(restored.title, chapter.title);
      expect(restored.chapterUrl, chapter.chapterUrl);
      expect(restored.index, 0);
      expect(restored.executionContext, 'server');
    });

    test('parses index from string and allows empty chapter url', () {
      final restored = Chapter.fromJson(<String, dynamic>{
        'id': 'chapter_1',
        'bookId': 'book_1',
        'title': '第一章',
        'chapterUrl': '   ',
        'index': '3',
        'isVolume': true,
      });

      expect(restored.chapterUrl, '');
      expect(restored.index, 3);
      expect(restored.isVolume, isTrue);
    });
  });
}
