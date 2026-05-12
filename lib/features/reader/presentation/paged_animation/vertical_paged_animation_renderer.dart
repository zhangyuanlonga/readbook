import 'package:flutter/widgets.dart';

import 'paged_animation_renderer.dart';

class VerticalPagedAnimationRenderer extends PagedAnimationRenderer {
  const VerticalPagedAnimationRenderer();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    final outgoingTranslation = Offset(0, -direction * progress);
    final incomingTranslation = Offset(0, direction * (1 - progress));
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionalTranslation(
          translation: outgoingTranslation,
          child: fromPage,
        ),
        FractionalTranslation(translation: incomingTranslation, child: toPage),
      ],
    );
  }
}
