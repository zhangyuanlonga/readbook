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

  test('ReaderSizes derives proportional reading metrics from font size', () {
    const sizes = ReaderSizes(18);

    expect(sizes.lineHeight, 32.4);
    expect(sizes.paragraphSpacing, 14.4);
    expect(sizes.pagePaddingH, closeTo(21.6, 0.0001));
    expect(sizes.indentSize, 36);
    expect(sizes.imageCaptionSize, closeTo(15.3, 0.0001));
  });
}
