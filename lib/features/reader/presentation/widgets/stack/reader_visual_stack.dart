import 'package:flutter/material.dart';

import '../../reader_overlay_z_order.dart';
import '../overlay/reader_overlay_layer_model.dart';

class ReaderVisualStackCallbacks {
  const ReaderVisualStackCallbacks({
    this.onTapUp,
    this.onLongPressStart,
    this.onDoubleTapDown,
    this.onDoubleTap,
  });

  final GestureTapUpCallback? onTapUp;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureTapDownCallback? onDoubleTapDown;
  final GestureTapCallback? onDoubleTap;

  bool get hasAnyHandler =>
      onTapUp != null ||
      onLongPressStart != null ||
      onDoubleTapDown != null ||
      onDoubleTap != null;
}

class ReaderVisualStackModel {
  const ReaderVisualStackModel({
    required this.backgroundColor,
    required this.contentSurfaceColor,
    required this.content,
    this.background,
    this.backgroundOverlay,
    this.center,
    this.top,
    this.bottom,
    this.leading,
    this.trailing,
    this.foregroundOverlay,
    this.callbacks = const ReaderVisualStackCallbacks(),
    this.contentPadding = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
  });

  final Color backgroundColor;
  final Color contentSurfaceColor;
  final Widget content;
  final Widget? background;
  final Widget? backgroundOverlay;
  final Widget? center;
  final Widget? top;
  final Widget? bottom;
  final Widget? leading;
  final Widget? trailing;
  final Widget? foregroundOverlay;
  final ReaderVisualStackCallbacks callbacks;
  final EdgeInsets contentPadding;
  final Clip clipBehavior;
}

/// The single reader visual stack.
///
/// It owns only visual ordering and hit-test policy for the reader surface.
/// Business commands and renderer state must be resolved before reaching here.
class ReaderVisualStack extends StatelessWidget {
  const ReaderVisualStack({super.key, required this.model});

  final ReaderVisualStackModel model;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: model.contentPadding,
      child: model.content,
    );
    final stackedContent = Stack(
      clipBehavior: model.clipBehavior,
      children: readerShellLayerOrder
          .map((slot) => _buildLayer(slot, content: content))
          .whereType<Widget>()
          .toList(growable: false),
    );

    if (!model.callbacks.hasAnyHandler) {
      return stackedContent;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: model.callbacks.onTapUp,
      onLongPressStart: model.callbacks.onLongPressStart,
      onDoubleTapDown: model.callbacks.onDoubleTapDown,
      onDoubleTap: model.callbacks.onDoubleTap,
      child: stackedContent,
    );
  }

  Widget? _buildLayer(ReaderShellLayerSlot slot, {required Widget content}) {
    return switch (slot) {
      ReaderShellLayerSlot.background => Positioned.fill(
        child: ColoredBox(
          color: model.backgroundColor,
          child: model.background ?? const SizedBox.shrink(),
        ),
      ),
      ReaderShellLayerSlot.backgroundOverlay =>
        model.backgroundOverlay == null
            ? null
            : ReaderFullScreenHitTestLayer(
              strategy: ReaderFullScreenHitTestStrategy.passThrough,
              child: model.backgroundOverlay!,
            ),
      ReaderShellLayerSlot.content => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(color: model.contentSurfaceColor),
          child: content,
        ),
      ),
      ReaderShellLayerSlot.center =>
        model.center == null
            ? null
            : ReaderFullScreenHitTestLayer(
              strategy: ReaderFullScreenHitTestStrategy.passThrough,
              child: model.center!,
            ),
      ReaderShellLayerSlot.top =>
        model.top == null
            ? null
            : Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: model.top!),
            ),
      ReaderShellLayerSlot.bottom =>
        model.bottom == null
            ? null
            : Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: model.bottom!),
            ),
      ReaderShellLayerSlot.leading =>
        model.leading == null
            ? null
            : Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SafeArea(right: false, child: model.leading!),
            ),
      ReaderShellLayerSlot.trailing =>
        model.trailing == null
            ? null
            : Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(left: false, child: model.trailing!),
            ),
      ReaderShellLayerSlot.foregroundOverlay =>
        model.foregroundOverlay == null
            ? null
            : Positioned.fill(child: model.foregroundOverlay!),
    };
  }
}
