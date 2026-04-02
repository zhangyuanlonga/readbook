import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/reader/application/reader_chapter_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderChapterNavigation', () {
    const navigation = ReaderChapterNavigation();
    const chapters = <Chapter>[
      Chapter(
        id: 'volume_1',
        bookId: 'book_1',
        title: '第一卷',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 1,
      ),
      Chapter(
        id: 'volume_2',
        bookId: 'book_1',
        title: '第二卷',
        chapterUrl: '',
        index: 2,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/2',
        index: 3,
      ),
    ];

    test('filters readable chapters', () {
      final readable = navigation.readableChapters(chapters);

      expect(readable.map((item) => item.id), <String>[
        'chapter_1',
        'chapter_2',
      ]);
    });

    test('skips volume nodes when searching forward and backward', () {
      expect(
        navigation.findReadableChapterIndex(chapters, 0, forward: true),
        1,
      );
      expect(
        navigation.findReadableChapterIndex(chapters, 2, forward: false),
        1,
      );
    });

    test('resolves nearest readable chapter index around volume nodes', () {
      expect(
        navigation.resolveNearestReadableChapterIndex(
          chapters,
          2,
          preferForward: true,
        ),
        3,
      );
      expect(
        navigation.resolveNearestReadableChapterIndex(
          chapters,
          2,
          preferForward: false,
        ),
        1,
      );
    });
  });
}
