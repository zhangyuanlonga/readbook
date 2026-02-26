import 'package:flutter/widgets.dart';

import 'app_layout.dart';

class AppSpacing {
  const AppSpacing._();

  static double pageHorizontal(BuildContext context) {
    final width = AppLayout.screenWidth(context);
    final bucket = AppLayout.widthBucket(context);
    if (bucket == AppWidthBucket.compact) {
      return 12;
    }
    if (bucket == AppWidthBucket.phoneXl ||
        (bucket == AppWidthBucket.largePhone &&
            width >= AppLayout.phoneLargeWidth)) {
      return 20;
    }
    return 16;
  }

  static double cardHorizontal(BuildContext context) {
    final width = AppLayout.screenWidth(context);
    final bucket = AppLayout.widthBucket(context);
    if (bucket == AppWidthBucket.compact) {
      return 12;
    }
    if (bucket == AppWidthBucket.phoneXl ||
        (bucket == AppWidthBucket.largePhone &&
            width >= AppLayout.phoneLargeWidth)) {
      return 16;
    }
    return 14;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: pageHorizontal(context));
  }

  static EdgeInsets cardPadding(BuildContext context) {
    final h = cardHorizontal(context);
    return EdgeInsets.symmetric(horizontal: h, vertical: h);
  }

  static EdgeInsets dialogInsetPadding(BuildContext context) {
    final width = AppLayout.screenWidth(context);
    final bucket = AppLayout.widthBucket(context);
    final horizontal =
        bucket == AppWidthBucket.compact
            ? 16.0
            : bucket == AppWidthBucket.phoneXl ||
                (bucket == AppWidthBucket.largePhone &&
                    width >= AppLayout.phoneLargeWidth)
            ? 28.0
            : 24.0;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: 24);
  }

  static EdgeInsets modalSheetPadding(BuildContext context) {
    final horizontal = pageHorizontal(context);
    return EdgeInsets.fromLTRB(
      horizontal,
      8,
      horizontal,
      16 + AppLayout.keyboardInset(context),
    );
  }
}
