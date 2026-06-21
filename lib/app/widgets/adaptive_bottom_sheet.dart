import 'dart:ui' show ImageFilter;

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
  bool useRootNavigator = true,
  bool barrierDismissible = true,
  bool showDragHandle = true,
  Color? mobileBackgroundColor,
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
      backgroundColor: mobileBackgroundColor ?? Colors.transparent,
      builder:
          (surfaceContext) => Padding(
            padding: EdgeInsets.only(
              bottom: _keyboardInsetBottom(surfaceContext),
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

double _keyboardInsetBottom(BuildContext context) {
  final mediaQueryInset = MediaQuery.viewInsetsOf(context).bottom;
  final view = View.of(context);
  final rawViewInset = view.viewInsets.bottom / view.devicePixelRatio;
  return mediaQueryInset > rawViewInset ? mediaQueryInset : rawViewInset;
}

Future<T?> showAdaptiveRawSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
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
        maxHeightFactor: maxHeightFactor,
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

class AdaptiveBottomSheet extends StatefulWidget {
  const AdaptiveBottomSheet({
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
  State<AdaptiveBottomSheet> createState() => _AdaptiveBottomSheetState();
}

class _AdaptiveBottomSheetState extends State<AdaptiveBottomSheet> {
  static const double _expandedHeightFactor = 0.96;
  static const double _minimumHeightFactor = 0.32;

  late double _heightFactor;

  @override
  void initState() {
    super.initState();
    _heightFactor = _normalizedInitialHeightFactor;
  }

  @override
  void didUpdateWidget(covariant AdaptiveBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxHeightFactor != widget.maxHeightFactor) {
      _heightFactor = _normalizedInitialHeightFactor;
    }
  }

  double get _normalizedInitialHeightFactor {
    return widget.maxHeightFactor
        .clamp(_minimumHeightFactor, _expandedHeightFactor)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding =
        metrics.sectionGap + (bottomSafeArea > 0 ? bottomSafeArea : 8);
    return AppFadeSlideTransition(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? 0;
          if (delta == 0 || viewportHeight <= 0) {
            return;
          }
          setState(() {
            _heightFactor =
                (_heightFactor - delta / viewportHeight)
                    .clamp(_minimumHeightFactor, _expandedHeightFactor)
                    .toDouble();
          });
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth ?? metrics.bottomSheetMaxWidth,
              maxHeight: viewportHeight * _heightFactor,
            ),
            child: _AdaptiveBlurredSurface(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  appComponentThemeTokensOf(context).overlay.topRadius,
                ),
              ),
              child: Padding(
                padding:
                    widget.padding ??
                    EdgeInsets.fromLTRB(
                      metrics.pagePadding,
                      metrics.contentGap,
                      metrics.pagePadding,
                      bottomPadding,
                    ),
                child: CustomScrollView(
                  shrinkWrap: true,
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  slivers: [SliverToBoxAdapter(child: widget.child)],
                ),
              ),
            ),
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
          child: _AdaptiveBlurredSurface(
            borderRadius: BorderRadius.circular(componentTokens.overlay.radius),
            color: backgroundColor,
            elevation: 8,
            shadowColor: shadowColor,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.46),
              width: componentTokens.overlay.borderWidth,
            ),
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

class _AdaptiveBlurredSurface extends StatelessWidget {
  const _AdaptiveBlurredSurface({
    required this.child,
    required this.borderRadius,
    this.color,
    this.elevation = 0,
    this.shadowColor,
    this.borderSide = BorderSide.none,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final double elevation;
  final Color? shadowColor;
  final BorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomSheetTheme = Theme.of(context).bottomSheetTheme;
    final componentTokens = appComponentThemeTokensOf(context);
    final blurSigma =
        componentTokens.overlay.backgroundBlurSigma.clamp(0.0, 24.0).toDouble();
    final surfaceColor =
        color ??
        bottomSheetTheme.modalBackgroundColor ??
        bottomSheetTheme.backgroundColor ??
        colorScheme.surfaceContainerLow;
    final effectiveColor =
        blurSigma > 0 ? surfaceColor.withValues(alpha: 0.88) : surfaceColor;
    final content = Material(
      color: effectiveColor,
      elevation: elevation,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: borderSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (blurSigma <= 0) {
      return content;
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}
