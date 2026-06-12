import 'package:flutter/widgets.dart';

/// Stateless two-page transition renderer.
///
/// Implementations in `paged_animation/` only compose already-built page
/// widgets for one animation frame. They must not own reader progress,
/// chapter identity, gesture policy, screenshot caches, or persistence side
/// effects. Snapshot/controller based effects, such as paper curl, are routed
/// through `ReaderPagedAnimationSurface` instead.
abstract class PagedAnimationRenderer {
  const PagedAnimationRenderer();

  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  });
}
