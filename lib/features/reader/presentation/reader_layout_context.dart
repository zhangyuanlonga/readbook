import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_size_tokens.dart';
import '../application/reader_mode_model.dart';

enum ReaderPanelPresentation { bottomSheet, sidePanel }

class ReaderSizes {
  const ReaderSizes(this.fontSize);

  final double fontSize;

  double get lineHeight => fontSize * 1.8;
  double get paragraphSpacing => fontSize * 0.8;
  double get pagePaddingH => fontSize * 1.2;
  double get pagePaddingV => fontSize;
  double get indentSize => fontSize * 2;
  double get blockQuoteIndent => fontSize * 1.5;
  double get imageCaptionSize => fontSize * 0.85;
}

class ReaderLayoutContext {
  const ReaderLayoutContext({
    required this.metrics,
    required this.viewportKind,
    required this.isDesktopLike,
  });

  final AppAdaptiveMetrics metrics;
  final ReaderModeViewportKind viewportKind;
  final bool isDesktopLike;

  factory ReaderLayoutContext.resolve(
    BuildContext context, {
    ReaderModeViewportKind viewportKind = ReaderModeViewportKind.textPaged,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    return ReaderLayoutContext.fromMetrics(
      metrics: metrics,
      viewportKind: viewportKind,
      isWeb: kIsWeb,
      platform: Theme.of(context).platform,
    );
  }

  factory ReaderLayoutContext.fromMetrics({
    required AppAdaptiveMetrics metrics,
    required ReaderModeViewportKind viewportKind,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return ReaderLayoutContext(
      metrics: metrics,
      viewportKind: viewportKind,
      isDesktopLike: metrics.isDesktopLikeForPlatform(
        isWeb: isWeb,
        platform: platform,
      ),
    );
  }

  bool get isTextViewport =>
      viewportKind == ReaderModeViewportKind.textPaged ||
      viewportKind == ReaderModeViewportKind.textScroll;

  bool get isImageViewport =>
      viewportKind == ReaderModeViewportKind.imagePaged ||
      viewportKind == ReaderModeViewportKind.imageScroll;

  double? get contentMaxWidth {
    if (!isTextViewport || !metrics.isExpandedWindow) {
      return null;
    }
    return AppSizeTokens.readerTextContentMaxWidth;
  }

  ReaderPanelPresentation get catalogPanelPresentation =>
      isDesktopLike
          ? ReaderPanelPresentation.sidePanel
          : ReaderPanelPresentation.bottomSheet;

  ReaderPanelPresentation get settingsPanelPresentation =>
      isDesktopLike
          ? ReaderPanelPresentation.sidePanel
          : ReaderPanelPresentation.bottomSheet;

  double get sidePanelMaxWidth {
    if (metrics.isExpandedWindow) {
      return 520;
    }
    if (metrics.isMediumWindow) {
      return 480;
    }
    return math.max(320, metrics.width - metrics.pagePadding * 2);
  }
}
