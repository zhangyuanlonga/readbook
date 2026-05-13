import 'dart:math' as math;

import 'app_layout.dart';

class AppSizeTokens {
  const AppSizeTokens._();

  static const double minTouchTarget = 44;
  static const double compactControlHeight = 36;
  static const double regularControlHeight = 40;
  static const double comfortableControlHeight = 44;
  static const double iconButtonHitSize = minTouchTarget;

  static const double mediumContentMaxWidth = 680;
  static const double expandedContentMaxWidth = 820;
  static const double settingsContentMaxWidth = 680;
  static const double formContentMaxWidth = 680;
  static const double readerTextContentMaxWidth = 720;

  static const double bookshelfCardMinWidth = 140;
  static const double bookshelfCardMaxWidth = 200;
  static const double bookshelfDesktopCardMinWidth = 156;

  static double defaultContentMaxWidthForWidth(double width) {
    if (width >= AppLayout.expandedBreakpointWidth) {
      return expandedContentMaxWidth;
    }
    if (width >= AppLayout.mediumBreakpointWidth) {
      return mediumContentMaxWidth;
    }
    return double.infinity;
  }

  static double clampTouchTarget(double visualSize) {
    return math.max(minTouchTarget, visualSize);
  }
}
