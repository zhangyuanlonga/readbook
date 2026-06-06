import 'reader_content_session.dart';
import 'reader_mode_model.dart';

enum ReaderInteractionSurface { mobileTouch, desktopPointer, webPointer }

enum ReaderAdaptiveWidthBand { compact, medium, expanded, wide }

/// 阅读器交互、自适应和可访问性策略。
///
/// 这里不直接构建 widget，只沉淀宽度、文字缩放、键鼠 / 触控能力和可读性规则。
/// 后续继续拆 `ReaderPage`、目录和设置面板时，应优先复用这些决策，避免移动端
/// 和桌面端各自维护一套隐含规则。
class ReaderAccessibilityAdaptivePolicy {
  const ReaderAccessibilityAdaptivePolicy();

  static const List<double> widthAuditPoints = <double>[
    390,
    600,
    840,
    1280,
    1600,
  ];

  ReaderAdaptiveLayoutDecision resolveLayout({
    required double width,
    required bool isDesktopLike,
  }) {
    final normalizedWidth = width.clamp(0.0, 2400.0).toDouble();
    final band =
        normalizedWidth >= 1280
            ? ReaderAdaptiveWidthBand.wide
            : normalizedWidth >= 840
            ? ReaderAdaptiveWidthBand.expanded
            : normalizedWidth >= 600
            ? ReaderAdaptiveWidthBand.medium
            : ReaderAdaptiveWidthBand.compact;
    final usesSidePanel = isDesktopLike && normalizedWidth >= 600;
    return ReaderAdaptiveLayoutDecision(
      width: normalizedWidth,
      band: band,
      usesSidePanel: usesSidePanel,
      contentMaxWidth:
          normalizedWidth >= 840 ? 720 : normalizedWidth.clamp(0.0, 720.0),
      minTouchTarget: normalizedWidth < 600 ? 48 : 40,
      overlayHorizontalInset:
          normalizedWidth >= 1280
              ? 32
              : normalizedWidth >= 600
              ? 24
              : 16,
    );
  }

  ReaderTextScaleDecision resolveTextScale({required double textScaleFactor}) {
    final normalized = textScaleFactor.clamp(0.85, 2.0).toDouble();
    return ReaderTextScaleDecision(
      readerBodyScaleFollowsSettings: true,
      chromeTextScale: normalized.clamp(0.85, 1.20).toDouble(),
      sheetTextScale: normalized.clamp(0.85, 1.15).toDouble(),
    );
  }

  ReaderKeyboardInteractionPolicy resolveKeyboardInteraction({
    required ReaderInteractionSurface surface,
  }) {
    final pointerSurface = surface != ReaderInteractionSurface.mobileTouch;
    return ReaderKeyboardInteractionPolicy(
      showsFocusRing: pointerSurface,
      supportsTabTraversal: pointerSurface,
      escClosesOverlay: pointerSurface,
      enterActivatesFocusedAction: pointerSurface,
      hoverFeedbackEnabled: pointerSurface,
      wheelPageTurnEnabled: pointerSurface,
    );
  }

  ReaderGestureCapability resolveGestureCapability({
    required ReaderContentMode contentMode,
    required ReaderModeViewportKind viewportKind,
    required ReaderInteractionSurface surface,
  }) {
    final mobile = surface == ReaderInteractionSurface.mobileTouch;
    final textMode = contentMode == ReaderContentMode.text;
    final imageMode =
        contentMode == ReaderContentMode.comic ||
        viewportKind == ReaderModeViewportKind.imagePaged ||
        viewportKind == ReaderModeViewportKind.imageScroll;
    final pdfMode =
        contentMode == ReaderContentMode.hybrid &&
        viewportKind == ReaderModeViewportKind.hybridPaged;
    return ReaderGestureCapability(
      supportsTextSelection: textMode,
      supportsAnnotationToolbar: textMode,
      supportsImagePreview: imageMode,
      supportsPdfZoomGesture: pdfMode,
      prefersLongPressSelection: mobile && textMode,
      prefersHoverToolbar: !mobile && textMode,
    );
  }

  ReaderReadabilityDecision resolveReadability({
    required bool hasBackgroundImage,
    required bool darkMode,
    required bool highContrastText,
  }) {
    return ReaderReadabilityDecision(
      shouldDimBackgroundImage: hasBackgroundImage,
      brightnessOverlayAllowed: !highContrastText,
      minimumContrastRatio: highContrastText ? 7.0 : 4.5,
      preferSolidTextScrim: hasBackgroundImage || darkMode || highContrastText,
    );
  }
}

class ReaderAdaptiveLayoutDecision {
  const ReaderAdaptiveLayoutDecision({
    required this.width,
    required this.band,
    required this.usesSidePanel,
    required this.contentMaxWidth,
    required this.minTouchTarget,
    required this.overlayHorizontalInset,
  });

  final double width;
  final ReaderAdaptiveWidthBand band;
  final bool usesSidePanel;
  final double contentMaxWidth;
  final double minTouchTarget;
  final double overlayHorizontalInset;
}

class ReaderTextScaleDecision {
  const ReaderTextScaleDecision({
    required this.readerBodyScaleFollowsSettings,
    required this.chromeTextScale,
    required this.sheetTextScale,
  });

  final bool readerBodyScaleFollowsSettings;
  final double chromeTextScale;
  final double sheetTextScale;
}

class ReaderKeyboardInteractionPolicy {
  const ReaderKeyboardInteractionPolicy({
    required this.showsFocusRing,
    required this.supportsTabTraversal,
    required this.escClosesOverlay,
    required this.enterActivatesFocusedAction,
    required this.hoverFeedbackEnabled,
    required this.wheelPageTurnEnabled,
  });

  final bool showsFocusRing;
  final bool supportsTabTraversal;
  final bool escClosesOverlay;
  final bool enterActivatesFocusedAction;
  final bool hoverFeedbackEnabled;
  final bool wheelPageTurnEnabled;
}

class ReaderGestureCapability {
  const ReaderGestureCapability({
    required this.supportsTextSelection,
    required this.supportsAnnotationToolbar,
    required this.supportsImagePreview,
    required this.supportsPdfZoomGesture,
    required this.prefersLongPressSelection,
    required this.prefersHoverToolbar,
  });

  final bool supportsTextSelection;
  final bool supportsAnnotationToolbar;
  final bool supportsImagePreview;
  final bool supportsPdfZoomGesture;
  final bool prefersLongPressSelection;
  final bool prefersHoverToolbar;
}

class ReaderReadabilityDecision {
  const ReaderReadabilityDecision({
    required this.shouldDimBackgroundImage,
    required this.brightnessOverlayAllowed,
    required this.minimumContrastRatio,
    required this.preferSolidTextScrim,
  });

  final bool shouldDimBackgroundImage;
  final bool brightnessOverlayAllowed;
  final double minimumContrastRatio;
  final bool preferSolidTextScrim;
}
