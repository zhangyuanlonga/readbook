import 'package:flutter/widgets.dart';

import 'paged_animation_renderer.dart';

class TranslatePagedAnimationRenderer extends PagedAnimationRenderer {
  const TranslatePagedAnimationRenderer();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    final outgoingTranslation = Offset(-direction * progress, 0);
    final incomingTranslation = Offset(direction * (1 - progress), 0);
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
