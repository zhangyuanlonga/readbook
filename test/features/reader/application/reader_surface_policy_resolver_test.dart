import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_policy_resolver.dart';

void main() {
  group('ReaderSurfacePolicyResolver', () {
    const resolver = ReaderSurfacePolicyResolver();

    test('uses zero scroll reserve when footer info bar is visible', () {
      final policy = resolver.resolve(
        showsReaderFooterInfoBar: true,
        showsPagedHeaderInfoBar: false,
        hasPagedInfoOverlay: true,
        effectiveBottomSafeInset: 20,
        bottomProgressReserve: 12,
        bottomOverlayReserve: 96,
        headerMarginTop: 0,
        headerMarginBottom: 0,
        footerMarginTop: 0,
        footerMarginBottom: 0,
        infoHeaderPadding: 8,
        infoFooterPadding: 8,
        headerFontSize: 11.5,
        headerLineHeightFactor: 1.2,
        footerFontSize: 11.5,
        footerLineHeightFactor: 1.2,
      );

      expect(policy.scrollBottomReserve, 0);
    });

    test('ensures paged bottom reserve always covers info overlay reserve', () {
      final policy = resolver.resolve(
        showsReaderFooterInfoBar: false,
        showsPagedHeaderInfoBar: false,
        hasPagedInfoOverlay: true,
        effectiveBottomSafeInset: 20,
        bottomProgressReserve: 12,
        bottomOverlayReserve: 96,
        headerMarginTop: 0,
        headerMarginBottom: 0,
        footerMarginTop: 6,
        footerMarginBottom: 10,
        infoHeaderPadding: 18,
        infoFooterPadding: 18,
        headerFontSize: 12,
        headerLineHeightFactor: 1.3,
        footerFontSize: 12,
        footerLineHeightFactor: 1.3,
      );

      expect(policy.pagedInfoOverlayReserve, closeTo(46.6, 0.001));
      expect(
        policy.pagedBottomReserve,
        greaterThanOrEqualTo(policy.pagedInfoOverlayReserve),
      );
      expect(policy.pagedBottomReserve, lessThan(96));
    });

    test(
      'falls back to bottom progress reserve when paged overlay is hidden',
      () {
        final policy = resolver.resolve(
          showsReaderFooterInfoBar: false,
          showsPagedHeaderInfoBar: false,
          hasPagedInfoOverlay: false,
          effectiveBottomSafeInset: 18,
          bottomProgressReserve: 12,
          bottomOverlayReserve: 96,
          headerMarginTop: 0,
          headerMarginBottom: 0,
          footerMarginTop: 99,
          footerMarginBottom: 99,
          infoHeaderPadding: 24,
          infoFooterPadding: 24,
          headerFontSize: 16,
          headerLineHeightFactor: 2,
          footerFontSize: 16,
          footerLineHeightFactor: 2,
        );

        expect(policy.pagedInfoOverlayReserve, 12);
        expect(policy.pagedBottomReserve, 24);
      },
    );

    test('computes paged header reserve when paged header is visible', () {
      final policy = resolver.resolve(
        showsReaderFooterInfoBar: false,
        showsPagedHeaderInfoBar: true,
        hasPagedInfoOverlay: false,
        effectiveBottomSafeInset: 18,
        bottomProgressReserve: 12,
        bottomOverlayReserve: 96,
        headerMarginTop: 4,
        headerMarginBottom: 6,
        footerMarginTop: 0,
        footerMarginBottom: 0,
        infoHeaderPadding: 10,
        infoFooterPadding: 8,
        headerFontSize: 12,
        headerLineHeightFactor: 1.3,
        footerFontSize: 11.5,
        footerLineHeightFactor: 1.2,
      );

      expect(policy.pagedHeaderReserve, closeTo(41.6, 0.001));
    });
  });
}
