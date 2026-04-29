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

  static const double _kPagedFooterSafetyBuffer = 6.0;
  static const double _kPagedFooterVerticalPadding = 3.0;

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
                infoHeaderPadding +
                (headerFontSize * headerLineHeightFactor) +
                6;

    final pagedInfoOverlayReserve =
        !hasPagedInfoOverlay
            ? bottomProgressReserve
            : footerMarginBottom +
                _kPagedFooterVerticalPadding +
                (footerFontSize * footerLineHeightFactor) +
                6 +
                _kPagedFooterSafetyBuffer;

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
