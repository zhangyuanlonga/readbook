import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'reader_icons.dart';

class ReaderPdfViewportSnapshot {
  const ReaderPdfViewportSnapshot({
    required this.pageIndex,
    required this.pageCount,
    required this.zoomScale,
    required this.panDx,
    required this.panDy,
  });

  final int? pageIndex;
  final int pageCount;
  final double zoomScale;
  final double panDx;
  final double panDy;
}

class ReaderPdfView extends StatefulWidget {
  const ReaderPdfView({
    super.key,
    required this.filePath,
    this.initialPage = 1,
    this.initialZoomScale,
    this.initialPanDx,
    this.initialPanDy,
    this.onPageChanged,
    this.onViewportChanged,
    this.onViewerReady,
    this.errorBuilder,
  });

  final String filePath;
  final int initialPage;
  final double? initialZoomScale;
  final double? initialPanDx;
  final double? initialPanDy;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderPdfViewportSnapshot>? onViewportChanged;
  final void Function(PdfViewerController controller, int pageCount)?
  onViewerReady;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<ReaderPdfView> createState() => _ReaderPdfViewState();
}

class _ReaderPdfViewState extends State<ReaderPdfView> {
  late final PdfViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filePath = widget.filePath.trim();
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      return _buildError(context, StateError('PDF 文件不存在或路径为空'));
    }

    return PdfViewer.file(
      filePath,
      controller: _controller,
      initialPageNumber: widget.initialPage.clamp(1, 1 << 20),
      params: PdfViewerParams(
        backgroundColor: Theme.of(context).colorScheme.surface,
        // UI-GOV-EXEMPT: box-shadow pdf-page-depth
        pageDropShadow: BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
          maxScale: 6,
        ),
        onViewerReady: (document, controller) {
          widget.onViewerReady?.call(controller, document.pages.length);
          _restoreInitialDocumentPosition(controller);
          _emitViewportChanged();
        },
        onPageChanged: (pageNumber) {
          if (pageNumber != null) {
            widget.onPageChanged?.call(pageNumber);
            _emitViewportChanged();
          }
        },
      ),
    );
  }

  void _handleControllerChanged() {
    _emitViewportChanged();
  }

  void _restoreInitialDocumentPosition(PdfViewerController controller) {
    final zoomScale = widget.initialZoomScale;
    final panDx = widget.initialPanDx;
    final panDy = widget.initialPanDy;
    if (zoomScale == null && panDx == null && panDy == null) {
      return;
    }
    final visibleRect = controller.visibleRect;
    unawaited(
      controller.goToPosition(
        documentOffset: Offset(
          panDx ?? visibleRect.left,
          panDy ?? visibleRect.top,
        ),
        zoom: zoomScale,
        duration: Duration.zero,
      ),
    );
  }

  void _emitViewportChanged() {
    final callback = widget.onViewportChanged;
    if (callback == null || !_controller.isReady) {
      return;
    }
    final pageNumber = _controller.pageNumber;
    final visibleRect = _controller.visibleRect;
    callback(
      ReaderPdfViewportSnapshot(
        pageIndex: pageNumber == null ? null : pageNumber - 1,
        pageCount: _controller.pageCount,
        zoomScale: _controller.currentZoom,
        panDx: visibleRect.left,
        panDy: visibleRect.top,
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final custom = widget.errorBuilder;
    if (custom != null) {
      return custom(context, error);
    }
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ReaderIcons.pdf, size: 36, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'PDF 打开失败',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
