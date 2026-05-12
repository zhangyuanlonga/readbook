import 'package:flutter/painting.dart';

class ReaderLayoutMetrics {
  const ReaderLayoutMetrics({
    required this.safeInsets,
    required this.bodyPadding,
    required this.headerPadding,
    required this.footerPadding,
    required this.bottomProgressReserve,
    required this.pinnedHeaderHeight,
    required this.effectivePagePadding,
    required this.contentWidth,
    required this.contentHeight,
  });

  final EdgeInsets safeInsets;
  final EdgeInsets bodyPadding;
  final EdgeInsets headerPadding;
  final EdgeInsets footerPadding;
  final double bottomProgressReserve;
  final double pinnedHeaderHeight;
  final EdgeInsets effectivePagePadding;
  final double contentWidth;
  final double contentHeight;
}
