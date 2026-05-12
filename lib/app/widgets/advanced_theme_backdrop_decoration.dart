import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/app_advanced_theme.dart';
import '../images/local_file_image.dart';
import '../theme/app_advanced_theme_tokens.dart';

final Map<String, ImageProvider?> _advancedThemeBackdropFileImageCache =
    <String, ImageProvider?>{};

Decoration buildAdvancedThemeBackdropDecoration(
  ResolvedAdvancedThemeBackdrop backdrop, {
  BorderRadius? borderRadius,
  BoxBorder? border,
}) {
  final wallpaperPath = backdrop.wallpaperPath?.trim() ?? '';
  return _AdvancedThemeBackdropDecoration(
    backgroundColor: backdrop.backgroundColor,
    surfaceColor: backdrop.surfaceColor,
    imageProvider: _resolveBackdropFileImage(wallpaperPath),
    imageOpacity: backdrop.wallpaperOpacity,
    imageBlurSigma: backdrop.wallpaperBlurSigma,
    imageFit: _toBoxFit(backdrop.wallpaperFit),
    overlayColor: backdrop.wallpaperOverlayColor,
    overlayOpacity: backdrop.wallpaperOverlayOpacity,
    borderRadius: borderRadius,
    border: border,
  );
}

Decoration buildImageBackdropDecoration({
  required Color backgroundColor,
  required Color surfaceColor,
  ImageProvider? imageProvider,
  double imageOpacity = 1,
  double imageBlurSigma = 0,
  BoxFit imageFit = BoxFit.cover,
  Color? overlayColor,
  double overlayOpacity = 0,
  BorderRadius? borderRadius,
  BoxBorder? border,
}) {
  return _AdvancedThemeBackdropDecoration(
    backgroundColor: backgroundColor,
    surfaceColor: surfaceColor,
    imageProvider: imageProvider,
    imageOpacity: imageOpacity,
    imageBlurSigma: imageBlurSigma,
    imageFit: imageFit,
    overlayColor: overlayColor,
    overlayOpacity: overlayOpacity,
    borderRadius: borderRadius,
    border: border,
  );
}

class _AdvancedThemeBackdropDecoration extends Decoration {
  const _AdvancedThemeBackdropDecoration({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.imageProvider,
    required this.imageOpacity,
    required this.imageBlurSigma,
    required this.imageFit,
    required this.overlayColor,
    required this.overlayOpacity,
    this.borderRadius,
    this.border,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final ImageProvider? imageProvider;
  final double imageOpacity;
  final double imageBlurSigma;
  final BoxFit imageFit;
  final Color? overlayColor;
  final double overlayOpacity;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AdvancedThemeBackdropPainter(this, onChanged);
  }
}

class _AdvancedThemeBackdropPainter extends BoxPainter {
  _AdvancedThemeBackdropPainter(this.decoration, super.onChanged)
    : _backgroundPainter = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[decoration.backgroundColor, decoration.surfaceColor],
        ),
        borderRadius: decoration.borderRadius,
      ).createBoxPainter(onChanged),
      _borderPainter =
          decoration.border == null
              ? null
              : BoxDecoration(
                borderRadius: decoration.borderRadius,
                border: decoration.border,
              ).createBoxPainter(onChanged);

  final _AdvancedThemeBackdropDecoration decoration;
  final BoxPainter _backgroundPainter;
  final BoxPainter? _borderPainter;

  DecorationImagePainter? _wallpaperPainter;
  DecorationImage? _wallpaperDecorationImage;

  @override
  void dispose() {
    _backgroundPainter.dispose();
    _borderPainter?.dispose();
    _wallpaperPainter?.dispose();
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) {
      return;
    }

    _backgroundPainter.paint(canvas, offset, configuration);

    final rect = offset & size;
    final borderRadius = decoration.borderRadius;
    final clipPath =
        borderRadius == null
            ? null
            : (Path()..addRRect(borderRadius.toRRect(rect)));
    if (decoration.imageProvider != null) {
      final wallpaperDecorationImage = DecorationImage(
        image: decoration.imageProvider!,
        fit: decoration.imageFit,
        alignment: Alignment.center,
        opacity: decoration.imageOpacity.clamp(0.0, 1.0),
        filterQuality: FilterQuality.high,
      );
      if (_wallpaperDecorationImage != wallpaperDecorationImage) {
        _wallpaperPainter?.dispose();
        _wallpaperDecorationImage = wallpaperDecorationImage;
        _wallpaperPainter = wallpaperDecorationImage.createPainter(
          onChanged ?? () {},
        );
      }
      final blurSigma = decoration.imageBlurSigma.clamp(0.0, 24.0);
      if (blurSigma > 0) {
        canvas.saveLayer(
          rect,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
        );
      }
      _wallpaperPainter?.paint(canvas, rect, clipPath, configuration);
      if (blurSigma > 0) {
        canvas.restore();
      }
      final overlayOpacity = decoration.overlayOpacity.clamp(0.0, 1.0);
      if (overlayOpacity > 0 && decoration.overlayColor != null) {
        final overlayPaint =
            Paint()
              ..color = decoration.overlayColor!.withValues(
                alpha: overlayOpacity,
              );
        if (clipPath != null) {
          canvas.save();
          canvas.clipPath(clipPath);
          canvas.drawRect(rect, overlayPaint);
          canvas.restore();
        } else {
          canvas.drawRect(rect, overlayPaint);
        }
      }
    } else {
      _wallpaperPainter?.dispose();
      _wallpaperPainter = null;
      _wallpaperDecorationImage = null;
    }

    _borderPainter?.paint(canvas, offset, configuration);
  }
}

BoxFit _toBoxFit(AppAdvancedThemeWallpaperFit fit) {
  return switch (fit) {
    AppAdvancedThemeWallpaperFit.fill => BoxFit.fill,
    AppAdvancedThemeWallpaperFit.cover => BoxFit.cover,
  };
}

ImageProvider? _resolveBackdropFileImage(String wallpaperPath) {
  if (wallpaperPath.isEmpty) {
    return null;
  }
  if (_advancedThemeBackdropFileImageCache.containsKey(wallpaperPath)) {
    return _advancedThemeBackdropFileImageCache[wallpaperPath];
  }
  final resolved = resolveLocalFileImageProvider(wallpaperPath);
  _advancedThemeBackdropFileImageCache[wallpaperPath] = resolved;
  return resolved;
}
