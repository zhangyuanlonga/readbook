import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_renderer_authority_resolver.dart';

void main() {
  group('ReaderRendererAuthorityResolver', () {
    const resolver = ReaderRendererAuthorityResolver();

    test('uses release page count as the only authority when active', () {
      final snapshot = resolver.resolve(
        releaseActive: true,
        releasePageCount: 4,
        currentPageIndex: 6,
      );

      expect(snapshot.authority, ReaderRendererAuthority.release);
      expect(snapshot.pageCount, 4);
      expect(snapshot.currentPageIndex, 3);
      expect(snapshot.reason, 'layout_release_active');
    });

    test(
      'keeps release authority without scheduling alternate renderer when inactive',
      () {
        final snapshot = resolver.resolve(
          releaseActive: false,
          releasePageCount: 4,
          currentPageIndex: 3,
        );

        expect(snapshot.authority, ReaderRendererAuthority.release);
        expect(snapshot.pageCount, 0);
        expect(snapshot.currentPageIndex, 0);
        expect(snapshot.reason, 'layout_release_inactive');
      },
    );

    test('keeps release authority while exposing inactive reason', () {
      final snapshot = resolver.resolve(
        releaseActive: false,
        releasePageCount: null,
        currentPageIndex: 8,
        inactiveReason: 'layout_stream_failed',
      );

      expect(snapshot.authority, ReaderRendererAuthority.release);
      expect(snapshot.pageCount, 0);
      expect(snapshot.currentPageIndex, 0);
      expect(snapshot.reason, 'layout_stream_failed');
    });
  });
}
