import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_catalog_search_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_navigation_entry_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_catalog_sheet.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_navigation_presenter.dart';

void main() {
  group('ReaderNavigationPresenter', () {
    const presenter = ReaderNavigationPresenter();
    const chapters = <Chapter>[
      Chapter(
        id: 'volume-1',
        bookId: 'book-1',
        title: '卷一',
        chapterUrl: 'chapter://volume-1',
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

    final bookmark = Bookmark(
      id: 'bookmark-1',
      bookId: 'book-1',
      chapterId: 'chapter-2',
      chapterIndex: 2,
      startOffset: 4,
      endOffset: 8,
      snippet: '高光片段',
      createdAt: DateTime(2026, 4, 26, 9),
      updatedAt: DateTime(2026, 4, 26, 9),
    );

    test('returns bookmark jump plan for catalog bookmark result', () {
      final plan = presenter.resolveCatalogResult(
        result: ReaderCatalogSheetResult.bookmark(bookmark),
        chapters: chapters,
        currentChapterIndex: 1,
      );

      expect(plan.message, isNull);
      expect(plan.resumeAutoReadOnRestore, isFalse);
      expect(plan.request?.type, ReaderNavigationRequestType.jumpBookmark);
      expect(plan.request?.targetChapterIndex, 2);
    });

    test('returns restore plan for same-chapter catalog selection', () {
      const logicalPosition = ReaderLogicalPosition(
        chapterIndex: 1,
        blockIndex: 0,
        offsetInBlock: 3,
        chapterPositionRatio: 0.35,
      );

      final plan = presenter.resolveCatalogResult(
        result: const ReaderCatalogSheetResult.selection(
          ReaderCatalogSheetSelection(
            chapterIndex: 1,
            logicalPosition: logicalPosition,
          ),
        ),
        chapters: chapters,
        currentChapterIndex: 1,
      );

      expect(plan.resumeAutoReadOnRestore, isTrue);
      expect(plan.request?.type, ReaderNavigationRequestType.restoreCurrent);
      expect(plan.request?.initialLogicalPosition, same(logicalPosition));
    });

    test('returns jumpChapter for unreadable volume search entry', () {
      final target = presenter.resolveCatalogSearchEntryTargetIndex(
        entry: const ReaderCatalogSearchEntry(
          title: '卷一',
          subtitle: '分卷',
          chapterIndex: 0,
          isVolume: true,
          targetChapterIndex: 1,
        ),
        chapters: chapters,
      );

      expect(target, 1);
    });

    test('builds manga position presentation for paged manga', () {
      final presentation = presenter.resolveMangaPositionPresentation(
        isMangaViewport: true,
        totalImageCount: 12,
        hasScrollClients: false,
        isPagedMode: true,
        currentScrollRatio: 0.42,
        currentPageIndex: 4,
      );

      expect(presentation, isNotNull);
      expect(presentation?.chapterLabel, '第 5 / 12 张');
      expect(presentation?.progressLabel, '42%');
      expect(presentation?.initialRatio, 0.42);
    });

    test('skips manga position presentation when viewport is unavailable', () {
      final presentation = presenter.resolveMangaPositionPresentation(
        isMangaViewport: false,
        totalImageCount: 1,
        hasScrollClients: false,
        isPagedMode: false,
        currentScrollRatio: 0.2,
        currentPageIndex: 0,
      );

      expect(presentation, isNull);
    });

    test(
      'executes restoreCurrent and schedules resume when requested',
      () async {
        final harness = _ExecutionHarness();

        await presenter.executeRequest(
          request: const ReaderNavigationRequest.restoreCurrent(
            scrollRatio: 0.4,
          ),
          snapshot: harness.snapshot,
          delegate: harness.delegate,
          resumeAutoReadOnRestore: true,
        );

        expect(harness.restoreCalls, hasLength(1));
        expect(harness.restoreCalls.single.scrollRatio, 0.4);
        expect(harness.autoReadResumeCount, 1);
        expect(harness.progressSaveCount, 0);
      },
    );

    test('executes bookmark jump and restores logical position', () async {
      final harness = _ExecutionHarness(
        chapterContent: '序章高光片段结尾',
        currentChapterIndex: 2,
        isPagedTextReaderEnabled: true,
        currentPageIndex: 3,
      );

      await presenter.executeRequest(
        request: ReaderNavigationRequest.jumpBookmark(
          bookmark: bookmark,
          targetChapterIndex: 2,
        ),
        snapshot: harness.snapshot,
        delegate: harness.delegate,
      );

      expect(harness.jumpCalls, hasLength(1));
      expect(harness.jumpCalls.single.chapterIndex, 2);
      expect(harness.jumpCalls.single.initialScrollRatio, 0);
      expect(harness.restoreCalls, hasLength(1));
      expect(harness.restoreCalls.single.logicalPosition, isNotNull);
      expect(harness.progressSaveCount, 1);
    });

    test('shows message when bookmark content is empty after jump', () async {
      final harness = _ExecutionHarness(chapterContent: '   ');

      await presenter.executeRequest(
        request: ReaderNavigationRequest.jumpBookmark(
          bookmark: bookmark,
          targetChapterIndex: 2,
        ),
        snapshot: harness.snapshot,
        delegate: harness.delegate,
      );

      expect(harness.jumpCalls, hasLength(1));
      expect(harness.restoreCalls, isEmpty);
      expect(harness.messages, ['章节内容为空，无法定位灵感。']);
    });
  });
}

class _ExecutionHarness {
  _ExecutionHarness({
    String chapterContent = '第一段\n第二段\n高光片段\n第四段',
    int? currentChapterIndex = 1,
    bool isPagedTextReaderEnabled = false,
    int currentPageIndex = 0,
    bool shouldContinue = true,
  }) : snapshot = ReaderNavigationExecutionSnapshot(
         chapterContent: chapterContent,
         document: ReaderDocument.fromContent(content: chapterContent),
         currentChapterIndex: currentChapterIndex,
         isPagedTextReaderEnabled: isPagedTextReaderEnabled,
         currentPageIndex: currentPageIndex,
       ),
       _shouldContinue = shouldContinue {
    delegate = ReaderNavigationExecutionDelegate(
      jumpToChapter: (
        chapterIndex, {
        double? initialScrollRatio,
        ReaderLogicalPosition? initialLogicalPosition,
      }) async {
        jumpCalls.add(
          _JumpCall(
            chapterIndex: chapterIndex,
            initialScrollRatio: initialScrollRatio,
            initialLogicalPosition: initialLogicalPosition,
          ),
        );
      },
      restoreCurrent: ({
        double? scrollRatio,
        ReaderLogicalPosition? logicalPosition,
      }) async {
        restoreCalls.add(
          _RestoreCall(
            scrollRatio: scrollRatio,
            logicalPosition: logicalPosition,
          ),
        );
      },
      scheduleAutoReadResume: () {
        autoReadResumeCount += 1;
      },
      scheduleProgressSave: () {
        progressSaveCount += 1;
      },
      showMessage: (message) {
        messages.add(message);
      },
      shouldContinue: () => _shouldContinue,
    );
  }

  final ReaderNavigationExecutionSnapshot snapshot;
  final bool _shouldContinue;
  final List<_JumpCall> jumpCalls = <_JumpCall>[];
  final List<_RestoreCall> restoreCalls = <_RestoreCall>[];
  final List<String> messages = <String>[];
  late final ReaderNavigationExecutionDelegate delegate;
  int autoReadResumeCount = 0;
  int progressSaveCount = 0;
}

class _JumpCall {
  const _JumpCall({
    required this.chapterIndex,
    required this.initialScrollRatio,
    required this.initialLogicalPosition,
  });

  final int chapterIndex;
  final double? initialScrollRatio;
  final ReaderLogicalPosition? initialLogicalPosition;
}

class _RestoreCall {
  const _RestoreCall({
    required this.scrollRatio,
    required this.logicalPosition,
  });

  final double? scrollRatio;
  final ReaderLogicalPosition? logicalPosition;
}
