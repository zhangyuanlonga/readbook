import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum AppWidthBucket {
  compact,
  regularPhone,
  largePhone,
  phoneXl,
  medium,
  expanded,
}

class AppLayout {
  const AppLayout._();

  static const double compactContentWidth = 340;
  static const double phoneSmallWidth = 360;
  static const double actionWrapWidth = 420;
  static const double phoneLargeWidth = 430;
  static const double railBreakpointWidth = 600;
  static const double regularPhoneBreakpointWidth = 360;
  static const double largePhoneBreakpointWidth = 390;
  static const double phoneXlBreakpointWidth = 480;
  static const double mediumBreakpointWidth = 600;
  static const double expandedBreakpointWidth = 840;
  static const double mineContentMaxWidth = 700;
  static const double settingsContentMaxWidth = 760;
  static const double systemSettingsContentMaxWidth = 860;
  static const double aboutContentMaxWidth = 920;
  static const double aboutExpandedContentMaxWidth = 1080;
  static const double discoverExpandedSidePanelWidth = 300;
  static const double discoverMediumSidePanelWidth = 250;
  static const double discoverExpandedContentMaxWidth = 980;
  static const double discoverMediumContentMaxWidth = 880;
  static const double bookshelfGridFourColumnsWidth = 800;
  static const double bookshelfGridFiveColumnsWidth = 1100;
  static const double bookshelfGridSixColumnsWidth = 1400;

  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static bool isPhoneSmall(BuildContext context) {
    return screenWidth(context) < phoneSmallWidth;
  }

  static bool isPhoneLarge(BuildContext context) {
    final width = screenWidth(context);
    return width >= phoneLargeWidth && width < railBreakpointWidth;
  }

  static AppWidthBucket widthBucket(BuildContext context) {
    return widthBucketFor(screenWidth(context));
  }

  static AppWidthBucket widthBucketFor(double width) {
    if (width < regularPhoneBreakpointWidth) {
      return AppWidthBucket.compact;
    }
    if (width < largePhoneBreakpointWidth) {
      return AppWidthBucket.regularPhone;
    }
    if (width < phoneXlBreakpointWidth) {
      return AppWidthBucket.largePhone;
    }
    if (width < mediumBreakpointWidth) {
      return AppWidthBucket.phoneXl;
    }
    if (width < expandedBreakpointWidth) {
      return AppWidthBucket.medium;
    }
    return AppWidthBucket.expanded;
  }

  static bool isLargePhoneUp(BuildContext context) {
    return screenWidth(context) >= largePhoneBreakpointWidth;
  }

  static bool isMediumUp(BuildContext context) {
    return screenWidth(context) >= mediumBreakpointWidth;
  }

  static bool isExpandedUp(BuildContext context) {
    return screenWidth(context) >= expandedBreakpointWidth;
  }

  static bool isExpandedWidth(double width) {
    return width >= expandedBreakpointWidth;
  }

  static bool isMediumWidth(double width) {
    return width >= mediumBreakpointWidth;
  }

  static int optionGridColumnsForWidth(double width) {
    final bucket = widthBucketFor(width);
    if (bucket == AppWidthBucket.medium || bucket == AppWidthBucket.expanded) {
      return 3;
    }
    if (bucket == AppWidthBucket.compact) {
      return 1;
    }
    return 2;
  }

  static int bookshelfGridColumnsForWidth(double width) {
    final available = width.clamp(220.0, 2400.0);
    if (available >= bookshelfGridSixColumnsWidth) {
      return 6;
    }
    if (available >= bookshelfGridFiveColumnsWidth) {
      return 5;
    }
    if (available >= bookshelfGridFourColumnsWidth) {
      return 4;
    }
    return 3;
  }

  static double shortestSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width, size.height);
  }

  static bool isPhone(BuildContext context) {
    return shortestSide(context) < railBreakpointWidth;
  }

  static double clampedTextScaleFactor(BuildContext context) {
    final raw = MediaQuery.textScalerOf(context).scale(1);
    final minScale = isPhone(context) ? 0.92 : 0.94;
    final maxScale = isPhone(context) ? 1.06 : 1.12;
    return raw.clamp(minScale, maxScale).toDouble();
  }

  static EdgeInsets viewPadding(BuildContext context) {
    return MediaQuery.viewPaddingOf(context);
  }

  static EdgeInsets viewInsets(BuildContext context) {
    return MediaQuery.viewInsetsOf(context);
  }

  static double keyboardInset(BuildContext context) {
    return viewInsets(context).bottom;
  }

  static TextScaler textScaler(BuildContext context) {
    return MediaQuery.textScalerOf(context);
  }

  static double dialogMaxWidth(
    BuildContext context, {
    double maxWidth = 560,
    double horizontalMargin = 32,
  }) {
    final available = math.max(0.0, screenWidth(context) - horizontalMargin);
    return math.min(maxWidth, available);
  }

  static double sheetHeightFactor(
    BuildContext context, {
    required double compact,
    required double regular,
    required double large,
  }) {
    final width = screenWidth(context);
    if (width < phoneSmallWidth) {
      return compact;
    }
    if (width >= phoneLargeWidth) {
      return large;
    }
    return regular;
  }

  static double pageContentMaxWidth(
    BuildContext context, {
    required double maxWidth,
  }) {
    final available = screenWidth(context);
    if (available < railBreakpointWidth) {
      return available;
    }
    return math.min(available, maxWidth);
  }

  static double aboutPageContentMaxWidth(BuildContext context) {
    final available = screenWidth(context);
    if (available >= 1200) {
      return math.min(available, aboutExpandedContentMaxWidth);
    }
    if (available >= railBreakpointWidth) {
      return math.min(available, aboutContentMaxWidth);
    }
    return available;
  }
}
