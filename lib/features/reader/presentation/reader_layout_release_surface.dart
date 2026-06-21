import 'package:flutter/material.dart';

import '../application/reader_layout_diagnostics_service.dart';
import '../application/reader_layout_renderer_controller.dart';
import '../application/reader_layout_request.dart';
import '../application/reader_selection_runtime.dart';
import 'reader_layout_paged_view.dart';
import 'reader_layout_renderer_preview_surface.dart';

class ReaderLayoutReleaseSurface extends StatelessWidget {
  const ReaderLayoutReleaseSurface({
    super.key,
    required this.request,
    required this.options,
    required this.controller,
    this.targetRatio = 0,
    this.initialPageIndex,
    this.pageIndex,
    this.nearbyPageRadius = 1,
    this.loadingBuilder,
    this.readyBuilder,
    this.showDiagnosticsOverlay = false,
    this.onDiagnostics,
    this.onPageChanged,
    this.onSelectionChanged,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor,
    this.physics,
    this.selectionRuntime = const ReaderSelectionRuntime(),
  });

  final ReaderLayoutRequest request;
  final ReaderLayoutDevOptions options;
  final ReaderLayoutRendererController controller;
  final double targetRatio;
  final int? initialPageIndex;
  final int? pageIndex;
  final int nearbyPageRadius;
  final ReaderLayoutRendererLoadingBuilder? loadingBuilder;
  final ReaderLayoutRendererReadyBuilder? readyBuilder;
  final bool showDiagnosticsOverlay;
  final ValueChanged<ReaderLayoutRendererState>? onDiagnostics;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderLayoutSelectionSnapshot>? onSelectionChanged;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color? highlightColor;
  final ScrollPhysics? physics;
  final ReaderSelectionRuntime selectionRuntime;

  @override
  Widget build(BuildContext context) {
    return ReaderLayoutRendererPreviewSurface(
      request: request,
      options: options,
      controller: controller,
      targetRatio: targetRatio,
      initialPageIndex: initialPageIndex,
      pageIndex: pageIndex,
      nearbyPageRadius: nearbyPageRadius,
      loadingBuilder: loadingBuilder,
      readyBuilder: readyBuilder,
      showDiagnosticsOverlay: showDiagnosticsOverlay,
      onDiagnostics: onDiagnostics,
      onPageChanged: onPageChanged,
      onSelectionChanged: onSelectionChanged,
      textStyle: textStyle,
      titleStyle: titleStyle,
      imagePlaceholderBuilder: imagePlaceholderBuilder,
      annotationRanges: annotationRanges,
      highlightColor: highlightColor,
      physics: physics,
      selectionRuntime: selectionRuntime,
    );
  }
}
