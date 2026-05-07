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

  static const bool _kShowCurlShadow = false;

  Widget build({
    required Widget currentPage,
    required Widget targetPage,
    required double progress,
    required int direction,
    double touchXFactor = 0.88,
    double touchYFactor = 0.82,
    bool isInteractive = false,
    double animationStartProgress = 0,
    bool useTopCorner = false,
    bool commitOnAnimationEnd = true,
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
        final geometry = _CurlGeometry.resolve(
          size,
          progress: clampedProgress,
          direction: direction,
          touchXFactor: touchXFactor,
          touchYFactor: touchYFactor,
          isInteractive: isInteractive,
          animationStartProgress: animationStartProgress,
          useTopCorner: useTopCorner,
          commitOnAnimationEnd: commitOnAnimationEnd,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            targetPage,
            ClipPath(
              clipper: _CurlCurrentPageClipper(geometry),
              child: currentPage,
            ),
            ClipPath(clipper: _CurlRevealClipper(geometry), child: targetPage),
            _CurlBacksideLayer(
              page: currentPage,
              geometry: geometry,
              colors: colors,
            ),
            if (_kShowCurlShadow)
              IgnorePointer(
                child: CustomPaint(
                  painter: _CurlOverlayPainter(
                    geometry: geometry,
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

class _CurlGeometry {
  const _CurlGeometry({
    required this.progress,
    required this.direction,
    required this.touch,
    required this.corner,
    required this.bezierStart1,
    required this.bezierControl1,
    required this.bezierVertex1,
    required this.bezierEnd1,
    required this.bezierStart2,
    required this.bezierControl2,
    required this.bezierVertex2,
    required this.bezierEnd2,
    required this.pathFront,
    required this.pathBack,
    required this.pathReveal,
    required this.rotationDegrees,
    required this.maxLength,
  });

  final double progress;
  final int direction;
  final Offset touch;
  final Offset corner;
  final Offset bezierStart1;
  final Offset bezierControl1;
  final Offset bezierVertex1;
  final Offset bezierEnd1;
  final Offset bezierStart2;
  final Offset bezierControl2;
  final Offset bezierVertex2;
  final Offset bezierEnd2;
  final Path pathFront;
  final Path pathBack;
  final Path pathReveal;
  final double rotationDegrees;
  final double maxLength;

  bool get isRightToLeft => direction >= 0;

  factory _CurlGeometry.resolve(
    Size size, {
    required double progress,
    required int direction,
    required double touchXFactor,
    required double touchYFactor,
    required bool isInteractive,
    required double animationStartProgress,
    required bool useTopCorner,
    required bool commitOnAnimationEnd,
  }) {
    final cornerX = direction >= 0 ? size.width : 0.0;
    final cornerY = useTopCorner ? 0.0 : size.height;
    final safeTouchXFactor = touchXFactor.clamp(0.02, 0.98);
    final safeTouchYFactor = touchYFactor.clamp(0.08, 0.92);
    final startTouchX = size.width * safeTouchXFactor;
    final startTouchY = size.height * safeTouchYFactor;
    final normalizedStartProgress = animationStartProgress.clamp(0.0, 0.98);
    final releasePhase =
        commitOnAnimationEnd
            ? ((progress - normalizedStartProgress) /
                    (1.0 - normalizedStartProgress).clamp(0.0001, 1.0))
                .clamp(0.0, 1.0)
            : (progress / normalizedStartProgress.clamp(0.0001, 1.0)).clamp(
              0.0,
              1.0,
            );
    final easedReleasePhase = Curves.easeOutCubic.transform(releasePhase);

    final targetTouchX =
        commitOnAnimationEnd
            ? (direction >= 0 ? -size.width * 0.03 : size.width * 1.03)
            : (direction >= 0 ? size.width * 0.94 : size.width * 0.06);
    final targetTouchY =
        commitOnAnimationEnd
            ? lerpDouble(startTouchY, cornerY, 0.72)!
            : startTouchY;
    final touchX =
        isInteractive
            ? startTouchX
            : lerpDouble(startTouchX, targetTouchX, easedReleasePhase)!;
    final touchY =
        isInteractive
            ? startTouchY
            : lerpDouble(startTouchY, targetTouchY, easedReleasePhase)!;

    var resolvedTouch = Offset(touchX, touchY);
    final corner = Offset(cornerX, cornerY);
    final maxLength = sqrt(size.width * size.width + size.height * size.height);

    Offset bezierStart1 = Offset.zero;
    Offset bezierControl1 = Offset.zero;
    Offset bezierVertex1 = Offset.zero;
    Offset bezierEnd1 = Offset.zero;
    Offset bezierStart2 = Offset.zero;
    Offset bezierControl2 = Offset.zero;
    Offset bezierVertex2 = Offset.zero;
    Offset bezierEnd2 = Offset.zero;

    void recalc() {
      final middleX = (resolvedTouch.dx + corner.dx) / 2;
      final middleY = (resolvedTouch.dy + corner.dy) / 2;

      final denominator1 = corner.dx - middleX;
      bezierControl1 = Offset(
        middleX -
            (corner.dy - middleY) *
                (corner.dy - middleY) /
                (denominator1.abs() < 0.1
                    ? 0.1 * direction.signOrOne
                    : denominator1),
        corner.dy,
      );
      final denominator2 = corner.dy - middleY;
      bezierControl2 = Offset(
        corner.dx,
        middleY -
            (corner.dx - middleX) *
                (corner.dx - middleX) /
                (denominator2.abs() < 0.1 ? 0.1 : denominator2),
      );

      bezierStart1 = Offset(
        bezierControl1.dx - (corner.dx - bezierControl1.dx) / 2,
        corner.dy,
      );
      bezierStart2 = Offset(
        corner.dx,
        bezierControl2.dy - (corner.dy - bezierControl2.dy) / 2,
      );

      if (resolvedTouch.dx > 0 && resolvedTouch.dx < size.width) {
        if (bezierStart1.dx < 0 || bezierStart1.dx > size.width) {
          final adjustedStart1X =
              bezierStart1.dx < 0
                  ? size.width - bezierStart1.dx
                  : bezierStart1.dx;
          final distanceX = (corner.dx - resolvedTouch.dx).abs();
          final projectedX = size.width * distanceX / adjustedStart1X;
          final nextTouchX = (corner.dx - projectedX).abs();
          final nextTouchY =
              (corner.dy -
                      (corner.dx - nextTouchX).abs() *
                          (corner.dy - resolvedTouch.dy).abs() /
                          distanceX)
                  .abs();
          resolvedTouch = Offset(nextTouchX, nextTouchY);
          recalc();
          return;
        }
      }

      bezierEnd1 = _lineIntersection(
        resolvedTouch,
        bezierControl1,
        bezierStart1,
        bezierStart2,
      );
      bezierEnd2 = _lineIntersection(
        resolvedTouch,
        bezierControl2,
        bezierStart1,
        bezierStart2,
      );

      bezierVertex1 = Offset(
        (bezierStart1.dx + 2 * bezierControl1.dx + bezierEnd1.dx) / 4,
        (2 * bezierControl1.dy + bezierStart1.dy + bezierEnd1.dy) / 4,
      );
      bezierVertex2 = Offset(
        (bezierStart2.dx + 2 * bezierControl2.dx + bezierEnd2.dx) / 4,
        (2 * bezierControl2.dy + bezierStart2.dy + bezierEnd2.dy) / 4,
      );
    }

    recalc();

    final pathFront =
        Path()
          ..moveTo(bezierStart1.dx, bezierStart1.dy)
          ..quadraticBezierTo(
            bezierControl1.dx,
            bezierControl1.dy,
            bezierEnd1.dx,
            bezierEnd1.dy,
          )
          ..lineTo(resolvedTouch.dx, resolvedTouch.dy)
          ..lineTo(bezierEnd2.dx, bezierEnd2.dy)
          ..quadraticBezierTo(
            bezierControl2.dx,
            bezierControl2.dy,
            bezierStart2.dx,
            bezierStart2.dy,
          )
          ..lineTo(corner.dx, corner.dy)
          ..close();

    final pathBack =
        Path()
          ..moveTo(bezierVertex2.dx, bezierVertex2.dy)
          ..lineTo(bezierVertex1.dx, bezierVertex1.dy)
          ..lineTo(bezierEnd1.dx, bezierEnd1.dy)
          ..lineTo(resolvedTouch.dx, resolvedTouch.dy)
          ..lineTo(bezierEnd2.dx, bezierEnd2.dy)
          ..close();

    final pathReveal =
        Path()
          ..moveTo(bezierStart1.dx, bezierStart1.dy)
          ..lineTo(bezierVertex1.dx, bezierVertex1.dy)
          ..lineTo(bezierVertex2.dx, bezierVertex2.dy)
          ..lineTo(bezierStart2.dx, bezierStart2.dy)
          ..lineTo(corner.dx, corner.dy)
          ..close();

    final rotationDegrees =
        atan2(bezierControl1.dx - corner.dx, bezierControl2.dy - corner.dy) *
        180 /
        pi;

    return _CurlGeometry(
      progress: progress,
      direction: direction,
      touch: resolvedTouch,
      corner: corner,
      bezierStart1: bezierStart1,
      bezierControl1: bezierControl1,
      bezierVertex1: bezierVertex1,
      bezierEnd1: bezierEnd1,
      bezierStart2: bezierStart2,
      bezierControl2: bezierControl2,
      bezierVertex2: bezierVertex2,
      bezierEnd2: bezierEnd2,
      pathFront: pathFront,
      pathBack: pathBack,
      pathReveal: pathReveal,
      rotationDegrees: rotationDegrees,
      maxLength: maxLength,
    );
  }
}

class _CurlCurrentPageClipper extends CustomClipper<Path> {
  const _CurlCurrentPageClipper(this.geometry);

  final _CurlGeometry geometry;

  @override
  Path getClip(Size size) {
    final bounds = Path()..addRect(Offset.zero & size);
    return Path.combine(PathOperation.difference, bounds, geometry.pathFront);
  }

  @override
  bool shouldReclip(covariant _CurlCurrentPageClipper oldClipper) {
    return oldClipper.geometry != geometry;
  }
}

class _CurlRevealClipper extends CustomClipper<Path> {
  const _CurlRevealClipper(this.geometry);

  final _CurlGeometry geometry;

  @override
  Path getClip(Size size) {
    return geometry.pathReveal;
  }

  @override
  bool shouldReclip(covariant _CurlRevealClipper oldClipper) {
    return oldClipper.geometry != geometry;
  }
}

class _CurlBackClipper extends CustomClipper<Path> {
  const _CurlBackClipper(this.geometry);

  final _CurlGeometry geometry;

  @override
  Path getClip(Size size) => geometry.pathBack;

  @override
  bool shouldReclip(covariant _CurlBackClipper oldClipper) {
    return oldClipper.geometry != geometry;
  }
}

class _CurlBacksideLayer extends StatelessWidget {
  const _CurlBacksideLayer({
    required this.page,
    required this.geometry,
    required this.colors,
  });

  final Widget page;
  final _CurlGeometry geometry;
  final CurlRendererColors colors;

  @override
  Widget build(BuildContext context) {
    final normalizedDirection = geometry.isRightToLeft ? 1.0 : -1.0;
    final angle =
        lerpDouble(0.02, 0.24, geometry.progress)! * normalizedDirection;
    final scaleX = lerpDouble(0.998, 0.94, geometry.progress)!;
    final tintAlpha = lerpDouble(0.05, 0.18, geometry.progress)!;
    return ClipPath(
      clipper: _CurlBackClipper(geometry),
      child: Transform(
        alignment:
            geometry.isRightToLeft
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
                      geometry.isRightToLeft
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                  end:
                      geometry.isRightToLeft
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

class _CurlOverlayPainter extends CustomPainter {
  const _CurlOverlayPainter({
    required this.geometry,
    required this.backgroundColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  final _CurlGeometry geometry;
  final Color backgroundColor;
  final Color dividerColor;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowAlpha = lerpDouble(0.0, 0.24, geometry.progress)!;
    final overlayAlpha = lerpDouble(0.0, 0.18, geometry.progress)!;
    final highlightAlpha = lerpDouble(0.0, 0.22, geometry.progress)!;
    final backsideAlpha = lerpDouble(0.0, 0.26, geometry.progress)!;

    final foldRect =
        geometry.isRightToLeft
            ? Rect.fromLTRB(
              max(0, geometry.bezierStart1.dx - 42),
              0,
              min(size.width, geometry.bezierStart1.dx + 18),
              size.height,
            )
            : Rect.fromLTRB(
              max(0, geometry.bezierStart1.dx - 18),
              0,
              min(size.width, geometry.bezierStart1.dx + 42),
              size.height,
            );
    canvas.drawRect(
      foldRect,
      Paint()
        ..shader = LinearGradient(
          begin:
              geometry.isRightToLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
          end:
              geometry.isRightToLeft
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
          colors: [
            Colors.transparent,
            backgroundColor.withValues(alpha: backsideAlpha * 0.4),
            overlayColor.withValues(alpha: overlayAlpha),
            dividerColor.withValues(alpha: highlightAlpha),
          ],
          stops: const [0, 0.35, 0.76, 1],
        ).createShader(foldRect),
    );

    final edgePath =
        Path()
          ..moveTo(geometry.bezierStart1.dx, geometry.bezierStart1.dy)
          ..quadraticBezierTo(
            geometry.bezierControl1.dx,
            geometry.bezierControl1.dy,
            geometry.bezierEnd1.dx,
            geometry.bezierEnd1.dy,
          )
          ..lineTo(geometry.touch.dx, geometry.touch.dy)
          ..lineTo(geometry.bezierEnd2.dx, geometry.bezierEnd2.dy)
          ..quadraticBezierTo(
            geometry.bezierControl2.dx,
            geometry.bezierControl2.dy,
            geometry.bezierStart2.dx,
            geometry.bezierStart2.dy,
          );
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = dividerColor.withValues(
          alpha: max(highlightAlpha, shadowAlpha * 0.8),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(0.8, 1.8, geometry.progress)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CurlOverlayPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}

Offset _lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
  final a1 =
      (p2.dy - p1.dy) / ((p2.dx - p1.dx).abs() < 0.1 ? 0.1 : (p2.dx - p1.dx));
  final b1 =
      (p1.dx * p2.dy - p2.dx * p1.dy) /
      ((p1.dx - p2.dx).abs() < 0.1 ? 0.1 : (p1.dx - p2.dx));
  final a2 =
      (p4.dy - p3.dy) / ((p4.dx - p3.dx).abs() < 0.1 ? 0.1 : (p4.dx - p3.dx));
  final b2 =
      (p3.dx * p4.dy - p4.dx * p3.dy) /
      ((p3.dx - p4.dx).abs() < 0.1 ? 0.1 : (p3.dx - p4.dx));
  final x = (b2 - b1) / ((a1 - a2).abs() < 0.1 ? 0.1 : (a1 - a2));
  final y = a1 * x + b1;
  return Offset(x, y);
}

extension on int {
  double get signOrOne => this >= 0 ? 1.0 : -1.0;
}
