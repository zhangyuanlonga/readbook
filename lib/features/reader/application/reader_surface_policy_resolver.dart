import 'dart:math';

class ReaderSurfacePolicy {
  const ReaderSurfacePolicy({
    required this.scrollBottomReserve,
    required this.pagedHeaderReserve,
    required this.pagedInfoOverlayReserve,
    required this.pagedBottomReserve,
  });

  final double scrollBottomReserve;
  final double pagedHeaderReserve;
  final double pagedInfoOverlayReserve;
  final double pagedBottomReserve;
}

class ReaderSurfacePolicyResolver {
  const ReaderSurfacePolicyResolver();

  ReaderSurfacePolicy resolve({
    required bool showsReaderFooterInfoBar,
    required bool showsPagedHeaderInfoBar,
    required bool hasPagedInfoOverlay,
    required double effectiveBottomSafeInset,
    required double bottomProgressReserve,
    required double bottomOverlayReserve,
    required double headerMarginTop,
    required double headerMarginBottom,
    required double footerMarginTop,
    required double footerMarginBottom,
    required double infoHeaderPadding,
    required double infoFooterPadding,
    required double headerFontSize,
    required double headerLineHeightFactor,
    required double footerFontSize,
    required double footerLineHeightFactor,
  }) {
    final scrollBottomReserve =
        showsReaderFooterInfoBar
            ? 0.0
            : max(
              bottomProgressReserve,
              min(20.0, effectiveBottomSafeInset * 0.6),
            );

    final pagedHeaderReserve =
        !showsPagedHeaderInfoBar
            ? 0.0
            : headerMarginTop +
                headerMarginBottom +
                max(4.0, infoHeaderPadding * 0.5) +
                (headerFontSize * headerLineHeightFactor) +
                6;

    final pagedInfoOverlayReserve =
        !hasPagedInfoOverlay
            ? bottomProgressReserve
            : footerMarginBottom +
                max(4.0, infoFooterPadding * 0.5) +
                (footerFontSize * footerLineHeightFactor) +
                6;

    final pagedBottomReserve =
        hasPagedInfoOverlay
            ? max(bottomProgressReserve, pagedInfoOverlayReserve)
            : max(bottomProgressReserve, min(bottomOverlayReserve, 24.0));

    return ReaderSurfacePolicy(
      scrollBottomReserve: scrollBottomReserve,
      pagedHeaderReserve: pagedHeaderReserve,
      pagedInfoOverlayReserve: pagedInfoOverlayReserve,
      pagedBottomReserve: pagedBottomReserve,
    );
  }
}
