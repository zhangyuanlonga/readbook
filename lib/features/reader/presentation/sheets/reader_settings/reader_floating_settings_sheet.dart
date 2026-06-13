import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../app/layout/app_adaptive.dart';
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
  final radius = metrics.cardRadius + (useEdgeToEdgeSheet ? 10 : 12);
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
          child: ClipRRect(
            borderRadius:
                useEdgeToEdgeSheet
                    ? BorderRadius.vertical(top: Radius.circular(radius))
                    : BorderRadius.circular(radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: floatingColor,
                borderRadius:
                    useEdgeToEdgeSheet
                        ? BorderRadius.vertical(top: Radius.circular(radius))
                        : BorderRadius.circular(radius),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}
