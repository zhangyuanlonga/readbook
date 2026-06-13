import 'package:flutter/widgets.dart';

import '../../reader_overlay_z_order.dart';

enum ReaderOverlayHitTestPolicy {
  /// Let the child decide whether it handles pointer events.
  deferToChild,

  /// Keep the layer visible but never let it participate in hit testing.
  passThrough,

  /// Reserve the layer for future full-screen blockers.
  blockAll,
}

enum ReaderFullScreenHitTestStrategy {
  /// The layer is painted but must never handle pointer events.
  passThrough,

  /// The layer always captures pointer events while it is mounted.
  intercept,

  /// The layer captures pointer events only while it is visibly active.
  interceptWhenVisible,
}

enum ReaderOverlaySemanticRole { loading, status, scrim, chrome, custom }

class ReaderOverlayLayer {
  const ReaderOverlayLayer({
    required this.slot,
    required this.zOrder,
    required this.child,
    this.visible = true,
    this.hitTestPolicy = ReaderOverlayHitTestPolicy.deferToChild,
    this.semanticRole = ReaderOverlaySemanticRole.custom,
  });

  final ReaderForegroundOverlaySlot slot;
  final int zOrder;
  final Widget child;
  final bool visible;
  final ReaderOverlayHitTestPolicy hitTestPolicy;
  final ReaderOverlaySemanticRole semanticRole;
}

class ReaderOverlayLayerModel {
  const ReaderOverlayLayerModel({required this.layers});

  final List<ReaderOverlayLayer> layers;

  List<ReaderOverlayLayer> get visibleLayers {
    final visible = layers.where((layer) => layer.visible).toList();
    visible.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return List<ReaderOverlayLayer>.unmodifiable(visible);
  }
}

class ReaderOverlayLayerRenderer extends StatelessWidget {
  const ReaderOverlayLayerRenderer({
    super.key,
    required this.model,
    this.clipBehavior = Clip.hardEdge,
  });

  final ReaderOverlayLayerModel model;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: clipBehavior,
      children: model.visibleLayers
          .map(_wrapHitTestPolicy)
          .toList(growable: false),
    );
  }

  Widget _wrapHitTestPolicy(ReaderOverlayLayer layer) {
    return switch (layer.hitTestPolicy) {
      ReaderOverlayHitTestPolicy.deferToChild => layer.child,
      ReaderOverlayHitTestPolicy.passThrough => IgnorePointer(
        child: layer.child,
      ),
      ReaderOverlayHitTestPolicy.blockAll => AbsorbPointer(child: layer.child),
    };
  }
}

class ReaderFullScreenHitTestLayer extends StatelessWidget {
  const ReaderFullScreenHitTestLayer({
    super.key,
    required this.strategy,
    required this.child,
    this.visible = true,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  final ReaderFullScreenHitTestStrategy strategy;
  final bool visible;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: _buildHitTestChild());
  }

  Widget _buildHitTestChild() {
    return switch (strategy) {
      ReaderFullScreenHitTestStrategy.passThrough => IgnorePointer(
        child: child,
      ),
      ReaderFullScreenHitTestStrategy.intercept => _buildInterceptingChild(),
      ReaderFullScreenHitTestStrategy.interceptWhenVisible =>
        visible ? _buildInterceptingChild() : IgnorePointer(child: child),
    };
  }

  Widget _buildInterceptingChild() {
    final onTap = this.onTap;
    if (onTap == null) {
      return AbsorbPointer(child: child);
    }
    return GestureDetector(behavior: behavior, onTap: onTap, child: child);
  }
}
