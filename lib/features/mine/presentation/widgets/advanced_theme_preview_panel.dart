import 'package:flutter/material.dart';

class AdvancedThemePreviewPanel extends StatelessWidget {
  const AdvancedThemePreviewPanel({
    super.key,
    required this.decoration,
    required this.maxWidth,
    required this.child,
  });

  final Decoration decoration;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
