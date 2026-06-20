import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_renderer_authority_resolver.dart';

void main() {
  group('ReaderRendererAuthorityResolver', () {
    const resolver = ReaderRendererAuthorityResolver();

    test('uses release page count as the only authority when active', () {
      final snapshot = resolver.resolve(
        releaseActive: true,
        releasePageCount: 4,
        legacyTextPageCount: 9,
        legacyBlockPageCount: 10,
        currentPageIndex: 6,
      );

      expect(snapshot.authority, ReaderRendererAuthority.release);
      expect(snapshot.pageCount, 4);
      expect(snapshot.currentPageIndex, 3);
      expect(snapshot.shouldScheduleLegacyPagination, isFalse);
    });

    test('uses legacy page count and schedules pagination when inactive', () {
      final snapshot = resolver.resolve(
        releaseActive: false,
        releasePageCount: 4,
        legacyTextPageCount: 2,
        legacyBlockPageCount: 5,
        currentPageIndex: 3,
      );

      expect(snapshot.authority, ReaderRendererAuthority.legacy);
      expect(snapshot.pageCount, 5);
      expect(snapshot.currentPageIndex, 3);
      expect(snapshot.shouldScheduleLegacyPagination, isTrue);
    });

    test('marks fallback authority with reason', () {
      final snapshot = resolver.resolve(
        releaseActive: false,
        releasePageCount: null,
        legacyTextPageCount: 3,
        legacyBlockPageCount: 0,
        currentPageIndex: 8,
        fallbackReason: 'layout_stream_failed',
      );

      expect(snapshot.authority, ReaderRendererAuthority.fallback);
      expect(snapshot.pageCount, 3);
      expect(snapshot.currentPageIndex, 2);
      expect(snapshot.reason, 'layout_stream_failed');
    });
  });
}
