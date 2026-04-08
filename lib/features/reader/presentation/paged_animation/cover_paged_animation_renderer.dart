import 'package:flutter/material.dart';

import 'paged_animation_renderer.dart';

class CoverPagedAnimationRenderer extends PagedAnimationRenderer {
  const CoverPagedAnimationRenderer();

  static const double _kCoverEdgeShadowWidth = 20;
  static const double _kCoverEdgeShadowMaxAlpha = 0.22;

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    final normalizedDirection = direction >= 0 ? 1.0 : -1.0;
    final fromRight = normalizedDirection > 0;
    final translateX = normalizedDirection * (1 - progress);
    final shadowAlpha = (1 - progress) * _kCoverEdgeShadowMaxAlpha;

    return Stack(
      fit: StackFit.expand,
      children: [
        fromPage,
        FractionalTranslation(
          translation: Offset(translateX, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              toPage,
              IgnorePointer(
                child: Align(
                  alignment:
                      fromRight ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: _kCoverEdgeShadowWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:
                            fromRight
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                        end:
                            fromRight
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: shadowAlpha),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
