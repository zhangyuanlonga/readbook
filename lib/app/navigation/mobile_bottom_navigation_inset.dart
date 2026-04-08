import 'package:flutter/widgets.dart';

import '../widgets/cupertino_dock_navigation_bar.dart';
import 'app_navigation_style_provider.dart';

const double _kStandardNavigationBarHeight = 64;

double mobileBottomNavigationContentInset(
  BuildContext context, {
  required AppNavigationStyle style,
  required bool showNavigationLabels,
}) {
  final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
  return switch (style) {
    AppNavigationStyle.standard => _kStandardNavigationBarHeight + bottomSafe,
    AppNavigationStyle.cupertinoDock =>
      CupertinoDockNavigationBar.contentBottomInset(
        context,
        showLabels: showNavigationLabels,
      ),
  };
}
