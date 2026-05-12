import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class CurlRendererColors {
  const CurlRendererColors({
    required this.backgroundColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  final Color backgroundColor;
  final Color dividerColor;
  final Color overlayColor;
}

class CurlPagedAnimationRenderer {
  const CurlPagedAnimationRenderer();

  Widget build({
    required Widget currentPage,
    required Widget targetPage,
    required double progress,
    required int direction,
    required CurlRendererColors colors,
  }) {
    if (progress <= 0) {
      return currentPage;
    }

    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) {
          return currentPage;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            targetPage,
            ClipPath(
              clipper: _CurlPageClipper(
                progress: clampedProgress,
                direction: direction,
              ),
              child: currentPage,
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CurlOverlayPainter(
                  progress: clampedProgress,
                  direction: direction,
                  backgroundColor: colors.backgroundColor,
                  dividerColor: colors.dividerColor,
                  overlayColor: colors.overlayColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurlVisualMetrics {
  const _CurlVisualMetrics({
    required this.boundaryX,
    required this.curveDepth,
    required this.shadowWidth,
    required this.highlightWidth,
  });

  final double boundaryX;
  final double curveDepth;
  final double shadowWidth;
  final double highlightWidth;

  factory _CurlVisualMetrics.resolve(
    Size size, {
    required double progress,
    required int direction,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(clamped);
    final curveDepth =
        lerpDouble(
          10,
          min(size.width * 0.16, 88.0),
          Curves.easeOutCubic.transform(clamped),
        )!;
    final shadowWidth = lerpDouble(18, min(size.width * 0.2, 110.0), clamped)!;
    final highlightWidth =
        lerpDouble(8, min(size.width * 0.07, 32.0), clamped)!;

    if (direction >= 0) {
      return _CurlVisualMetrics(
        boundaryX: lerpDouble(size.width, size.width * 0.08, eased)!,
        curveDepth: curveDepth,
        shadowWidth: shadowWidth,
        highlightWidth: highlightWidth,
      );
    }

    return _CurlVisualMetrics(
      boundaryX: lerpDouble(0, size.width * 0.92, eased)!,
      curveDepth: curveDepth,
      shadowWidth: shadowWidth,
      highlightWidth: highlightWidth,
    );
  }
}

class _CurlPageClipper extends CustomClipper<Path> {
  const _CurlPageClipper({required this.progress, required this.direction});

  final double progress;
  final int direction;

  @override
  Path getClip(Size size) {
    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
    );
    final path = Path();

    if (direction >= 0) {
      path
        ..moveTo(0, 0)
        ..lineTo(metrics.boundaryX, 0)
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          size.height * 0.22,
          metrics.boundaryX - metrics.curveDepth,
          size.height * 0.5,
        )
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          size.height * 0.78,
          metrics.boundaryX,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close();
      return path;
    }

    path
      ..moveTo(metrics.boundaryX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(metrics.boundaryX, size.height)
      ..quadraticBezierTo(
        metrics.boundaryX + metrics.curveDepth * 0.18,
        size.height * 0.78,
        metrics.boundaryX + metrics.curveDepth,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        metrics.boundaryX + metrics.curveDepth * 0.18,
        size.height * 0.22,
        metrics.boundaryX,
        0,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CurlPageClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.direction != direction;
  }
}

class _CurlOverlayPainter extends CustomPainter {
  const _CurlOverlayPainter({
    required this.progress,
    required this.direction,
    required this.backgroundColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  final double progress;
  final int direction;
  final Color backgroundColor;
  final Color dividerColor;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
    );
    final shadowAlpha = lerpDouble(0.0, 0.22, progress)!;
    final overlayAlpha = lerpDouble(0.0, 0.16, progress)!;
    final highlightAlpha = lerpDouble(0.0, 0.18, progress)!;

    if (direction >= 0) {
      final shadowRect = Rect.fromLTRB(
        max(0, metrics.boundaryX - metrics.shadowWidth),
        0,
        min(size.width, metrics.boundaryX + metrics.highlightWidth * 0.6),
        size.height,
      );
      canvas.drawRect(
        shadowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              overlayColor.withValues(alpha: shadowAlpha * 0.55),
              backgroundColor.withValues(alpha: overlayAlpha),
              dividerColor.withValues(alpha: highlightAlpha),
            ],
            stops: const [0, 0.45, 0.78, 1],
          ).createShader(shadowRect),
      );

      final edgePath =
          Path()
            ..moveTo(metrics.boundaryX, 0)
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              size.height * 0.22,
              metrics.boundaryX - metrics.curveDepth,
              size.height * 0.5,
            )
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              size.height * 0.78,
              metrics.boundaryX,
              size.height,
            );
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = dividerColor.withValues(alpha: highlightAlpha * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lerpDouble(0.8, 1.6, progress)!,
      );
      return;
    }

    final shadowRect = Rect.fromLTRB(
      max(0, metrics.boundaryX - metrics.highlightWidth * 0.6),
      0,
      min(size.width, metrics.boundaryX + metrics.shadowWidth),
      size.height,
    );
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            dividerColor.withValues(alpha: highlightAlpha),
            backgroundColor.withValues(alpha: overlayAlpha),
            overlayColor.withValues(alpha: shadowAlpha * 0.55),
            Colors.transparent,
          ],
          stops: const [0, 0.22, 0.55, 1],
        ).createShader(shadowRect),
    );

    final edgePath =
        Path()
          ..moveTo(metrics.boundaryX, 0)
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            size.height * 0.22,
            metrics.boundaryX + metrics.curveDepth,
            size.height * 0.5,
          )
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            size.height * 0.78,
            metrics.boundaryX,
            size.height,
          );
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = dividerColor.withValues(alpha: highlightAlpha * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(0.8, 1.6, progress)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CurlOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}
