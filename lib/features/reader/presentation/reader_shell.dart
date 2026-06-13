import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_surface_metrics.dart';
import 'widgets/stack/reader_visual_stack.dart';

enum ReaderPresentationViewportKind {
  textScroll,
  textPaged,
  mangaContinuous,
  mangaPaged,
  mangaHorizontal,
}

class ReaderPresentationPalette {
  const ReaderPresentationPalette({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    this.dividerColor = const Color(0x14000000),
    this.scrimColor = const Color(0x22000000),
    this.chromeColor = const Color(0x14000000),
  });

  factory ReaderPresentationPalette.fromColorScheme(ColorScheme scheme) {
    return ReaderPresentationPalette(
      backgroundColor: scheme.surface,
      surfaceColor: scheme.surface,
      primaryTextColor: scheme.onSurface,
      secondaryTextColor: scheme.onSurfaceVariant,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.4),
      scrimColor: scheme.scrim.withValues(alpha: 0.16),
      chromeColor: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
    );
  }

  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color dividerColor;
  final Color scrimColor;
  final Color chromeColor;
}

class ReaderShellChromeSlots {
  const ReaderShellChromeSlots({
    this.backgroundOverlay,
    this.top,
    this.bottom,
    this.leading,
    this.trailing,
    this.center,
    this.foregroundOverlay,
  });

  final Widget? backgroundOverlay;
  final Widget? top;
  final Widget? bottom;
  final Widget? leading;
  final Widget? trailing;
  final Widget? center;
  final Widget? foregroundOverlay;
}

class ReaderShellCallbacks {
  const ReaderShellCallbacks({
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

class ReaderShellModel {
  const ReaderShellModel({
    required this.contentSession,
    required this.settings,
    required this.surfaceMetrics,
    required this.viewportKind,
    required this.palette,
    this.background,
    this.chrome = const ReaderShellChromeSlots(),
    this.callbacks = const ReaderShellCallbacks(),
    this.contentPadding = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
    this.debugLabel,
  });

  final ReaderContentSession contentSession;
  final ReaderSettings settings;
  final ReaderSurfaceMetrics surfaceMetrics;
  final ReaderPresentationViewportKind viewportKind;
  final ReaderPresentationPalette palette;
  final Widget? background;
  final ReaderShellChromeSlots chrome;
  final ReaderShellCallbacks callbacks;
  final EdgeInsets contentPadding;
  final Clip clipBehavior;
  final String? debugLabel;
}

class ReaderShell extends StatelessWidget {
  const ReaderShell({super.key, required this.model, required this.child});

  final ReaderShellModel model;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contentSurfaceColor =
        model.background == null
            ? model.palette.surfaceColor
            : Colors.transparent;
    return ReaderVisualStack(
      model: ReaderVisualStackModel(
        backgroundColor: model.palette.backgroundColor,
        contentSurfaceColor: contentSurfaceColor,
        content: child,
        background: model.background,
        backgroundOverlay: model.chrome.backgroundOverlay,
        center: model.chrome.center,
        top: model.chrome.top,
        bottom: model.chrome.bottom,
        leading: model.chrome.leading,
        trailing: model.chrome.trailing,
        foregroundOverlay: model.chrome.foregroundOverlay,
        callbacks: ReaderVisualStackCallbacks(
          onTapUp: model.callbacks.onTapUp,
          onLongPressStart: model.callbacks.onLongPressStart,
          onDoubleTapDown: model.callbacks.onDoubleTapDown,
          onDoubleTap: model.callbacks.onDoubleTap,
        ),
        contentPadding: model.contentPadding,
        clipBehavior: model.clipBehavior,
      ),
    );
  }
}
