import 'package:flutter/widgets.dart';

import 'app_layout.dart';

class AppSpacing {
  const AppSpacing._();

  static double pageHorizontal(BuildContext context) {
    return AppLayout.isPhoneSmall(context) ? 12 : 16;
  }

  static double cardHorizontal(BuildContext context) {
    return AppLayout.isPhoneSmall(context) ? 12 : 14;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: pageHorizontal(context));
  }

  static EdgeInsets cardPadding(BuildContext context) {
    final h = cardHorizontal(context);
    return EdgeInsets.symmetric(horizontal: h, vertical: h);
  }

  static EdgeInsets dialogInsetPadding(BuildContext context) {
    final horizontal = AppLayout.isPhoneSmall(context) ? 16.0 : 24.0;
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
