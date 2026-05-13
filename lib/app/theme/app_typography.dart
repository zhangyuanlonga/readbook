import 'dart:math' as math;

class AppTypography {
  const AppTypography._();

  static const double caption = 11;
  static const double footnote = 12;
  static const double subhead = 13;
  static const double bodyBase = 15;
  static const double body = bodyBase;
  static const double bodyLarge = 16;
  static const double titleSmall = 18;
  static const double title = 22;
  static const double titleLarge = 28;
  static const double headline = 34;

  static const double uiTextScaleMax = 1.5;
  static const double readerChromeTextScaleMax = 1.5;

  /// Reader body uses the app reader font-size slider and should not be
  /// multiplied by system text scale during pagination.
  static const double readerBodyDefaultMobile = 17;
  static const double readerBodyDefaultLargeScreen = 18;

  static double capUiTextScale(double textScaleFactor) {
    return math.max(0.8, math.min(textScaleFactor, uiTextScaleMax));
  }

  static double capReaderChromeTextScale(double textScaleFactor) {
    return math.max(0.8, math.min(textScaleFactor, readerChromeTextScaleMax));
  }
}
