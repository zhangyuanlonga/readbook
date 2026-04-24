import 'package:flutter/widgets.dart';

import '../widgets/cupertino_dock_navigation_bar.dart';
import 'app_navigation_style_provider.dart';

const double _kStandardNavigationBarHeightWithLabels = 80;
const double _kStandardNavigationBarHeightIconOnly = 64;
const double _kStandardNavigationContentComfortInset = 8;
const double _kCupertinoDockContentComfortInset = 8;

double mobileBottomNavigationContentInset(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
}) {
  final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
  return switch (style) {
    AppNavigationStyle.standard =>
      (showNavigationLabels
              ? _kStandardNavigationBarHeightWithLabels
              : _kStandardNavigationBarHeightIconOnly) +
          bottomSafe,
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
  double extra = 0,
}) {
  return mobileBottomNavigationContentInset(
        context,
        style: style,
        showNavigationLabels: showNavigationLabels,
      ) +
      mobileBottomNavigationComfortInset(style: style) +
      extra;
}

EdgeInsets mobileBottomNavigationBodyPadding(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) {
  return EdgeInsets.fromLTRB(
    left,
    top,
    right,
    bottom +
        mobileBottomNavigationBodyInset(
          context,
          style: style,
          showNavigationLabels: showNavigationLabels,
        ),
  );
}
