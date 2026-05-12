import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_chapter_window_controller.dart';

void main() {
  group('ReaderChapterWindowController', () {
    const controller = ReaderChapterWindowController();
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
        id: 'volume-2',
        bookId: 'book-1',
        title: '卷二',
        chapterUrl: '',
        index: 2,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter-2',
        bookId: 'book-1',
        title: '第二章',
        chapterUrl: 'chapter://2',
        index: 3,
      ),
      Chapter(
        id: 'chapter-3',
        bookId: 'book-1',
        title: '第三章',
        chapterUrl: 'chapter://3',
        index: 4,
      ),
    ];

    test('builds prev/current/next window and skips volume nodes', () {
      final plan = controller.buildWindowPlan(
        chapters: chapters,
        currentChapterIndex: 3,
      );

      expect(plan, isNotNull);
      expect(plan!.previousChapterIndex, 1);
      expect(plan.currentChapterIndex, 3);
      expect(plan.nextChapterIndex, 4);
      expect(plan.indices, <int>[1, 3, 4]);
      expect(
        plan.chapterIndexFor(ReaderChapterSlot.previous),
        plan.previousChapterIndex,
      );
      expect(plan.slots.map((slot) => slot.slot), <ReaderChapterSlot>[
        ReaderChapterSlot.previous,
        ReaderChapterSlot.current,
        ReaderChapterSlot.next,
      ]);
      expect(
        plan.slots.map((slot) => slot.status),
        everyElement(ReaderChapterWindowStatus.ready),
      );
    });

    test('marks missing edge slots as empty', () {
      final plan = controller.buildWindowPlan(
        chapters: chapters,
        currentChapterIndex: 1,
      );

      expect(plan, isNotNull);
      expect(plan!.previousChapterIndex, isNull);
      expect(plan.slots.first.status, ReaderChapterWindowStatus.empty);
      expect(plan.slots[1].status, ReaderChapterWindowStatus.ready);
    });

    test('retains only chapters inside the active window', () {
      final retained = controller.retainWindow<int>(
        items: const <int>[0, 1, 3, 4, 9],
        chapterIndexOf: (item) => item,
        chapters: chapters,
        currentChapterIndex: 3,
      );

      expect(retained, <int>[1, 3, 4]);
    });

    test('inserts a loaded chapter and keeps the window bounded', () {
      final retained = controller.insertAndRetainWindow<int>(
        items: const <int>[1, 3],
        item: 4,
        chapterIndexOf: (item) => item,
        chapters: chapters,
        currentChapterIndex: 3,
      );

      expect(retained, <int>[1, 3, 4]);
    });

    test('rejects loaded chapters outside the active window', () {
      expect(
        controller.shouldAcceptLoadedChapter(
          loadedChapterIndex: 0,
          chapters: chapters,
          currentChapterIndex: 3,
        ),
        isFalse,
      );
      expect(
        controller.shouldAcceptLoadedChapter(
          loadedChapterIndex: 4,
          chapters: chapters,
          currentChapterIndex: 3,
        ),
        isTrue,
      );
    });

    test('resolves unloaded adjacent chapter inside the window', () {
      final next = controller.resolveAdjacentLoadIndex(
        chapters: chapters,
        loadedChapterIndices: const <int>[3],
        currentChapterIndex: 3,
        forward: true,
      );
      final previous = controller.resolveAdjacentLoadIndex(
        chapters: chapters,
        loadedChapterIndices: const <int>[3],
        currentChapterIndex: 3,
        forward: false,
      );

      expect(next, 4);
      expect(previous, 1);
    });

    test('builds move plan with reusable, entering, and leaving chapters', () {
      final move = controller.buildMovePlan(
        chapters: chapters,
        previousCurrentChapterIndex: 3,
        nextCurrentChapterIndex: 4,
      );

      expect(move.from?.indices, <int>[1, 3, 4]);
      expect(move.to?.indices, <int>[3, 4]);
      expect(move.reusableChapterIndexes, <int>[3, 4]);
      expect(move.enteringChapterIndexes, isEmpty);
      expect(move.leavingChapterIndexes, <int>[1]);
      expect(move.hasReusableCurrent, isTrue);
    });

    test('resolves stale loaded chapters outside the window', () {
      final stale = controller.resolveStaleLoadedChapterIndexes(
        loadedChapterIndices: const <int>[0, 1, 3, 4, 9],
        chapters: chapters,
        currentChapterIndex: 3,
      );

      expect(stale, <int>[0, 9]);
    });
  });
}
