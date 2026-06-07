import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_logical_position.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_progress_commit_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_viewport_state.dart';

void main() {
  group('ReaderProgressCommitController', () {
    const controller = ReaderProgressCommitController();
    const viewportState = ReaderViewportState(
      kind: ReaderViewportStateKind.textPaged,
      contentMode: ReaderContentMode.text,
      supportsTextSelection: true,
      supportsZoomGesture: false,
      supportsAutoRead: true,
      pageIndex: 2,
      pageCount: 10,
      scrollOffset: 24,
      maxScrollExtent: 240,
    );

    test('returns null when required progress fields are absent', () {
      final progress = controller.buildProgress(
        ReaderProgressCommitInput(
          bookId: 'book-a',
          sourceId: null,
          detailUrl: 'detail-a',
          chapterId: 'chapter-1',
          chapterUrl: 'chapter-a',
          chapterTitle: '第一章',
          chapterIndex: 0,
          positionRatio: 0.2,
          viewportState: viewportState,
          contentMode: ReaderContentMode.text,
          updatedAt: DateTime(2026, 6, 7),
        ),
      );

      expect(progress, isNull);
    });

    test('normalizes local urls and copies viewport snapshot', () {
      final progress = controller.buildProgress(
        ReaderProgressCommitInput(
          bookId: 'book-a',
          sourceId: LocalReaderIdentity.localSourceId,
          detailUrl: '/tmp/book.txt',
          chapterId: 'chapter-1',
          chapterUrl: '/tmp/book.txt#1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          positionRatio: 0.35,
          viewportState: viewportState,
          contentMode: ReaderContentMode.text,
          logicalPosition: const ReaderLogicalPosition(
            chapterIndex: 0,
            blockIndex: 4,
            offsetInBlock: 12,
            chapterPositionRatio: 0.1,
          ),
          updatedAt: DateTime(2026, 6, 7),
        ),
      );

      expect(progress, isNotNull);
      expect(
        progress!.detailUrl,
        LocalReaderIdentity.buildBookDetailUrl('book-a'),
      );
      expect(
        progress.chapterUrl,
        LocalReaderIdentity.buildChapterUrl('chapter-1'),
      );
      expect(progress.chapterPositionRatio, 0.35);
      expect(progress.logicalPosition?.chapterPositionRatio, 0.35);
      expect(progress.logicalPosition?.pageIndex, 2);
      expect(progress.logicalPosition?.totalPageCount, 10);
      expect(progress.positionSnapshot?.viewportMode, 'textPaged');
      expect(progress.positionSnapshot?.audioPositionMs, isNull);
    });

    test('keeps audio snapshot only for audio content mode', () {
      final progress = controller.buildProgress(
        ReaderProgressCommitInput(
          bookId: 'book-a',
          sourceId: 'source-a',
          detailUrl: 'https://example.com/book',
          chapterId: 'chapter-1',
          chapterUrl: 'https://example.com/chapter',
          chapterTitle: '第一章',
          chapterIndex: 0,
          positionRatio: 0.5,
          viewportState: viewportState,
          contentMode: ReaderContentMode.audio,
          audioPlaybackPosition: const Duration(seconds: 12),
          audioPlaybackDuration: const Duration(seconds: 120),
          audioPlaybackSpeed: 1.25,
          updatedAt: DateTime(2026, 6, 7),
        ),
      );

      expect(progress?.positionSnapshot?.audioPositionMs, 12000);
      expect(progress?.positionSnapshot?.audioDurationMs, 120000);
      expect(progress?.positionSnapshot?.audioSpeed, 1.25);
    });
  });
}
