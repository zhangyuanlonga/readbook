import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_content_loading_presenter.dart';

void main() {
  group('ReaderContentLoadingPresenter', () {
    const presenter = ReaderContentLoadingPresenter();
    const chapters = <Chapter>[
      Chapter(
        id: 'volume-1',
        bookId: 'book-1',
        title: '卷一',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter-1',
        bookId: 'book-1',
        title: '第一章',
        chapterUrl: 'chapter://1',
        index: 1,
      ),
      Chapter(
        id: 'chapter-2',
        bookId: 'book-1',
        title: '第二章',
        chapterUrl: 'chapter://2',
        index: 2,
      ),
    ];

    test('resolves next readable continuous chapter index', () {
      final target = presenter.resolveAdjacentContinuousChapterIndex(
        chapters: chapters,
        loadedChapterIndices: const <int>[1],
        forward: true,
      );

      expect(target, 2);
    });

    test('skips unreadable volume when resolving backward chapter index', () {
      final target = presenter.resolveAdjacentContinuousChapterIndex(
        chapters: chapters,
        loadedChapterIndices: const <int>[2],
        forward: false,
      );

      expect(target, 1);
    });
  });
}
