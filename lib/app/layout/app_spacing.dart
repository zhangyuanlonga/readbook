import 'package:flutter/widgets.dart';

import 'app_layout.dart';

class AppSpacing {
  const AppSpacing._();

  static double pageHorizontal(BuildContext context) {
    final width = AppLayout.screenWidth(context);
    if (AppLayout.isPhoneSmallWidthFor(width)) {
      return 12;
    }
    final bucket = AppLayout.widthBucket(context);
    return switch (bucket) {
      AppWidthBucket.medium => 20,
      AppWidthBucket.expanded => 24,
      _ => 16,
    };
  }

  static double cardHorizontal(BuildContext context) {
    final width = AppLayout.screenWidth(context);
    if (AppLayout.isPhoneSmallWidthFor(width)) {
      return 12;
    }
    final bucket = AppLayout.widthBucket(context);
    return switch (bucket) {
      AppWidthBucket.medium || AppWidthBucket.expanded => 16,
      _ => 14,
    };
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
    if (AppLayout.isPhoneSmallWidthFor(width)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 24);
    }
    final bucket = AppLayout.widthBucket(context);
    final horizontal = switch (bucket) {
      AppWidthBucket.medium || AppWidthBucket.expanded => 28.0,
      _ => 24.0,
    };
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
