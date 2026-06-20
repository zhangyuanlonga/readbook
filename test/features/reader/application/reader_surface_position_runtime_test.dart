import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_position.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_position_runtime.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_viewport_state.dart';

void main() {
  group('ReaderSurfacePositionRuntime', () {
    const runtime = ReaderSurfacePositionRuntime();

    test('captures manga paged viewport as image surface', () {
      final position = runtime.capture(
        viewportState: const ReaderViewportState(
          kind: ReaderViewportStateKind.mangaPaged,
          contentMode: ReaderContentMode.comic,
          supportsTextSelection: false,
          supportsZoomGesture: true,
          supportsAutoRead: false,
          pageIndex: 2,
          pageCount: 8,
          chapterPositionRatio: 0.25,
        ),
        contentMode: ReaderContentMode.comic,
        chapterIndex: 3,
      );

      expect(position.kind, ReaderSurfaceKind.image);
      expect(position.imageIndex, 2);
      expect(position.imageCount, 8);
      expect(position.progressRatio, 0.25);
    });

    test('captures pdf viewport as document surface with zoom and pan', () {
      final position = runtime.capture(
        viewportState: const ReaderViewportState(
          kind: ReaderViewportStateKind.hybridPaged,
          contentMode: ReaderContentMode.hybrid,
          supportsTextSelection: false,
          supportsZoomGesture: true,
          supportsAutoRead: false,
          pageIndex: 4,
          pageCount: 30,
          zoomScale: 1.75,
          panDx: 120,
          panDy: 240,
          chapterPositionRatio: 0.14,
        ),
        contentMode: ReaderContentMode.hybrid,
        chapterIndex: 1,
        hybridSubMode: ReaderHybridSubMode.pdf,
      );

      expect(position.kind, ReaderSurfaceKind.document);
      expect(position.documentPageIndex, 4);
      expect(position.documentPageCount, 30);
      expect(position.zoomScale, 1.75);
      expect(position.panDx, 120);
      expect(position.panDy, 240);
    });

    test('keeps picture book hybrid viewport on image surface', () {
      final position = runtime.capture(
        viewportState: const ReaderViewportState(
          kind: ReaderViewportStateKind.hybridPaged,
          contentMode: ReaderContentMode.hybrid,
          supportsTextSelection: false,
          supportsZoomGesture: true,
          supportsAutoRead: false,
          pageIndex: 1,
          pageCount: 5,
          chapterPositionRatio: 0.25,
        ),
        contentMode: ReaderContentMode.hybrid,
        chapterIndex: 0,
        hybridSubMode: ReaderHybridSubMode.pictureBook,
      );

      expect(position.kind, ReaderSurfaceKind.image);
      expect(position.imageIndex, 1);
      expect(runtime.toSnapshot(position).viewportMode, 'imagePaged');
    });

    test('restores legacy snapshots and reports diagnostics', () {
      final plan = runtime.restoreFromProgress(
        ReadingProgress(
          bookId: 'book-a',
          sourceId: 'source-a',
          detailUrl: 'detail-a',
          chapterId: 'chapter-a',
          chapterUrl: 'chapter-url-a',
          chapterTitle: '第一章',
          chapterIndex: 2,
          updatedAt: DateTime(2026, 6, 20),
          chapterPositionRatio: 0.5,
          positionSnapshot: const ReaderPositionSnapshot(
            viewportMode: 'mangaContinuous',
            scrollOffset: 160,
            maxScrollExtent: 320,
          ),
        ),
      );

      expect(plan?.kind, ReaderSurfaceKind.image);
      expect(plan?.progressRatio, 0.5);
      final diagnostics = runtime.diagnostics(plan!.position).toJson();
      expect(diagnostics['surfaceKind'], 'image');
      expect(diagnostics['progressRatio'], 0.5);
    });
  });
}
