import 'package:flutter/widgets.dart';

import 'app_adaptive.dart';
import 'app_layout.dart';

class AppSpacing {
  const AppSpacing._();

  /// Prefer [AppAdaptiveMetrics.pagePadding] for new adaptive page surfaces.
  static double pageHorizontal(BuildContext context) {
    return pageHorizontalForWidth(AppLayout.screenWidth(context));
  }

  static double pageHorizontalForWidth(double width) {
    return AppAdaptiveMetrics.resolveForSize(
      size: Size(width, 844),
    ).pagePadding;
  }

  /// Prefer [AppAdaptiveMetrics.cardPadding] for new adaptive components.
  static double cardHorizontal(BuildContext context) {
    return cardHorizontalForWidth(AppLayout.screenWidth(context));
  }

  static double cardHorizontalForWidth(double width) {
    return AppAdaptiveMetrics.resolveForSize(
      size: Size(width, 844),
    ).cardPadding;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: pageHorizontal(context));
  }

  static EdgeInsets cardPadding(BuildContext context) {
    final h = cardHorizontal(context);
    return EdgeInsets.symmetric(horizontal: h, vertical: h);
  }

  static EdgeInsets dialogInsetPadding(BuildContext context) {
    return dialogInsetPaddingForWidth(AppLayout.screenWidth(context));
  }

  static EdgeInsets dialogInsetPaddingForWidth(double width) {
    if (AppLayout.isPhoneSmallWidthFor(width)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 24);
    }
    final bucket = AppLayout.widthBucketFor(width);
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
