import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

class AppAnimatedDashedRoundedBorder extends StatefulWidget {
  const AppAnimatedDashedRoundedBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.strokeWidth = 1.4,
    this.dashWidth = 8,
    this.dashSpace = 6,
    this.duration = const Duration(milliseconds: 1800),
    this.animated = true,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final Duration duration;
  final bool animated;

  @override
  State<AppAnimatedDashedRoundedBorder> createState() =>
      _AppAnimatedDashedRoundedBorderState();
}

class _AppAnimatedDashedRoundedBorderState
    extends State<AppAnimatedDashedRoundedBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant AppAnimatedDashedRoundedBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller.repeat();
      }
    }
    if (oldWidget.animated != widget.animated) {
      _syncAnimation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    if (AppMotion.enabledOf(context, enabled: widget.animated)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: widget.color,
        radius: widget.radius,
        strokeWidth: widget.strokeWidth,
        dashWidth: widget.dashWidth,
        dashSpace: widget.dashSpace,
        animation: _controller,
      ),
      child: widget.child,
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    this.animation,
  }) : super(repaint: animation);

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    final dashCycle = dashWidth + dashSpace;
    final phase = (animation?.value ?? 0) * dashCycle;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = -phase;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        if (next > 0) {
          canvas.drawPath(
            metric.extractPath(
              distance.clamp(0.0, metric.length).toDouble(),
              next.clamp(0.0, metric.length).toDouble(),
            ),
            paint,
          );
        }
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.animation != animation;
  }
}
