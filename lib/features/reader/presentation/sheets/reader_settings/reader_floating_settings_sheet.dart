import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../app/layout/app_adaptive.dart';
import '../../../../../app/theme/app_component_theme_tokens.dart';
import '../../../../../app/widgets/foundation/foundation.dart';
import '../../../application/reader_mode_model.dart';
import '../../reader_layout_context.dart';

Widget buildReaderFloatingSettingsSheet({
  required BuildContext context,
  required ThemeData readerModalTheme,
  required ReaderModeViewportKind viewportKind,
  required double keyboardInset,
  required double safeBottom,
  required double sheetHorizontal,
  required double maxWidth,
  required double heightFactor,
  Color? backgroundColor,
  required Widget child,
}) {
  final metrics = AppAdaptiveMetrics.of(context);
  final componentTokens = appComponentThemeTokensOf(context);
  final readerLayoutContext = ReaderLayoutContext.resolve(
    context,
    viewportKind: viewportKind,
  );
  final floatingColor =
      backgroundColor ??
      readerModalTheme.colorScheme.surface.withValues(alpha: 0.9);
  final borderColor = readerModalTheme.colorScheme.outlineVariant.withValues(
    alpha: 0.35,
  );
  final panelSpec = readerLayoutContext.panelLayoutFor(
    ReaderPanelRole.settings,
    preferredHeightFactor: heightFactor,
  );
  final useEdgeToEdgeSheet = panelSpec.edgeToEdge;
  final radius =
      componentTokens.overlay.radius +
      metrics.cardRadius * (useEdgeToEdgeSheet ? 0.35 : 0.45);
  final borderRadius =
      useEdgeToEdgeSheet
          ? BorderRadius.vertical(top: Radius.circular(radius))
          : BorderRadius.all(Radius.circular(radius));
  final resolvedMaxWidth = min(maxWidth, panelSpec.maxWidth);

  return AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.fromLTRB(
      panelSpec.outerPadding.left,
      panelSpec.outerPadding.top,
      panelSpec.outerPadding.right,
      keyboardInset +
          (useEdgeToEdgeSheet
              ? 0
              : max(panelSpec.outerPadding.bottom, safeBottom)),
    ),
    child: Align(
      alignment: panelSpec.alignment,
      child: FractionallySizedBox(
        heightFactor: panelSpec.heightFactor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: useEdgeToEdgeSheet ? double.infinity : resolvedMaxWidth,
          ),
          child: AppSurface(
            tone: AppSurfaceTone.elevated,
            padding: EdgeInsets.zero,
            borderRadius: borderRadius,
            borderColor: borderColor,
            backgroundColor: floatingColor,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    ),
  );
}
