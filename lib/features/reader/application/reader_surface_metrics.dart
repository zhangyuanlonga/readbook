import 'package:flutter/painting.dart';

class ReaderSurfaceMetrics {
  const ReaderSurfaceMetrics({
    required this.viewportSize,
    required this.safeInsets,
    required this.bodyPadding,
    required this.headerPadding,
    required this.footerPadding,
    required this.scrollBodyPadding,
    required this.pinnedHeaderHeight,
    required this.pagedHeaderReserve,
    required this.pagedFooterReserve,
    required this.bottomProgressReserve,
    required this.effectivePagePadding,
    required this.contentRect,
    required this.contentWidth,
    required this.contentHeight,
  });

  final Size viewportSize;
  final EdgeInsets safeInsets;
  final EdgeInsets bodyPadding;
  final EdgeInsets headerPadding;
  final EdgeInsets footerPadding;
  final EdgeInsets scrollBodyPadding;
  final double pinnedHeaderHeight;
  final double pagedHeaderReserve;
  final double pagedFooterReserve;
  final double bottomProgressReserve;
  final EdgeInsets effectivePagePadding;
  final Rect contentRect;
  final double contentWidth;
  final double contentHeight;
}
