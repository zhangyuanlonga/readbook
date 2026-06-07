import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/layout/app_adaptive.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_layout_context.dart';

void main() {
  test('text reader caps expanded content width while image reader fills', () {
    final expandedMetrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(1280, 800),
    );

    final textContext = ReaderLayoutContext.fromMetrics(
      metrics: expandedMetrics,
      viewportKind: ReaderModeViewportKind.textPaged,
      isWeb: false,
      platform: TargetPlatform.macOS,
    );
    final imageContext = ReaderLayoutContext.fromMetrics(
      metrics: expandedMetrics,
      viewportKind: ReaderModeViewportKind.imagePaged,
      isWeb: false,
      platform: TargetPlatform.macOS,
    );

    expect(textContext.contentMaxWidth, 720);
    expect(imageContext.contentMaxWidth, isNull);
  });

  test('reader panels use side panel only on desktop-like surfaces', () {
    final phoneMetrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(390, 844),
    );
    final desktopMetrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(900, 800),
    );

    final phoneContext = ReaderLayoutContext.fromMetrics(
      metrics: phoneMetrics,
      viewportKind: ReaderModeViewportKind.textScroll,
      isWeb: false,
      platform: TargetPlatform.android,
    );
    final desktopContext = ReaderLayoutContext.fromMetrics(
      metrics: desktopMetrics,
      viewportKind: ReaderModeViewportKind.textScroll,
      isWeb: false,
      platform: TargetPlatform.windows,
    );

    expect(
      phoneContext.catalogPanelPresentation,
      ReaderPanelPresentation.bottomSheet,
    );
    expect(
      desktopContext.catalogPanelPresentation,
      ReaderPanelPresentation.sidePanel,
    );
    expect(
      desktopContext.settingsPanelPresentation,
      ReaderPanelPresentation.sidePanel,
    );
    expect(desktopContext.sidePanelMaxWidth, 520);
  });

  test(
    'reader desktop panel specs preserve mobile sheet and desktop panels',
    () {
      final phoneContext = ReaderLayoutContext.fromMetrics(
        metrics: AppAdaptiveMetrics.resolveForSize(size: const Size(390, 844)),
        viewportKind: ReaderModeViewportKind.textScroll,
        isWeb: false,
        platform: TargetPlatform.android,
      );
      final narrowDesktopContext = ReaderLayoutContext.fromMetrics(
        metrics: AppAdaptiveMetrics.resolveForSize(size: const Size(600, 800)),
        viewportKind: ReaderModeViewportKind.textScroll,
        isWeb: false,
        platform: TargetPlatform.windows,
      );
      final desktopContext = ReaderLayoutContext.fromMetrics(
        metrics: AppAdaptiveMetrics.resolveForSize(size: const Size(1280, 820)),
        viewportKind: ReaderModeViewportKind.textScroll,
        isWeb: false,
        platform: TargetPlatform.macOS,
      );

      final mobileSettings = phoneContext.panelLayoutFor(
        ReaderPanelRole.settings,
        preferredHeightFactor: 0.8,
      );
      final narrowCatalog = narrowDesktopContext.panelLayoutFor(
        ReaderPanelRole.catalog,
      );
      final desktopSettings = desktopContext.panelLayoutFor(
        ReaderPanelRole.settings,
        preferredHeightFactor: 0.5,
      );
      final desktopAuxiliary = desktopContext.panelLayoutFor(
        ReaderPanelRole.auxiliaryAction,
        preferredHeightFactor: 0.56,
      );

      expect(
        phoneContext.overlayActionPlacement,
        ReaderOverlayActionPlacement.bottomBar,
      );
      expect(mobileSettings.presentation, ReaderPanelPresentation.bottomSheet);
      expect(mobileSettings.alignment, Alignment.bottomCenter);
      expect(mobileSettings.showDragHandle, isTrue);
      expect(mobileSettings.edgeToEdge, isTrue);
      expect(
        narrowDesktopContext.overlayActionPlacement,
        ReaderOverlayActionPlacement.topToolbar,
      );
      expect(narrowDesktopContext.showsBottomActionBar, isFalse);
      expect(narrowCatalog.presentation, ReaderPanelPresentation.sidePanel);
      expect(narrowCatalog.maxWidth, 380);
      expect(narrowCatalog.alignment, Alignment.centerRight);
      expect(desktopSettings.presentation, ReaderPanelPresentation.sidePanel);
      expect(desktopSettings.maxWidth, 520);
      expect(desktopSettings.heightFactor, 0.72);
      expect(desktopSettings.outerPadding, const EdgeInsets.all(24));
      expect(desktopAuxiliary.presentation, ReaderPanelPresentation.dialog);
      expect(desktopAuxiliary.alignment, Alignment.center);
      expect(desktopAuxiliary.maxWidth, 420);
    },
  );

  test(
    'reader width policy covers compact through wide desktop breakpoints',
    () {
      ReaderLayoutContext resolve(double width, TargetPlatform platform) {
        return ReaderLayoutContext.fromMetrics(
          metrics: AppAdaptiveMetrics.resolveForSize(size: Size(width, 820)),
          viewportKind: ReaderModeViewportKind.textPaged,
          isWeb: false,
          platform: platform,
        );
      }

      final compact = resolve(390, TargetPlatform.android);
      final mediumDesktop = resolve(600, TargetPlatform.linux);
      final expandedDesktop = resolve(840, TargetPlatform.linux);
      final regularDesktop = resolve(1280, TargetPlatform.windows);
      final wideDesktop = resolve(1600, TargetPlatform.macOS);

      expect(compact.contentMaxWidth, isNull);
      expect(
        compact.panelLayoutFor(ReaderPanelRole.settings).presentation,
        ReaderPanelPresentation.bottomSheet,
      );
      expect(mediumDesktop.contentMaxWidth, isNull);
      expect(mediumDesktop.catalogSidePanelMaxWidth, 380);
      expect(mediumDesktop.desktopProgressMaxWidth, 560);
      expect(expandedDesktop.contentMaxWidth, 720);
      expect(expandedDesktop.catalogSidePanelMaxWidth, 420);
      expect(expandedDesktop.desktopProgressMaxWidth, 792);
      expect(regularDesktop.settingsSidePanelMaxWidth, 520);
      expect(wideDesktop.contentMaxWidth, 720);
      expect(wideDesktop.desktopProgressMaxWidth, 820);
    },
  );

  test('ReaderSizes derives proportional reading metrics from font size', () {
    const sizes = ReaderSizes(18);

    expect(sizes.lineHeight, 32.4);
    expect(sizes.paragraphSpacing, 14.4);
    expect(sizes.pagePaddingH, closeTo(21.6, 0.0001));
    expect(sizes.indentSize, 36);
    expect(sizes.imageCaptionSize, closeTo(15.3, 0.0001));
  });
}
