import 'package:flutter/material.dart';

enum AppBorderTone { subtle, defaultTone, strong }

Color resolveAppBorderColor(
  ColorScheme colorScheme, {
  Color? baseColor,
  Color? containerColor,
  AppBorderTone tone = AppBorderTone.defaultTone,
}) {
  final effectiveBase = baseColor ?? colorScheme.outlineVariant;
  final effectiveContainer = containerColor ?? colorScheme.surface;

  return switch (tone) {
    AppBorderTone.subtle =>
      Color.lerp(
        effectiveBase,
        effectiveContainer,
        colorScheme.brightness == Brightness.dark ? 0.14 : 0.18,
      )!,
    AppBorderTone.defaultTone => effectiveBase,
    AppBorderTone.strong =>
      baseColor != null
          ? effectiveBase
          : Color.lerp(effectiveBase, colorScheme.outline, 0.45)!,
  };
}

BorderSide resolveAppBorderSide(
  ColorScheme colorScheme, {
  Color? baseColor,
  Color? containerColor,
  AppBorderTone tone = AppBorderTone.defaultTone,
  double width = 1,
}) {
  return BorderSide(
    color: resolveAppBorderColor(
      colorScheme,
      baseColor: baseColor,
      containerColor: containerColor,
      tone: tone,
    ),
    width: width,
  );
}
