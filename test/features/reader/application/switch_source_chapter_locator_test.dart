import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/reader/application/switch_source_chapter_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwitchSourceChapterLocator', () {
    const locator = SwitchSourceChapterLocator();

    Chapter chapter(int index, String title) {
      return Chapter(
        id: 'c$index',
        bookId: 'book_1',
        title: title,
        chapterUrl: 'https://example.com/$index',
        index: index,
      );
    }

    test('prefers exact title match over partial match', () {
      final chapters = <Chapter>[
        chapter(0, '第12章 山海（上）'),
        chapter(1, '第12章 山海'),
        chapter(2, '第13章 启程'),
      ];

      final targetIndex = locator.resolveTargetChapterIndex(
        chapters: chapters,
        previousChapterTitle: '第12章  山海',
        previousChapterIndex: 0,
      );

      expect(targetIndex, 1);
    });

    test('falls back to clamped previous index when no title match', () {
      final chapters = <Chapter>[chapter(0, '第一章 开端'), chapter(1, '第二章 深入')];

      final targetIndex = locator.resolveTargetChapterIndex(
        chapters: chapters,
        previousChapterTitle: '第八章 终局',
        previousChapterIndex: 10,
      );

      expect(targetIndex, 1);
    });

    test('falls back to zero when no match and previous index is null', () {
      final chapters = <Chapter>[chapter(0, '第一章 开端'), chapter(1, '第二章 深入')];

      final targetIndex = locator.resolveTargetChapterIndex(
        chapters: chapters,
        previousChapterTitle: null,
        previousChapterIndex: null,
      );

      expect(targetIndex, 0);
    });
  });
}
