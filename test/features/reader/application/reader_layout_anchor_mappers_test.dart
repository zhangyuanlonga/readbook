import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_annotation_anchor_mapper.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_bookmark_anchor_mapper.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_anchor_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_progress_anchor_mapper.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_range_segmenter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_read_aloud_anchor_mapper.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_search_anchor_mapper.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_selection_runtime.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderSelectionRuntime', () {
    const runtime = ReaderSelectionRuntime();

    test('selects a word by layout hit-test and exposes copy text', () {
      final snapshot = runtime.selectWordAt(
        layoutPages: _pages(),
        pageIndex: 0,
        dx: 18,
        dy: 12,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.startOffset, 0);
      expect(snapshot.endOffset, 5);
      expect(runtime.copyText(snapshot), 'hello');
      expect(snapshot.anchor.kind, ReaderLayoutAnchorKind.selection);
      expect(snapshot.anchor.rects, isNotEmpty);
    });

    test('selects across pages from offsets', () {
      final snapshot = runtime.selectOffsets(
        layoutPages: _pages(),
        startOffset: 3,
        endOffset: 16,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.anchor.spansMultiplePages, isTrue);
      expect(snapshot.segments, hasLength(2));
      expect(snapshot.selectedText, contains('lo'));
      expect(snapshot.selectedText, contains('foo'));
    });
  });

  group('ReaderLayoutRangeSegmenter', () {
    const runtime = ReaderSelectionRuntime();
    const segmenter = ReaderLayoutRangeSegmenter();

    test('splits and merges cross-page ranges', () {
      final snapshot =
          runtime.selectOffsets(
            layoutPages: _pages(),
            startOffset: 3,
            endOffset: 16,
          )!;

      final segments = segmenter.splitByPage(_pages(), snapshot.range);
      final merged = segmenter.mergeSegments(segments);

      expect(segments.map((segment) => segment.pageIndex), <int>[0, 1]);
      expect(merged, isNotNull);
      expect(merged!.start.chapterOffset, 3);
      expect(merged.end.chapterOffset, 16);
      expect(merged.rects, isNotEmpty);
    });
  });

  group('ReaderAnnotationAnchorMapper', () {
    const mapper = ReaderAnnotationAnchorMapper();
    const runtime = ReaderSelectionRuntime();

    test('builds bookmark payload and restores layout anchor', () {
      final anchor =
          runtime
              .selectOffsets(
                layoutPages: _pages(),
                startOffset: 0,
                endOffset: 5,
                kind: ReaderLayoutAnchorKind.annotation,
              )!
              .anchor;

      final bookmark = mapper.buildBookmarkForAnchor(
        anchor: anchor,
        bookId: 'book-1',
        chapterId: 'chapter-1',
        chapterIndex: 0,
        bookmarkId: 'bookmark-1',
        timestamp: DateTime(2026, 6, 20, 10),
        note: 'note',
        isBold: true,
      );
      final restored = mapper.fromBookmark(
        bookmark: bookmark!,
        layoutPages: _pages(),
      );

      expect(bookmark.startOffset, 0);
      expect(bookmark.endOffset, 5);
      expect(bookmark.content.layoutAnchor, isNotNull);
      expect(restored, isNotNull);
      expect(restored!.anchor.selectedText, 'hello');
      expect(restored.isBold, isTrue);
      expect(restored.note, 'note');
    });

    test('ignores bookmarks without layout anchors', () {
      final restored = mapper.fromBookmark(
        bookmark: _bookmarkWithoutLayoutAnchor(start: 13, end: 16),
        layoutPages: _pages(),
      );

      expect(restored, isNull);
    });
  });

  group('ReaderBookmarkAnchorMapper', () {
    const mapper = ReaderBookmarkAnchorMapper();

    test('maps layout anchor to stable layout position', () {
      const runtime = ReaderSelectionRuntime();
      final anchor =
          runtime
              .selectOffsets(
                layoutPages: _pages(),
                startOffset: 13,
                endOffset: 16,
                kind: ReaderLayoutAnchorKind.bookmark,
              )!
              .anchor;
      final restored = mapper.fromBookmark(
        bookmark: _bookmarkWithLayoutAnchor(anchor),
        layoutPages: _pages(),
      );

      expect(restored, isNotNull);
      expect(restored!.position.pageIndex, 1);
      expect(restored.position.chapterOffset, 13);
      expect(restored.range!.selectedText, 'foo');
    });

    test('builds point bookmark with layout position payload', () {
      const position = ReaderLayoutAnchoredPosition(
        kind: ReaderLayoutAnchorKind.bookmark,
        position: ReaderLayoutPosition(
          pageIndex: 1,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 13,
        ),
        chapterProgressRatio: 0.5,
      );
      final bookmark = mapper.buildBookmarkForPosition(
        position: position,
        bookId: 'book-1',
        chapterId: 'chapter-1',
        chapterIndex: 0,
        bookmarkId: 'bookmark-point',
        timestamp: DateTime(2026, 6, 20, 11),
      );

      expect(bookmark.startOffset, 13);
      expect(bookmark.endOffset, 13);
      expect(bookmark.content.layoutAnchor, isNotNull);
    });
  });

  group('ReaderSearchAnchorMapper', () {
    const mapper = ReaderSearchAnchorMapper();

    test('resolves keyword hits to layout ranges and logical positions', () {
      final hits = mapper.resolveKeywordHits(
        keyword: 'foo',
        paragraphs: const <String>['hello world', 'foo bar'],
        layoutPages: _pages(),
        chapterIndex: 0,
      );

      expect(hits, hasLength(1));
      expect(hits.single.anchor.startOffset, 13);
      expect(hits.single.anchor.endOffset, 16);
      expect(hits.single.logicalPosition.pageIndex, 1);
      expect(hits.single.scrollRatio, greaterThan(0));
    });
  });

  group('ReaderReadAloudAnchorMapper', () {
    const mapper = ReaderReadAloudAnchorMapper();

    test('advances by line and by block', () {
      final line = mapper.resolveStep(layoutPages: _pages(), chapterOffset: 1);
      final block = mapper.resolveStep(
        layoutPages: _pages(),
        chapterOffset: 1,
        unit: ReaderReadAloudAdvanceUnit.block,
      );

      expect(line, isNotNull);
      expect(line!.current.selectedText, 'hello');
      expect(line.nextPosition!.chapterOffset, 5);
      expect(block, isNotNull);
      expect(block!.current.selectedText, contains('hello'));
      expect(block.current.selectedText, contains('world'));
      expect(block.nextPosition!.chapterOffset, 13);
    });
  });

  group('ReaderLayoutProgressAnchorMapper', () {
    const mapper = ReaderLayoutProgressAnchorMapper();

    test('captures progress from layout position', () {
      final progress = mapper.toProgressSnapshot(
        layoutPages: _pages(),
        position: const ReaderLayoutPosition(
          pageIndex: 1,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 13,
        ),
      );

      expect(progress.pageIndex, 1);
      expect(progress.totalPageCount, 2);
      expect(progress.chapterPositionRatio, closeTo(0.65, 0.08));
    });
  });
}

Bookmark _bookmarkWithoutLayoutAnchor({required int start, required int end}) {
  return Bookmark(
    id: 'old-$start-$end',
    bookId: 'book-1',
    chapterId: 'chapter-1',
    chapterIndex: 0,
    startOffset: start,
    endOffset: end,
    snippet: 'old',
    createdAt: DateTime(2026, 6, 20, 9),
    updatedAt: DateTime(2026, 6, 20, 9),
    color: '__highlight__',
  );
}

Bookmark _bookmarkWithLayoutAnchor(ReaderLayoutAnchoredRange anchor) {
  return Bookmark(
    id: 'bookmark-${anchor.startOffset}-${anchor.endOffset}',
    bookId: 'book-1',
    chapterId: 'chapter-1',
    chapterIndex: 0,
    startOffset: anchor.startOffset,
    endOffset: anchor.endOffset,
    snippet: Bookmark.buildLayoutSnippetPayload(
      quote: anchor.selectedText,
      layoutAnchor: anchor.toJson(),
    ),
    createdAt: DateTime(2026, 6, 20, 9),
    updatedAt: DateTime(2026, 6, 20, 9),
    color: '__highlight__',
  );
}

List<ReaderLayoutPage> _pages() {
  return const <ReaderLayoutPage>[
    ReaderLayoutPage(
      chapterId: 'chapter-1',
      chapterIndex: 0,
      pageIndex: 0,
      startOffset: 0,
      endOffset: 11,
      contentWidth: 320,
      contentHeight: 480,
      layoutSignature: 'sig',
      lines: <ReaderLayoutLine>[
        ReaderLayoutLine(
          lineIndex: 0,
          paragraphIndex: 0,
          text: 'hello',
          chapterOffset: 0,
          pageOffset: 0,
          lineTop: 0,
          lineBase: 18,
          lineBottom: 24,
          columns: <ReaderLayoutColumn>[
            ReaderLayoutColumn(
              columnIndex: 0,
              kind: ReaderLayoutColumnKind.text,
              startOffset: 0,
              endOffset: 5,
              rect: ReaderLayoutRect(left: 0, top: 0, right: 50, bottom: 24),
              text: 'hello',
            ),
          ],
        ),
        ReaderLayoutLine(
          lineIndex: 1,
          paragraphIndex: 0,
          text: ' world',
          chapterOffset: 5,
          pageOffset: 5,
          lineTop: 30,
          lineBase: 48,
          lineBottom: 54,
          columns: <ReaderLayoutColumn>[
            ReaderLayoutColumn(
              columnIndex: 0,
              kind: ReaderLayoutColumnKind.text,
              startOffset: 5,
              endOffset: 11,
              rect: ReaderLayoutRect(left: 0, top: 30, right: 60, bottom: 54),
              text: ' world',
            ),
          ],
        ),
      ],
    ),
    ReaderLayoutPage(
      chapterId: 'chapter-1',
      chapterIndex: 0,
      pageIndex: 1,
      startOffset: 13,
      endOffset: 20,
      contentWidth: 320,
      contentHeight: 480,
      layoutSignature: 'sig',
      lines: <ReaderLayoutLine>[
        ReaderLayoutLine(
          lineIndex: 0,
          paragraphIndex: 1,
          text: 'foo',
          chapterOffset: 13,
          pageOffset: 0,
          lineTop: 0,
          lineBase: 18,
          lineBottom: 24,
          columns: <ReaderLayoutColumn>[
            ReaderLayoutColumn(
              columnIndex: 0,
              kind: ReaderLayoutColumnKind.text,
              startOffset: 13,
              endOffset: 16,
              rect: ReaderLayoutRect(left: 0, top: 0, right: 30, bottom: 24),
              text: 'foo',
            ),
          ],
        ),
        ReaderLayoutLine(
          lineIndex: 1,
          paragraphIndex: 1,
          text: ' bar',
          chapterOffset: 16,
          pageOffset: 3,
          lineTop: 30,
          lineBase: 48,
          lineBottom: 54,
          columns: <ReaderLayoutColumn>[
            ReaderLayoutColumn(
              columnIndex: 0,
              kind: ReaderLayoutColumnKind.text,
              startOffset: 16,
              endOffset: 20,
              rect: ReaderLayoutRect(left: 0, top: 30, right: 40, bottom: 54),
              text: ' bar',
            ),
          ],
        ),
      ],
    ),
  ];
}
