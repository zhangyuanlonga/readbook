import 'dart:async';

import 'package:flutter/material.dart';

import '../application/reader_layout_diagnostics_service.dart';
import '../application/reader_layout_renderer_controller.dart';
import '../application/reader_layout_request.dart';
import 'reader_layout_paged_view.dart';

typedef ReaderLayoutLegacyRendererBuilder =
    Widget Function(BuildContext context, ReaderLayoutRendererState state);

typedef ReaderLayoutRendererLoadingBuilder =
    Widget Function(BuildContext context, ReaderLayoutRendererState? state);

typedef ReaderLayoutRendererDiagnosticsBuilder =
    Widget Function(BuildContext context, ReaderLayoutRendererState state);

class ReaderLayoutRendererPreviewSurface extends StatefulWidget {
  const ReaderLayoutRendererPreviewSurface({
    super.key,
    required this.request,
    this.options = const ReaderLayoutDevOptions(),
    this.controller,
    this.targetRatio = 0,
    this.initialPageIndex,
    this.nearbyPageRadius = 1,
    this.legacyBuilder,
    this.loadingBuilder,
    this.diagnosticsBuilder,
    this.showDiagnosticsOverlay = false,
    this.onDiagnostics,
    this.onPageChanged,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor,
    this.physics,
  });

  final ReaderLayoutRequest request;
  final ReaderLayoutDevOptions options;
  final ReaderLayoutRendererController? controller;
  final double targetRatio;
  final int? initialPageIndex;
  final int nearbyPageRadius;
  final ReaderLayoutLegacyRendererBuilder? legacyBuilder;
  final ReaderLayoutRendererLoadingBuilder? loadingBuilder;
  final ReaderLayoutRendererDiagnosticsBuilder? diagnosticsBuilder;
  final bool showDiagnosticsOverlay;
  final ValueChanged<ReaderLayoutRendererState>? onDiagnostics;
  final ValueChanged<int>? onPageChanged;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color? highlightColor;
  final ScrollPhysics? physics;

  @override
  State<ReaderLayoutRendererPreviewSurface> createState() =>
      _ReaderLayoutRendererPreviewSurfaceState();
}

class _ReaderLayoutRendererPreviewSurfaceState
    extends State<ReaderLayoutRendererPreviewSurface> {
  ReaderLayoutRendererController? _ownedController;
  StreamSubscription<ReaderLayoutRendererState>? _subscription;
  ReaderLayoutRendererState? _state;

  ReaderLayoutRendererController get _controller {
    return widget.controller ??
        (_ownedController ??= ReaderLayoutRendererController());
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ReaderLayoutRendererPreviewSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldResubscribe(oldWidget)) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ownedController?.cancelActive();
    super.dispose();
  }

  bool _shouldResubscribe(ReaderLayoutRendererPreviewSurface oldWidget) {
    return oldWidget.controller != widget.controller ||
        oldWidget.request.chapterId != widget.request.chapterId ||
        oldWidget.request.chapterIndex != widget.request.chapterIndex ||
        oldWidget.request.layoutSignature != widget.request.layoutSignature ||
        oldWidget.request.totalContentLength !=
            widget.request.totalContentLength ||
        oldWidget.options.mode != widget.options.mode ||
        oldWidget.targetRatio != widget.targetRatio ||
        oldWidget.initialPageIndex != widget.initialPageIndex ||
        oldWidget.nearbyPageRadius != widget.nearbyPageRadius;
  }

  void _subscribe() {
    _subscription?.cancel();
    _state = null;
    _subscription = _controller
        .watch(
          widget.request,
          options: widget.options,
          targetRatio: widget.targetRatio,
          initialPageIndex: widget.initialPageIndex,
          nearbyPageRadius: widget.nearbyPageRadius,
        )
        .listen((state) {
          widget.onDiagnostics?.call(state);
          if (!mounted) {
            return;
          }
          setState(() {
            _state = state;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null || state.kind == ReaderLayoutRendererStateKind.loading) {
      return widget.loadingBuilder?.call(context, state) ??
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (state.shouldUseLegacyRenderer) {
      return widget.legacyBuilder?.call(context, state) ??
          const SizedBox.shrink();
    }

    if (!state.canRenderLayout) {
      return widget.legacyBuilder?.call(context, state) ??
          const SizedBox.shrink();
    }

    final diagnosticsOverlay =
        widget.showDiagnosticsOverlay
            ? widget.diagnosticsBuilder?.call(context, state) ??
                _ReaderLayoutDiagnosticsOverlay(state: state)
            : null;
    return ReaderLayoutPagedView(
      pages: state.pages,
      pageIndex: state.pageIndex,
      onPageChanged: widget.onPageChanged,
      physics: widget.physics,
      textStyle: widget.textStyle,
      titleStyle: widget.titleStyle,
      imagePlaceholderBuilder: widget.imagePlaceholderBuilder,
      annotationRanges: widget.annotationRanges,
      highlightColor: widget.highlightColor,
      diagnosticsOverlay: diagnosticsOverlay,
    );
  }
}

class _ReaderLayoutDiagnosticsOverlay extends StatelessWidget {
  const _ReaderLayoutDiagnosticsOverlay({required this.state});

  final ReaderLayoutRendererState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label =
        '${state.effectiveMode.name} · ${state.pages.length}p'
        '${state.fromCache ? ' · cache' : ''}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
