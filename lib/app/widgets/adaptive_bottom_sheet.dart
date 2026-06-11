import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_layout.dart';
import '../motion/app_motion_widgets.dart';
import '../theme/app_component_theme_tokens.dart';

enum AdaptiveActionSurfaceMode { mobileSheet, desktopDialog }

class AdaptiveSheetDragHandle extends StatelessWidget {
  const AdaptiveSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

Future<T?> showAdaptiveActionSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool barrierDismissible = true,
  bool showDragHandle = true,
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
      showDragHandle: showDragHandle,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      builder:
          (surfaceContext) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(surfaceContext).viewInsets.bottom,
            ),
            child: AdaptiveActionSurface(
              mode: AdaptiveActionSurfaceMode.mobileSheet,
              maxWidth: maxWidth,
              maxHeightFactor: maxHeightFactor,
              padding: padding,
              child: builder(surfaceContext),
            ),
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

Future<T?> showAdaptiveRawSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool barrierDismissible = true,
  bool showDragHandle = true,
  Color? mobileBackgroundColor,
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
      showDragHandle: showDragHandle,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      backgroundColor: mobileBackgroundColor,
      constraints: BoxConstraints.tightFor(
        width: MediaQuery.sizeOf(context).width,
      ),
      builder: builder,
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
            child: builder(surfaceContext),
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
        heightFactor: 1,
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
    final dialogTheme = Theme.of(context).dialogTheme;
    final componentTokens = appComponentThemeTokensOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    final backgroundColor =
        dialogTheme.backgroundColor ?? colorScheme.surfaceContainerLow;
    final shadowColor =
        dialogTheme.shadowColor ?? colorScheme.shadow.withValues(alpha: 0.18);
    return AppFadeSlideTransition(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? metrics.dialogMaxWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: backgroundColor,
            elevation: 8,
            shadowColor: shadowColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                componentTokens.overlay.radius,
              ),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.46),
                width: componentTokens.overlay.borderWidth,
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
