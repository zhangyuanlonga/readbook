import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../../app/layout/app_layout.dart';
import '../overlay/reader_overlay_layer_model.dart';

class ReaderOverlayScrimLayer extends StatelessWidget {
  const ReaderOverlayScrimLayer({
    super.key,
    required this.animation,
    required this.maxAlpha,
    required this.onTap,
  });

  final Animation<double> animation;
  final double maxAlpha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final opacity = Curves.easeOut.transform(animation.value) * maxAlpha;
        return ReaderFullScreenHitTestLayer(
          strategy: ReaderFullScreenHitTestStrategy.interceptWhenVisible,
          visible: opacity > 0.001,
          onTap: onTap,
          child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
        );
      },
    );
  }
}

class ReaderChapterLoadingIndicatorLayer extends StatelessWidget {
  const ReaderChapterLoadingIndicatorLayer({
    super.key,
    required this.animation,
    required this.showIndicator,
    required this.topInset,
    required this.dividerColor,
    required this.indicatorColor,
  });

  final Animation<double> animation;
  final bool showIndicator;
  final double topInset;
  final Color dividerColor;
  final Color indicatorColor;

  @override
  Widget build(BuildContext context) {
    final indicator = Align(
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        offset: showIndicator ? Offset.zero : const Offset(0, -0.35),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: showIndicator ? 1 : 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.dialogMaxWidth(
                context,
                maxWidth: 220,
                horizontalMargin: 40,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: dividerColor.withValues(alpha: 0.22),
                valueColor: AlwaysStoppedAnimation<Color>(
                  indicatorColor.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return ReaderFullScreenHitTestLayer(
      strategy: ReaderFullScreenHitTestStrategy.passThrough,
      child: AnimatedBuilder(
        animation: animation,
        child: indicator,
        builder: (context, child) {
          final overlayProgress = Curves.easeOutCubic.transform(
            animation.value,
          );
          final topOffset =
              lerpDouble(topInset + 8, topInset + 60, overlayProgress)!;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, topOffset, 20, 0),
            child: child,
          );
        },
      ),
    );
  }
}
