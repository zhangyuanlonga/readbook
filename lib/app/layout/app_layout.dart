import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// 应用统一使用逻辑宽度做自适应，而不是物理分辨率。
/// 断点语义约定如下：
/// - compact: 390dp 以下的小屏手机，例如 iPhone 6s/7/8/SE。
/// - largePhone: 390dp 到 479dp 的大号手机，例如 iPhone 16e。
/// - phoneXl: 480dp 到 599dp 的超大手机或横屏手机。
/// - medium: 600dp 到 839dp 的中等宽度设备。
/// - expanded: 840dp 及以上的大屏设备。
enum AppWidthBucket {
  compact,
  largePhone,
  phoneXl,
  medium,
  expanded,
}

class AppLayout {
  const AppLayout._();

  static const String breakpointCompactName = 'APP_COMPACT';
  static const String breakpointLargePhoneName = 'APP_LARGE_PHONE';
  static const String breakpointPhoneXlName = 'APP_PHONE_XL';
  static const String breakpointMediumName = 'APP_MEDIUM';
  static const String breakpointExpandedName = 'APP_EXPANDED';
  static const double compactContentWidth = 340;
  /// 390dp 以下视为小屏手机。
  static const double phoneSmallWidth = largePhoneBreakpointWidth;
  /// 390dp 起视为大号手机布局。
  static const double largePhoneBreakpointWidth = 390;
  static const double phoneXlBreakpointWidth = 480;
  static const double mediumBreakpointWidth = 600;
  static const double expandedBreakpointWidth = 840;
  static const double actionWrapWidth = 420;
  static const double phoneLargeWidth = largePhoneBreakpointWidth;
  static const double railBreakpointWidth = mediumBreakpointWidth;
  static const double mineContentMaxWidth = 700;
  static const double bookDetailContentMaxWidth = 920;
  static const double searchContentMaxWidth = 920;
  static const double settingsContentMaxWidth = 760;
  static const double systemSettingsContentMaxWidth = 560;
  static const double errorCenterContentMaxWidth = 920;
  static const double aboutContentMaxWidth = 920;
  static const double aboutExpandedContentMaxWidth = 1080;
  static const double discoverExpandedSidePanelWidth = 300;
  static const double discoverMediumSidePanelWidth = 250;
  static const double discoverExpandedContentMaxWidth = 980;
  static const double discoverMediumContentMaxWidth = 880;
  static const double bookshelfGridThreeColumnsWidth = 320;
  static const double bookshelfGridFourColumnsWidth = 800;
  static const double bookshelfGridFiveColumnsWidth = 1100;
  static const double bookshelfGridSixColumnsWidth = 1400;
  static const List<Breakpoint> responsiveBreakpoints = [
    Breakpoint(start: 0, end: 389, name: breakpointCompactName),
    Breakpoint(
      start: largePhoneBreakpointWidth,
      end: 479,
      name: breakpointLargePhoneName,
    ),
    Breakpoint(
      start: phoneXlBreakpointWidth,
      end: 599,
      name: breakpointPhoneXlName,
    ),
    Breakpoint(
      start: mediumBreakpointWidth,
      end: 839,
      name: breakpointMediumName,
    ),
    Breakpoint(
      start: expandedBreakpointWidth,
      end: double.infinity,
      name: breakpointExpandedName,
    ),
  ];

  static Size viewportSize(BuildContext context) {
    final mediaQuerySize = MediaQuery.maybeSizeOf(context);
    if (mediaQuerySize != null &&
        mediaQuerySize.width > 0 &&
        mediaQuerySize.height > 0) {
      return mediaQuerySize;
    }

    final view = View.maybeOf(context);
    if (view != null && view.devicePixelRatio > 0) {
      return view.physicalSize / view.devicePixelRatio;
    }

    return Size.zero;
  }

  static double screenWidth(BuildContext context) {
    return viewportSize(context).width;
  }

  static double screenHeight(BuildContext context) {
    return viewportSize(context).height;
  }

  static bool isPhoneSmall(BuildContext context) {
    return isPhoneSmallWidthFor(screenWidth(context));
  }

  /// 390dp 以下按小屏手机处理。
  static bool isPhoneSmallWidthFor(double width) {
    return width < phoneSmallWidth;
  }

  static bool isPhoneLarge(BuildContext context) {
    final width = screenWidth(context);
    return width >= phoneLargeWidth && width < railBreakpointWidth;
  }

  static AppWidthBucket widthBucket(BuildContext context) {
    return widthBucketFor(screenWidth(context));
  }

  static AppWidthBucket? widthBucketFromBreakpointName(String? breakpointName) {
    return switch (breakpointName) {
      breakpointCompactName => AppWidthBucket.compact,
      breakpointLargePhoneName => AppWidthBucket.largePhone,
      breakpointPhoneXlName => AppWidthBucket.phoneXl,
      breakpointMediumName => AppWidthBucket.medium,
      breakpointExpandedName => AppWidthBucket.expanded,
      _ => null,
    };
  }

  /// 根据当前逻辑宽度返回布局分档。
  static AppWidthBucket widthBucketFor(double width) {
    if (width < largePhoneBreakpointWidth) {
      return AppWidthBucket.compact;
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

  static bool isBelowPhoneLargeWidth(BuildContext context) {
    return screenWidth(context) < phoneLargeWidth;
  }

  static bool isBelowPhoneLargeWidthFor(double width) {
    return width < phoneLargeWidth;
  }

  static int optionGridColumnsForWidth(double width) {
    if (isPhoneSmallWidthFor(width)) {
      return 1;
    }
    final bucket = widthBucketFor(width);
    if (bucket == AppWidthBucket.medium || bucket == AppWidthBucket.expanded) {
      return 3;
    }
    return 2;
  }

  static int bookshelfGridColumnsForWidth(double width) {
    final available = width.clamp(220.0, 2400.0);
    if (available < bookshelfGridThreeColumnsWidth) {
      return 2;
    }
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

  static int mineActionGridColumnsForWidth(double width) {
    return 4;
  }

  static int readingRecordsMetricColumnsForWidth(double width) {
    final bucket = widthBucketFor(width);
    return switch (bucket) {
      AppWidthBucket.medium || AppWidthBucket.expanded => 3,
      _ => 2,
    };
  }

  static bool useCondensedPhoneDensityForWidth(double width) {
    return width >= phoneLargeWidth && width < mediumBreakpointWidth;
  }

  static double shortestSide(BuildContext context) {
    final size = viewportSize(context);
    return math.min(size.width, size.height);
  }

  static bool isPhone(BuildContext context) {
    return shortestSide(context) < railBreakpointWidth;
  }

  static double clampedTextScaleFactor(
    BuildContext context, {
    double multiplier = 1,
  }) {
    final raw = MediaQuery.textScalerOf(context).scale(1) * multiplier;
    const minScale = 0.6;
    const maxScale = 1.5;
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

  /// 按当前逻辑宽度选择弹窗或底部面板高度。
  /// - compact: 小屏手机使用的高度系数。
  /// - regular: 常规手机使用的高度系数。
  /// - large: 大号手机及以上使用的高度系数。
  static double sheetHeightFactor(
    BuildContext context, {
    required double compact,
    required double regular,
    required double large,
  }) {
    final width = screenWidth(context);
    if (isPhoneSmallWidthFor(width)) {
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
