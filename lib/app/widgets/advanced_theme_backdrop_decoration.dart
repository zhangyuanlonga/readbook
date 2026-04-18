import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_advanced_theme_tokens.dart';

BoxDecoration buildAdvancedThemeBackdropDecoration(
  ResolvedAdvancedThemeBackdrop backdrop, {
  BorderRadius? borderRadius,
  BoxBorder? border,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[backdrop.backgroundColor, backdrop.surfaceColor],
    ),
    borderRadius: borderRadius,
    border: border,
    image:
        backdrop.wallpaperPath != null &&
                backdrop.wallpaperPath!.isNotEmpty &&
                File(backdrop.wallpaperPath!).existsSync()
            ? DecorationImage(
              image: FileImage(File(backdrop.wallpaperPath!)),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                backdrop.wallpaperOverlayColor.withValues(
                  alpha: backdrop.wallpaperOverlayOpacity.clamp(0.0, 1.0),
                ),
                BlendMode.srcOver,
              ),
            )
            : null,
  );
}
