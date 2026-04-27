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
    double touchYFactor = 0.82,
    required CurlRendererColors colors,
  }) {
    if (progress <= 0) {
      return currentPage;
    }

    final clampedProgress = progress.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        targetPage,
        _CurlBacksideLayer(
          page: currentPage,
          progress: clampedProgress,
          direction: direction,
          touchYFactor: touchYFactor,
          colors: colors,
        ),
        ClipPath(
          clipper: _CurlPageClipper(
            progress: clampedProgress,
            direction: direction,
            touchYFactor: touchYFactor,
          ),
          child: currentPage,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _CurlOverlayPainter(
              progress: clampedProgress,
              direction: direction,
              touchYFactor: touchYFactor,
              backgroundColor: colors.backgroundColor,
              dividerColor: colors.dividerColor,
              overlayColor: colors.overlayColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurlBacksideLayer extends StatelessWidget {
  const _CurlBacksideLayer({
    required this.page,
    required this.progress,
    required this.direction,
    required this.touchYFactor,
    required this.colors,
  });

  final Widget page;
  final double progress;
  final int direction;
  final double touchYFactor;
  final CurlRendererColors colors;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) {
      return const SizedBox.shrink();
    }

    final normalizedDirection = direction >= 0 ? 1.0 : -1.0;
    final angle = lerpDouble(0.02, 0.24, progress)! * normalizedDirection;
    final scaleX = lerpDouble(0.998, 0.94, progress)!;
    final tintAlpha = lerpDouble(0.05, 0.18, progress)!;

    return ClipPath(
      clipper: _CurlBacksideClipper(
        progress: progress,
        direction: direction,
        touchYFactor: touchYFactor,
      ),
      child: Transform(
        alignment:
            normalizedDirection > 0
                ? Alignment.centerRight
                : Alignment.centerLeft,
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(-angle)
              ..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            page,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:
                      normalizedDirection > 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                  end:
                      normalizedDirection > 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  colors: [
                    colors.backgroundColor.withValues(alpha: tintAlpha * 0.45),
                    colors.backgroundColor.withValues(alpha: tintAlpha),
                    colors.dividerColor.withValues(alpha: tintAlpha * 0.55),
                  ],
                  stops: const [0, 0.68, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurlVisualMetrics {
  const _CurlVisualMetrics({
    required this.boundaryX,
    required this.anchorY,
    required this.curveDepth,
    required this.shadowWidth,
    required this.highlightWidth,
  });

  final double boundaryX;
  final double anchorY;
  final double curveDepth;
  final double shadowWidth;
  final double highlightWidth;

  factory _CurlVisualMetrics.resolve(
    Size size, {
    required double progress,
    required int direction,
    required double touchYFactor,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(clamped);
    final anchorY =
        lerpDouble(
          size.height * 0.16,
          size.height * 0.84,
          touchYFactor.clamp(0.0, 1.0),
        )!;
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
        anchorY: anchorY,
        curveDepth: curveDepth,
        shadowWidth: shadowWidth,
        highlightWidth: highlightWidth,
      );
    }

    return _CurlVisualMetrics(
      boundaryX: lerpDouble(0, size.width * 0.92, eased)!,
      anchorY: anchorY,
      curveDepth: curveDepth,
      shadowWidth: shadowWidth,
      highlightWidth: highlightWidth,
    );
  }
}

class _CurlPageClipper extends CustomClipper<Path> {
  const _CurlPageClipper({
    required this.progress,
    required this.direction,
    required this.touchYFactor,
  });

  final double progress;
  final int direction;
  final double touchYFactor;

  @override
  Path getClip(Size size) {
    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
      touchYFactor: touchYFactor,
    );
    final anchorY = metrics.anchorY;
    final topControlY = lerpDouble(anchorY * 0.35, anchorY, 0.42)!;
    final bottomControlY =
        lerpDouble(anchorY + (size.height - anchorY) * 0.65, anchorY, 0.42)!;
    final path = Path();

    if (direction >= 0) {
      path
        ..moveTo(0, 0)
        ..lineTo(metrics.boundaryX, 0)
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          topControlY,
          metrics.boundaryX - metrics.curveDepth,
          anchorY,
        )
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          bottomControlY,
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
        bottomControlY,
        metrics.boundaryX + metrics.curveDepth,
        anchorY,
      )
      ..quadraticBezierTo(
        metrics.boundaryX + metrics.curveDepth * 0.18,
        topControlY,
        metrics.boundaryX,
        0,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CurlPageClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.direction != direction ||
        oldClipper.touchYFactor != touchYFactor;
  }
}

class _CurlBacksideClipper extends CustomClipper<Path> {
  const _CurlBacksideClipper({
    required this.progress,
    required this.direction,
    required this.touchYFactor,
  });

  final double progress;
  final int direction;
  final double touchYFactor;

  @override
  Path getClip(Size size) {
    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
      touchYFactor: touchYFactor,
    );
    final anchorY = metrics.anchorY;
    final topControlY = lerpDouble(anchorY * 0.35, anchorY, 0.42)!;
    final bottomControlY =
        lerpDouble(anchorY + (size.height - anchorY) * 0.65, anchorY, 0.42)!;
    final foldDepth = metrics.curveDepth * 0.82 + metrics.shadowWidth * 0.16;
    final innerDepth = metrics.curveDepth * 0.26;
    final path = Path();

    if (direction >= 0) {
      final outerX = metrics.boundaryX;
      final innerX = max(0.0, metrics.boundaryX - foldDepth);
      path
        ..moveTo(innerX, 0)
        ..lineTo(outerX, 0)
        ..quadraticBezierTo(
          outerX - innerDepth * 0.22,
          topControlY,
          innerX,
          anchorY,
        )
        ..quadraticBezierTo(
          outerX - innerDepth * 0.22,
          bottomControlY,
          outerX,
          size.height,
        )
        ..lineTo(innerX, size.height)
        ..quadraticBezierTo(
          innerX + innerDepth * 0.18,
          bottomControlY,
          innerX + innerDepth * 0.3,
          anchorY,
        )
        ..quadraticBezierTo(innerX + innerDepth * 0.18, topControlY, innerX, 0)
        ..close();
      return path;
    }

    final outerX = metrics.boundaryX;
    final innerX = min(size.width, metrics.boundaryX + foldDepth);
    path
      ..moveTo(outerX, 0)
      ..lineTo(innerX, 0)
      ..quadraticBezierTo(
        innerX - innerDepth * 0.18,
        topControlY,
        innerX - innerDepth * 0.3,
        anchorY,
      )
      ..quadraticBezierTo(
        innerX - innerDepth * 0.18,
        bottomControlY,
        innerX,
        size.height,
      )
      ..lineTo(outerX, size.height)
      ..quadraticBezierTo(
        outerX + innerDepth * 0.22,
        bottomControlY,
        innerX,
        anchorY,
      )
      ..quadraticBezierTo(outerX + innerDepth * 0.22, topControlY, outerX, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CurlBacksideClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.direction != direction ||
        oldClipper.touchYFactor != touchYFactor;
  }
}

class _CurlOverlayPainter extends CustomPainter {
  const _CurlOverlayPainter({
    required this.progress,
    required this.direction,
    required this.touchYFactor,
    required this.backgroundColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  final double progress;
  final int direction;
  final double touchYFactor;
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
      touchYFactor: touchYFactor,
    );
    final anchorY = metrics.anchorY;
    final topControlY = lerpDouble(anchorY * 0.35, anchorY, 0.42)!;
    final bottomControlY =
        lerpDouble(anchorY + (size.height - anchorY) * 0.65, anchorY, 0.42)!;
    final shadowAlpha = lerpDouble(0.0, 0.24, progress)!;
    final overlayAlpha = lerpDouble(0.0, 0.18, progress)!;
    final highlightAlpha = lerpDouble(0.0, 0.22, progress)!;
    final backsideAlpha = lerpDouble(0.0, 0.26, progress)!;

    if (direction >= 0) {
      final foldRect = Rect.fromLTRB(
        max(0, metrics.boundaryX - metrics.curveDepth * 1.1),
        0,
        min(size.width, metrics.boundaryX + metrics.highlightWidth * 0.7),
        size.height,
      );
      canvas.drawRect(
        foldRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              backgroundColor.withValues(alpha: backsideAlpha * 0.35),
              backgroundColor.withValues(alpha: backsideAlpha),
              dividerColor.withValues(alpha: highlightAlpha * 0.55),
            ],
            stops: const [0, 0.38, 0.78, 1],
          ).createShader(foldRect),
      );

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
              overlayColor.withValues(alpha: shadowAlpha * 0.62),
              backgroundColor.withValues(alpha: overlayAlpha),
              dividerColor.withValues(alpha: highlightAlpha),
            ],
            stops: const [0, 0.42, 0.78, 1],
          ).createShader(shadowRect),
      );

      final edgePath =
          Path()
            ..moveTo(metrics.boundaryX, 0)
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              topControlY,
              metrics.boundaryX - metrics.curveDepth,
              anchorY,
            )
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              bottomControlY,
              metrics.boundaryX,
              size.height,
            );
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = dividerColor.withValues(alpha: highlightAlpha * 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lerpDouble(0.8, 1.8, progress)!,
      );
      return;
    }

    final foldRect = Rect.fromLTRB(
      max(0, metrics.boundaryX - metrics.highlightWidth * 0.7),
      0,
      min(size.width, metrics.boundaryX + metrics.curveDepth * 1.1),
      size.height,
    );
    canvas.drawRect(
      foldRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            dividerColor.withValues(alpha: highlightAlpha * 0.55),
            backgroundColor.withValues(alpha: backsideAlpha),
            backgroundColor.withValues(alpha: backsideAlpha * 0.35),
            Colors.transparent,
          ],
          stops: const [0, 0.22, 0.62, 1],
        ).createShader(foldRect),
    );

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
            overlayColor.withValues(alpha: shadowAlpha * 0.62),
            Colors.transparent,
          ],
          stops: const [0, 0.22, 0.58, 1],
        ).createShader(shadowRect),
    );

    final edgePath =
        Path()
          ..moveTo(metrics.boundaryX, 0)
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            topControlY,
            metrics.boundaryX + metrics.curveDepth,
            anchorY,
          )
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            bottomControlY,
            metrics.boundaryX,
            size.height,
          );
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = dividerColor.withValues(alpha: highlightAlpha * 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(0.8, 1.8, progress)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CurlOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.touchYFactor != touchYFactor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}
