import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:turnable_page/turnable_page.dart';

class ReaderPaperCurlPagedView extends StatefulWidget {
  const ReaderPaperCurlPagedView({
    super.key,
    required this.chapterId,
    required this.pageCount,
    required this.currentPageIndex,
    required this.pageBuilder,
    required this.onPageCommitted,
    this.onTurnStarted,
    this.onTurnRejected,
  });

  final String chapterId;
  final int pageCount;
  final int currentPageIndex;
  final Widget Function(BuildContext context, int pageIndex) pageBuilder;
  final ValueChanged<int> onPageCommitted;
  final ValueChanged<int>? onTurnStarted;
  final ValueChanged<int>? onTurnRejected;

  @override
  State<ReaderPaperCurlPagedView> createState() =>
      ReaderPaperCurlPagedViewState();
}

class ReaderPaperCurlPagedViewState extends State<ReaderPaperCurlPagedView> {
  final GlobalKey _currentPageKey = GlobalKey();
  final GlobalKey _targetPageKey = GlobalKey();

  PageFlipController? _controller;
  bool _controllerReady = false;
  bool _overlayVisible = false;
  bool _isAnimating = false;
  int _overlayGeneration = 0;
  int _captureGeneration = 0;
  int? _queuedDirection;
  int? _pendingPageIndex;
  List<ui.Image>? _snapshotPages;

  bool get isAnimating => _isAnimating || _queuedDirection != null;

  @override
  void didUpdateWidget(covariant ReaderPaperCurlPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.pageCount != widget.pageCount) {
      _resetOverlay();
    }
  }

  @override
  void dispose() {
    _resetOverlay(setStateIfNeeded: false);
    super.dispose();
  }

  bool turnPage(int direction) {
    if (isAnimating || widget.pageCount <= 0) {
      widget.onTurnRejected?.call(direction);
      return false;
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final currentIndex = widget.currentPageIndex.clamp(0, widget.pageCount - 1);
    final targetIndex = currentIndex + safeDirection;
    if (targetIndex < 0 || targetIndex >= widget.pageCount) {
      widget.onTurnRejected?.call(safeDirection);
      return false;
    }

    _captureGeneration++;
    _pendingPageIndex = targetIndex;
    _queuedDirection = safeDirection;
    _isAnimating = true;
    _disposeSnapshots();
    setState(() {});
    _capturePagesAndStartTurn(_captureGeneration);
    return true;
  }

  Future<void> _capturePagesAndStartTurn(int generation) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _captureGeneration) {
      return;
    }

    final currentImage = await _captureBoundary(_currentPageKey);
    final targetImage = await _captureBoundary(_targetPageKey);
    if (!mounted || generation != _captureGeneration) {
      currentImage?.dispose();
      targetImage?.dispose();
      return;
    }
    if (currentImage == null || targetImage == null) {
      currentImage?.dispose();
      targetImage?.dispose();
      _resetOverlay();
      widget.onTurnRejected?.call(_queuedDirection ?? 1);
      return;
    }

    final direction = _queuedDirection ?? 1;
    final snapshots =
        direction >= 0
            ? <ui.Image>[currentImage, targetImage]
            : <ui.Image>[targetImage, currentImage];

    _controllerReady = false;
    _controller = PageFlipController();
    _overlayGeneration++;
    setState(() {
      _snapshotPages = snapshots;
      _overlayVisible = true;
    });
    widget.onTurnStarted?.call(direction);
    _startQueuedTurnAfterBuild(generation);
  }

  Future<ui.Image?> _captureBoundary(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    if (renderObject.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      return null;
    }
    return renderObject.toImage(pixelRatio: pixelRatio);
  }

  void _startQueuedTurnAfterBuild(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _captureGeneration) {
        return;
      }
      _attachAnimationCompleteListener();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _captureGeneration) {
          return;
        }
        _startQueuedTurn();
      });
    });
  }

  void _attachAnimationCompleteListener() {
    if (_controllerReady) {
      return;
    }
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      controller.addEventListener('animationComplete', (_) {
        _commitPendingPage();
      });
      _controllerReady = true;
    } catch (_) {
      _startQueuedTurnAfterBuild(_captureGeneration);
    }
  }

  void _startQueuedTurn() {
    final direction = _queuedDirection;
    final controller = _controller;
    if (direction == null || controller == null || !_controllerReady) {
      return;
    }
    _queuedDirection = null;
    final turned =
        direction >= 0
            ? controller.nextPage(FlipCorner.bottom)
            : controller.previousPage(FlipCorner.bottom);
    if (!turned) {
      _resetOverlay();
      widget.onTurnRejected?.call(direction);
    }
  }

  void _handleOverlayPageChanged(int leftPageIndex, int rightPageIndex) {
    // turnable_page fires this when the animation starts. The real reader page
    // is committed from animationComplete instead.
  }

  void _commitPendingPage() {
    final pendingIndex = _pendingPageIndex;
    _resetOverlay();
    if (!mounted || pendingIndex == null || widget.pageCount <= 0) {
      return;
    }
    widget.onPageCommitted(pendingIndex.clamp(0, widget.pageCount - 1));
  }

  void _resetOverlay({bool setStateIfNeeded = true}) {
    _removeAnimationCompleteListener();
    _controller = null;
    _controllerReady = false;
    _queuedDirection = null;
    _pendingPageIndex = null;
    _isAnimating = false;
    _captureGeneration++;
    _disposeSnapshots();
    if (mounted && setStateIfNeeded && _overlayVisible) {
      setState(() {
        _overlayVisible = false;
      });
    } else {
      _overlayVisible = false;
    }
  }

  void _disposeSnapshots() {
    final snapshots = _snapshotPages;
    _snapshotPages = null;
    if (snapshots == null) {
      return;
    }
    for (final image in snapshots) {
      image.dispose();
    }
  }

  void _removeAnimationCompleteListener() {
    if (!_controllerReady) {
      return;
    }
    try {
      _controller?.removeEventListener('animationComplete');
    } catch (_) {
      // Controller may already have been detached by turnable_page rebuild.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.pageCount;
    if (pageCount <= 0) {
      return const SizedBox.shrink();
    }
    final safePageIndex =
        widget.currentPageIndex.clamp(0, pageCount - 1).toInt();
    final pendingPageIndex = _pendingPageIndex;
    final snapshots = _snapshotPages;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (pendingPageIndex != null && snapshots == null)
          RepaintBoundary(
            key: _targetPageKey,
            child: widget.pageBuilder(context, pendingPageIndex),
          ),
        RepaintBoundary(
          key: _currentPageKey,
          child: widget.pageBuilder(context, safePageIndex),
        ),
        if (_overlayVisible && _controller != null && snapshots != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _PaperCurlSnapshotOverlay(
                key: ValueKey<String>(
                  'paper_curl_overlay_${widget.chapterId}_$_overlayGeneration',
                ),
                controller: _controller!,
                snapshots: snapshots,
                startPageIndex: (_queuedDirection ?? 1) >= 0 ? 0 : 1,
                onPageChanged: _handleOverlayPageChanged,
              ),
            ),
          ),
      ],
    );
  }
}

class _PaperCurlSnapshotOverlay extends StatelessWidget {
  const _PaperCurlSnapshotOverlay({
    super.key,
    required this.controller,
    required this.snapshots,
    required this.startPageIndex,
    required this.onPageChanged,
  });

  final PageFlipController controller;
  final List<ui.Image> snapshots;
  final int startPageIndex;
  final TurnablePageCallback onPageChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TurnablePage(
          key: ValueKey<String>(
            'paper_curl_snapshot_${snapshots.length}_$startPageIndex',
          ),
          controller: controller,
          pageCount: snapshots.length,
          pageViewMode: PageViewMode.single,
          autoResponseSize: false,
          aspectRatio:
              constraints.maxHeight <= 0
                  ? null
                  : constraints.maxWidth / constraints.maxHeight,
          pagesBoundaryIsEnabled: false,
          paperBoundaryDecoration: PaperBoundaryDecoration.modern,
          settings: FlipSettings(
            startPageIndex: startPageIndex,
            drawShadow: true,
            hideLeftShadow: true,
            onlyVerticalPageFlip: false,
            flippingTime: 1200,
            swipeDistance: 42,
            cornerTriggerAreaSize: 0.22,
            showPageCorners: true,
            usePortrait: true,
            maxShadowOpacity: 0.72,
            sagAmplitude: 0.08,
            bendStrength: 0.68,
          ),
          onPageChanged: onPageChanged,
          builder: (context, pageIndex, _) {
            final safeIndex = pageIndex.clamp(0, snapshots.length - 1);
            return RawImage(
              image: snapshots[safeIndex],
              fit: BoxFit.fill,
              filterQuality: FilterQuality.low,
            );
          },
        );
      },
    );
  }
}
