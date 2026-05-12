import 'package:flutter/widgets.dart';

abstract class PagedAnimationRenderer {
  const PagedAnimationRenderer();

  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  });
}
