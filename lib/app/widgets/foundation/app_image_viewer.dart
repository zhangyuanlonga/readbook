import 'package:flutter/material.dart';

class AppImageViewer extends StatelessWidget {
  const AppImageViewer({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 4,
    this.boundaryMargin = const EdgeInsets.all(96),
    this.backgroundColor,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final EdgeInsets boundaryMargin;
  final Color? backgroundColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color:
          backgroundColor ??
          colorScheme.scrim.withValues(
            alpha: colorScheme.brightness == Brightness.dark ? 0.72 : 0.62,
          ),
      child: Center(
        child: InteractiveViewer(
          minScale: minScale,
          maxScale: maxScale,
          boundaryMargin: boundaryMargin,
          clipBehavior: clipBehavior,
          child: child,
        ),
      ),
    );
  }
}
