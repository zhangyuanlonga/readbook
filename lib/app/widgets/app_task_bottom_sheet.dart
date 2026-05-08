import 'package:flutter/material.dart';

class AppTaskStep {
  const AppTaskStep({required this.label, required this.active});

  final String label;
  final bool active;
}

class AppTaskActionCard extends StatelessWidget {
  const AppTaskActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    this.dashedBorder = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: radius,
        border:
            dashedBorder
                ? null
                : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    final wrapped =
        dashedBorder
            ? CustomPaint(
              painter: _DashedRoundedRectPainter(
                color: Colors.black,
                radius: 24,
              ),
              child: content,
            )
            : content;

    return InkWell(borderRadius: radius, onTap: onTap, child: wrapped);
  }
}

class AppTaskBottomSheet extends StatelessWidget {
  const AppTaskBottomSheet({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.trailing,
    this.header,
    this.footer,
    this.steps = const <AppTaskStep>[],
    this.maxHeightFactor = 0.82,
    this.padding = const EdgeInsets.fromLTRB(16, 2, 16, 10),
    this.fitContent = false,
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? header;
  final Widget? footer;
  final List<AppTaskStep> steps;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: padding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          right: trailing != null ? 44 : 0,
                          left: leading != null ? 44 : 0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            title,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (leading != null)
                        Align(alignment: Alignment.centerLeft, child: leading!),
                      if (trailing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing!,
                        ),
                    ],
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (
                          var index = 0;
                          index < steps.length;
                          index += 1
                        ) ...[
                          _AppTaskStepNode(
                            label: steps[index].label,
                            active: steps[index].active,
                          ),
                          if (index != steps.length - 1)
                            Expanded(
                              child: CustomPaint(
                                painter: _DashedLinePainter(
                                  color:
                                      steps[index + 1].active
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant,
                                ),
                                child: const SizedBox(
                                  height: 1.4,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                  if (header != null) ...[const SizedBox(height: 10), header!],
                  const SizedBox(height: 10),
                  if (fitContent) body else Expanded(child: body),
                  if (footer != null) ...[const SizedBox(height: 10), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTaskStepNode extends StatelessWidget {
  const _AppTaskStepNode({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: active ? colorScheme.primary : colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

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
          ..strokeWidth = 1.4;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    const dashWidth = 7.0;
    const dashSpace = 5.0;
    var startX = 0.0;
    final centerY = size.height / 2;
    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0, size.width).toDouble();
      canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
