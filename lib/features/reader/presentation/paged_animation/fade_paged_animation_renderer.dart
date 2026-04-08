import 'package:flutter/widgets.dart';

import 'paged_animation_renderer.dart';

class FadePagedAnimationRenderer extends PagedAnimationRenderer {
  const FadePagedAnimationRenderer();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: (1 - progress).clamp(0.0, 1.0), child: fromPage),
        Opacity(opacity: progress.clamp(0.0, 1.0), child: toPage),
      ],
    );
  }
}
