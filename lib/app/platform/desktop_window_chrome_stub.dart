import 'package:flutter/material.dart';

class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DesktopWindowChromeInsets extends StatelessWidget {
  const DesktopWindowChromeInsets({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DesktopWindowDragArea extends StatelessWidget {
  const DesktopWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DesktopWindowCaptionControls extends StatelessWidget {
  const DesktopWindowCaptionControls({super.key});

  static bool isVisible(BuildContext context) => false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class DesktopWindowChromeMetrics {
  const DesktopWindowChromeMetrics._();

  static double topSafePadding(BuildContext context) => 0;

  static double sidebarTopPadding(BuildContext context) => 24;

  static double routeTopBarTopPadding(BuildContext context) => 0;
}
