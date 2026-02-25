import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class AppLayout {
  const AppLayout._();

  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static bool isPhoneSmall(BuildContext context) {
    return screenWidth(context) < 360;
  }

  static bool isPhoneLarge(BuildContext context) {
    final width = screenWidth(context);
    return width >= 430 && width < 600;
  }

  static double shortestSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width, size.height);
  }

  static bool isPhone(BuildContext context) {
    return shortestSide(context) < 600;
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
}
