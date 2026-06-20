import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_position.dart';

void main() {
  group('ReaderSurfacePosition', () {
    test('encodes and decodes text positions', () {
      final position = ReaderSurfacePosition.text(
        chapterIndex: 2,
        chapterOffset: 120,
        pageIndex: 3,
        pageCount: 9,
        scrollOffset: 42,
        maxScrollExtent: 420,
        progressRatio: 1.4,
      );

      final restored = ReaderSurfacePosition.fromJson(position.toJson());

      expect(restored.kind, ReaderSurfaceKind.text);
      expect(restored.chapterIndex, 2);
      expect(restored.chapterOffset, 120);
      expect(restored.pageIndex, 3);
      expect(restored.pageCount, 9);
      expect(restored.scrollOffset, 42);
      expect(restored.maxScrollExtent, 420);
      expect(restored.progressRatio, 1);
    });

    test('encodes and decodes image positions', () {
      final position = ReaderSurfacePosition.image(
        chapterIndex: 1,
        imageIndex: 4,
        imageCount: 12,
        scrollOffset: 88,
        maxScrollExtent: 300,
        progressRatio: 0.35,
      );

      final restored = ReaderSurfacePosition.fromJson(position.toJson());

      expect(restored.kind, ReaderSurfaceKind.image);
      expect(restored.imageIndex, 4);
      expect(restored.imageCount, 12);
      expect(restored.scrollOffset, 88);
      expect(restored.progressRatio, 0.35);
    });

    test('encodes and decodes document positions', () {
      final position = ReaderSurfacePosition.document(
        chapterIndex: 0,
        pageIndex: 7,
        pageCount: 99,
        zoomScale: 1.25,
        panDx: 10,
        panDy: 20,
        pageScrollOffset: 36,
        progressRatio: 0.5,
      );

      final restored = ReaderSurfacePosition.fromJson(position.toJson());

      expect(restored.kind, ReaderSurfaceKind.document);
      expect(restored.documentPageIndex, 7);
      expect(restored.documentPageCount, 99);
      expect(restored.zoomScale, 1.25);
      expect(restored.panDx, 10);
      expect(restored.panDy, 20);
      expect(restored.pageScrollOffset, 36);
    });

    test('encodes and decodes audio positions', () {
      final position = ReaderSurfacePosition.audio(
        chapterIndex: 3,
        positionMs: 32000,
        durationMs: 180000,
        speed: 1.5,
        progressRatio: -1,
      );

      final restored = ReaderSurfacePosition.fromJson(position.toJson());

      expect(restored.kind, ReaderSurfaceKind.audio);
      expect(restored.audioPositionMs, 32000);
      expect(restored.audioDurationMs, 180000);
      expect(restored.audioSpeed, 1.5);
      expect(restored.progressRatio, 0);
    });
  });

  group('ReaderSurfacePositionMapper', () {
    const mapper = ReaderSurfacePositionMapper();

    test('maps old text paged snapshot to surface position', () {
      final position = mapper.fromSnapshot(
        snapshot: const ReaderPositionSnapshot(
          viewportMode: 'textPaged',
          pageIndex: 2,
          pageCount: 8,
        ),
        chapterIndex: 5,
        chapterPositionRatio: 0.25,
      );

      expect(position.kind, ReaderSurfaceKind.text);
      expect(position.chapterIndex, 5);
      expect(position.pageIndex, 2);
      expect(position.pageCount, 8);
      expect(position.progressRatio, 0.25);
    });

    test('maps image and document snapshots to distinct surface kinds', () {
      final image = mapper.fromSnapshot(
        snapshot: const ReaderPositionSnapshot(
          viewportMode: 'mangaPaged',
          pageIndex: 3,
          pageCount: 10,
        ),
        chapterIndex: 1,
        chapterPositionRatio: 0.3,
      );
      final document = mapper.fromSnapshot(
        snapshot: const ReaderPositionSnapshot(
          viewportMode: 'hybridPaged',
          pageIndex: 6,
          pageCount: 100,
          zoomScale: 1.2,
          panDx: 8,
          panDy: 16,
        ),
        chapterIndex: 1,
        chapterPositionRatio: 0.06,
      );

      expect(image.kind, ReaderSurfaceKind.image);
      expect(image.imageIndex, 3);
      expect(document.kind, ReaderSurfaceKind.document);
      expect(document.documentPageIndex, 6);
      expect(document.zoomScale, 1.2);
    });

    test('maps audio surface position back to old snapshot', () {
      final snapshot = mapper.toSnapshot(
        ReaderSurfacePosition.audio(
          chapterIndex: 4,
          positionMs: 5000,
          durationMs: 20000,
          speed: 1.25,
        ),
      );

      expect(snapshot.viewportMode, 'audio');
      expect(snapshot.audioPositionMs, 5000);
      expect(snapshot.audioDurationMs, 20000);
      expect(snapshot.audioSpeed, 1.25);
    });

    test('uses scroll viewport when page index is absent', () {
      final textSnapshot = mapper.toSnapshot(
        ReaderSurfacePosition.text(chapterIndex: 0, scrollOffset: 128),
      );
      final imageSnapshot = mapper.toSnapshot(
        ReaderSurfacePosition.image(chapterIndex: 0, scrollOffset: 256),
      );

      expect(textSnapshot.viewportMode, 'textScroll');
      expect(imageSnapshot.viewportMode, 'imageScroll');
    });
  });
}
