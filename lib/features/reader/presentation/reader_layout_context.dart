import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_size_tokens.dart';
import '../application/reader_mode_model.dart';

/// 阅读器浮层的展示形态。
///
/// 移动端继续使用 bottom sheet；桌面端的目录和设置使用靠右 side panel；
/// 少量二级选择器、更多操作可以使用 dialog，避免把桌面交互塞回移动端弹层。
enum ReaderPanelPresentation { bottomSheet, sidePanel, dialog }

/// 阅读器浮层的业务角色，用来把“目录 / 设置 / 二级操作”的桌面形态固定下来。
enum ReaderPanelRole { catalog, settings, auxiliaryAction }

/// 阅读器 overlay 动作入口的位置。
///
/// 手机端保留底部大按钮栏；桌面端把动作收到顶部工具条，底部只保留进度控制，
/// 避免把触控式底栏拉宽到键鼠场景。
enum ReaderOverlayActionPlacement { bottomBar, topToolbar }

/// 阅读器浮层布局策略。
///
/// 该对象只描述 UI 展示边界，不承载章节、设置或书签业务状态。后续维护桌面
/// 阅读器时应优先扩展这里，而不是在目录、设置等面板内继续散落宽度判断。
class ReaderPanelLayoutSpec {
  const ReaderPanelLayoutSpec({
    required this.presentation,
    required this.alignment,
    required this.maxWidth,
    required this.outerPadding,
    required this.heightFactor,
    required this.showDragHandle,
    required this.edgeToEdge,
  });

  final ReaderPanelPresentation presentation;
  final Alignment alignment;
  final double maxWidth;
  final EdgeInsets outerPadding;
  final double heightFactor;
  final bool showDragHandle;
  final bool edgeToEdge;

  bool get isSidePanel => presentation == ReaderPanelPresentation.sidePanel;
  bool get isBottomSheet => presentation == ReaderPanelPresentation.bottomSheet;
  bool get isDialog => presentation == ReaderPanelPresentation.dialog;
}

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

  ReaderOverlayActionPlacement get overlayActionPlacement =>
      isDesktopLike
          ? ReaderOverlayActionPlacement.topToolbar
          : ReaderOverlayActionPlacement.bottomBar;

  bool get showsBottomActionBar =>
      overlayActionPlacement == ReaderOverlayActionPlacement.bottomBar;

  double get desktopProgressMaxWidth {
    if (!isDesktopLike) {
      return metrics.width;
    }
    if (metrics.isExpandedWindow) {
      return math.min(820, metrics.width - metrics.pagePadding * 2);
    }
    return math.max(320, metrics.width - metrics.pagePadding * 2);
  }

  double get catalogSidePanelMaxWidth {
    if (metrics.isExpandedWindow) {
      return 420;
    }
    if (metrics.isMediumWindow) {
      return 380;
    }
    return math.max(320, metrics.width - metrics.pagePadding * 2);
  }

  double get settingsSidePanelMaxWidth {
    if (metrics.isExpandedWindow) {
      return 520;
    }
    if (metrics.isMediumWindow) {
      return 480;
    }
    return math.max(320, metrics.width - metrics.pagePadding * 2);
  }

  double get sidePanelMaxWidth => settingsSidePanelMaxWidth;

  ReaderPanelLayoutSpec panelLayoutFor(
    ReaderPanelRole role, {
    double preferredHeightFactor = 0.82,
  }) {
    final presentation = _panelPresentationFor(role);
    final heightFactor = _panelHeightFactorFor(
      role,
      presentation: presentation,
      preferredHeightFactor: preferredHeightFactor,
    );

    return ReaderPanelLayoutSpec(
      presentation: presentation,
      alignment: _panelAlignmentFor(presentation),
      maxWidth: _panelMaxWidthFor(role, presentation: presentation),
      outerPadding: _panelOuterPaddingFor(presentation),
      heightFactor: heightFactor,
      showDragHandle: presentation == ReaderPanelPresentation.bottomSheet,
      edgeToEdge: presentation == ReaderPanelPresentation.bottomSheet,
    );
  }

  ReaderPanelPresentation _panelPresentationFor(ReaderPanelRole role) {
    if (!isDesktopLike) {
      return ReaderPanelPresentation.bottomSheet;
    }
    return switch (role) {
      ReaderPanelRole.catalog ||
      ReaderPanelRole.settings => ReaderPanelPresentation.sidePanel,
      ReaderPanelRole.auxiliaryAction => ReaderPanelPresentation.dialog,
    };
  }

  Alignment _panelAlignmentFor(ReaderPanelPresentation presentation) {
    return switch (presentation) {
      ReaderPanelPresentation.bottomSheet => Alignment.bottomCenter,
      ReaderPanelPresentation.sidePanel => Alignment.centerRight,
      ReaderPanelPresentation.dialog => Alignment.center,
    };
  }

  EdgeInsets _panelOuterPaddingFor(ReaderPanelPresentation presentation) {
    return switch (presentation) {
      ReaderPanelPresentation.bottomSheet => EdgeInsets.zero,
      ReaderPanelPresentation.sidePanel => EdgeInsets.symmetric(
        horizontal: metrics.pagePadding,
        vertical: metrics.isCompactDensity ? 16 : 24,
      ),
      ReaderPanelPresentation.dialog => EdgeInsets.all(
        metrics.isCompactDensity ? 16 : 24,
      ),
    };
  }

  double _panelMaxWidthFor(
    ReaderPanelRole role, {
    required ReaderPanelPresentation presentation,
  }) {
    if (presentation == ReaderPanelPresentation.bottomSheet) {
      return metrics.bottomSheetMaxWidth;
    }
    if (presentation == ReaderPanelPresentation.dialog) {
      return math.min(420, metrics.dialogMaxWidth);
    }
    return switch (role) {
      ReaderPanelRole.catalog => catalogSidePanelMaxWidth,
      ReaderPanelRole.settings => settingsSidePanelMaxWidth,
      ReaderPanelRole.auxiliaryAction => math.min(420, metrics.dialogMaxWidth),
    };
  }

  double _panelHeightFactorFor(
    ReaderPanelRole role, {
    required ReaderPanelPresentation presentation,
    required double preferredHeightFactor,
  }) {
    if (presentation == ReaderPanelPresentation.bottomSheet) {
      return preferredHeightFactor.clamp(0.0, 1.0).toDouble();
    }
    if (presentation == ReaderPanelPresentation.dialog) {
      return preferredHeightFactor.clamp(0.42, 0.82).toDouble();
    }
    return switch (role) {
      ReaderPanelRole.catalog => 1.0,
      ReaderPanelRole.settings =>
        preferredHeightFactor
            .clamp(0.72, metrics.height < 640 ? 0.96 : 0.9)
            .toDouble(),
      ReaderPanelRole.auxiliaryAction =>
        preferredHeightFactor.clamp(0.42, 0.82).toDouble(),
    };
  }
}
