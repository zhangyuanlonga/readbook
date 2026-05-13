import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/app_layout.dart';
import '../widgets/cupertino_dock_navigation_bar.dart';
import 'app_navigation_style_provider.dart';

const double _kStandardNavigationBarHeightWithLabels = 72;
const double _kStandardNavigationBarHeightIconOnly = 58;
const double _kStandardNavigationContentComfortInset = 6;
const double _kStandardFloatingNavigationBottomMinimum = 8;
const double _kCupertinoDockContentComfortInset = 6;

double mobileBottomNavigationContentInset(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
  AppStandardNavigationBarAppearance standardAppearance =
      const AppStandardNavigationBarAppearance(),
}) {
  if (AppLayout.isMediumUp(context)) {
    return 0;
  }
  final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
  return switch (style) {
    AppNavigationStyle.standard =>
      (showNavigationLabels
              ? _kStandardNavigationBarHeightWithLabels
              : _kStandardNavigationBarHeightIconOnly) +
          (standardAppearance.floatingBar
              ? math.max(bottomSafe, _kStandardFloatingNavigationBottomMinimum)
              : bottomSafe),
    AppNavigationStyle.cupertinoDock =>
      CupertinoDockNavigationBar.contentBottomInset(
        context,
        showLabels: showNavigationLabels,
      ),
  };
}

double mobileBottomNavigationComfortInset({required AppNavigationStyle style}) {
  return switch (style) {
    AppNavigationStyle.standard => _kStandardNavigationContentComfortInset,
    AppNavigationStyle.cupertinoDock => _kCupertinoDockContentComfortInset,
  };
}

double mobileBottomNavigationBodyInset(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
  AppStandardNavigationBarAppearance standardAppearance =
      const AppStandardNavigationBarAppearance(),
  double extra = 0,
}) {
  if (AppLayout.isMediumUp(context)) {
    return 0;
  }
  return mobileBottomNavigationContentInset(
        context,
        style: style,
        showNavigationLabels: showNavigationLabels,
        standardAppearance: standardAppearance,
      ) +
      mobileBottomNavigationComfortInset(style: style) +
      extra;
}

EdgeInsets mobileBottomNavigationBodyPadding(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
  AppStandardNavigationBarAppearance standardAppearance =
      const AppStandardNavigationBarAppearance(),
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) {
  if (AppLayout.isMediumUp(context)) {
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }
  return EdgeInsets.fromLTRB(
    left,
    top,
    right,
    bottom +
        mobileBottomNavigationBodyInset(
          context,
          style: style,
          showNavigationLabels: showNavigationLabels,
          standardAppearance: standardAppearance,
        ),
  );
}
