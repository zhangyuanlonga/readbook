import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_layout.dart';
import '../motion/app_motion_widgets.dart';

enum AdaptiveActionSurfaceMode { mobileSheet, desktopDialog }

Future<T?> showAdaptiveActionSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool barrierDismissible = true,
  double? maxWidth,
  double maxHeightFactor = 0.82,
  EdgeInsetsGeometry? padding,
  AdaptiveActionSurfaceMode? mode,
}) {
  final platform = Theme.of(context).platform;
  final effectiveMode =
      mode ??
      (AppLayout.isDesktopLike(context, platform: platform)
          ? AdaptiveActionSurfaceMode.desktopDialog
          : AdaptiveActionSurfaceMode.mobileSheet);

  return switch (effectiveMode) {
    AdaptiveActionSurfaceMode.mobileSheet => showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      builder:
          (surfaceContext) => AdaptiveActionSurface(
            mode: AdaptiveActionSurfaceMode.mobileSheet,
            maxWidth: maxWidth,
            maxHeightFactor: maxHeightFactor,
            padding: padding,
            child: builder(surfaceContext),
          ),
    ),
    AdaptiveActionSurfaceMode.desktopDialog => showDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      builder:
          (surfaceContext) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: AdaptiveActionSurface(
              mode: AdaptiveActionSurfaceMode.desktopDialog,
              maxWidth: maxWidth,
              maxHeightFactor: maxHeightFactor,
              padding: padding,
              child: builder(surfaceContext),
            ),
          ),
    ),
  };
}

class AdaptiveActionSurface extends StatelessWidget {
  const AdaptiveActionSurface({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeightFactor = 0.82,
    this.padding,
    this.mode,
  });

  final Widget child;
  final double? maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;
  final AdaptiveActionSurfaceMode? mode;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final effectiveMode =
        mode ??
        (AppLayout.isDesktopLike(context, platform: platform)
            ? AdaptiveActionSurfaceMode.desktopDialog
            : AdaptiveActionSurfaceMode.mobileSheet);

    return switch (effectiveMode) {
      AdaptiveActionSurfaceMode.mobileSheet => AdaptiveBottomSheet(
        maxWidth: maxWidth,
        padding: padding,
        child: child,
      ),
      AdaptiveActionSurfaceMode.desktopDialog => AdaptiveDialogSurface(
        maxWidth: maxWidth,
        maxHeightFactor: maxHeightFactor,
        padding: padding,
        child: child,
      ),
    };
  }
}

class AdaptiveBottomSheet extends StatelessWidget {
  const AdaptiveBottomSheet({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return AppFadeSlideTransition(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? metrics.bottomSheetMaxWidth,
          ),
          child: Padding(
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  metrics.pagePadding,
                  metrics.contentGap,
                  metrics.pagePadding,
                  metrics.sectionGap,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AdaptiveDialogSurface extends StatelessWidget {
  const AdaptiveDialogSurface({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeightFactor = 0.82,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    return AppFadeSlideTransition(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? metrics.dialogMaxWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: colorScheme.surface,
            elevation: 8,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.46),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding:
                  padding ?? EdgeInsets.all(metrics.isCompactDensity ? 16 : 20),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
