import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../../core/logging/app_logger.dart';
import 'widgets/overlay/reader_overlay_layer_model.dart';

typedef ReaderPaperCurlPageBuilder =
    Widget Function(BuildContext context, int pageIndex);

enum ReaderPaperCurlResultType {
  started,
  committed,
  rejected,
  timedOut,
  snapshotFailed,
}

enum ReaderPaperCurlFailureReason {
  busyOrEmpty,
  boundary,
  missingContext,
  missingRepaintBoundary,
  emptyBoundarySize,
  captureException,
  controllerRejected,
  animationTimeout,
}

class ReaderPaperCurlResult {
  const ReaderPaperCurlResult({
    required this.type,
    required this.direction,
    required this.fromPageIndex,
    required this.targetPageIndex,
    this.failureReason,
    this.message,
  });

  final ReaderPaperCurlResultType type;
  final int direction;
  final int fromPageIndex;
  final int? targetPageIndex;
  final ReaderPaperCurlFailureReason? failureReason;
  final String? message;

  bool get isFailure =>
      type == ReaderPaperCurlResultType.rejected ||
      type == ReaderPaperCurlResultType.timedOut ||
      type == ReaderPaperCurlResultType.snapshotFailed;
}

class ReaderPaperCurlPagedSurface {
  const ReaderPaperCurlPagedSurface({
    required this.surfaceToken,
    required this.pageCount,
    required this.currentPageIndex,
    required this.pageBuilder,
  });

  /// Opaque paging-surface identity used to reset stale animation snapshots.
  ///
  /// The paper-curl component owns animation and snapshot state only; it should
  /// not know whether this token came from a chapter, a local file, or another
  /// reader surface.
  final Object surfaceToken;
  final int pageCount;
  final int currentPageIndex;
  final ReaderPaperCurlPageBuilder pageBuilder;

  int get safePageIndex {
    if (pageCount <= 0) {
      return 0;
    }
    return currentPageIndex.clamp(0, pageCount - 1).toInt();
  }
}

class ReaderPaperCurlPagedView extends StatefulWidget {
  const ReaderPaperCurlPagedView({
    super.key,
    required this.surface,
    required this.onPageCommitted,
    this.onTurnStarted,
    this.onTurnRejected,
    this.onTurnResult,
  });

  final ReaderPaperCurlPagedSurface surface;
  final ValueChanged<int> onPageCommitted;
  final ValueChanged<int>? onTurnStarted;
  final ValueChanged<int>? onTurnRejected;
  final ValueChanged<ReaderPaperCurlResult>? onTurnResult;

  @override
  State<ReaderPaperCurlPagedView> createState() =>
      ReaderPaperCurlPagedViewState();
}

class ReaderPaperCurlPagedViewState extends State<ReaderPaperCurlPagedView> {
  static const Duration _kAnimationCompleteTimeout = Duration(
    milliseconds: 2400,
  );

  final GlobalKey _currentPageKey = GlobalKey();
  final GlobalKey _targetPageKey = GlobalKey();
  final AppLogger _logger = AppLogger.instance;

  PageFlipController? _controller;
  Timer? _animationTimeoutTimer;
  bool _controllerReady = false;
  bool _overlayVisible = false;
  bool _isAnimating = false;
  bool _waitingForCommittedPagePaint = false;
  int _overlayGeneration = 0;
  int _captureGeneration = 0;
  int _overlayDirection = 1;
  int? _queuedDirection;
  int? _pendingFromPageIndex;
  int? _pendingPageIndex;
  List<ui.Image>? _snapshotPages;

  bool get isAnimating => _isAnimating || _queuedDirection != null;

  @override
  void didUpdateWidget(covariant ReaderPaperCurlPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface.surfaceToken != widget.surface.surfaceToken ||
        oldWidget.surface.pageCount != widget.surface.pageCount) {
      _resetOverlay();
    }
  }

  @override
  void dispose() {
    _resetOverlay(setStateIfNeeded: false);
    super.dispose();
  }

  bool turnPage(int direction) {
    final surface = widget.surface;
    final safeDirection = direction >= 0 ? 1 : -1;
    final currentIndex = surface.safePageIndex;
    if (isAnimating || surface.pageCount <= 0) {
      _logPaperCurlTrace(
        'turn_rejected_busy_or_empty',
        context: <String, Object?>{
          'direction': safeDirection,
          'pageCount': surface.pageCount,
          'isAnimating': isAnimating,
        },
      );
      _emitTurnResult(
        ReaderPaperCurlResultType.rejected,
        direction: safeDirection,
        fromPageIndex: currentIndex,
        targetPageIndex: null,
        failureReason: ReaderPaperCurlFailureReason.busyOrEmpty,
      );
      widget.onTurnRejected?.call(safeDirection);
      return false;
    }

    final targetIndex = currentIndex + safeDirection;
    if (targetIndex < 0 || targetIndex >= surface.pageCount) {
      _logPaperCurlTrace(
        'turn_rejected_boundary',
        context: <String, Object?>{
          'direction': safeDirection,
          'currentIndex': currentIndex,
          'targetIndex': targetIndex,
          'pageCount': surface.pageCount,
        },
      );
      _emitTurnResult(
        ReaderPaperCurlResultType.rejected,
        direction: safeDirection,
        fromPageIndex: currentIndex,
        targetPageIndex: targetIndex,
        failureReason: ReaderPaperCurlFailureReason.boundary,
      );
      widget.onTurnRejected?.call(safeDirection);
      return false;
    }

    _captureGeneration++;
    _pendingFromPageIndex = currentIndex;
    _pendingPageIndex = targetIndex;
    _queuedDirection = safeDirection;
    _isAnimating = true;
    _waitingForCommittedPagePaint = false;
    _disposeSnapshots();
    setState(() {});
    _logPaperCurlTrace(
      'turn_requested',
      context: <String, Object?>{
        'direction': safeDirection,
        'currentIndex': currentIndex,
        'targetIndex': targetIndex,
        'pageCount': surface.pageCount,
        'generation': _captureGeneration,
      },
    );
    _capturePagesAndStartTurn(_captureGeneration);
    return true;
  }

  Future<void> _capturePagesAndStartTurn(int generation) async {
    _logPaperCurlTrace(
      'capture_wait_frame',
      context: <String, Object?>{'generation': generation},
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _captureGeneration) {
      return;
    }

    _logPaperCurlTrace(
      'capture_start',
      context: <String, Object?>{'generation': generation},
    );
    final currentCapture = await _captureBoundary(_currentPageKey, 'current');
    final targetCapture = await _captureBoundary(_targetPageKey, 'target');
    final currentImage = currentCapture.image;
    final targetImage = targetCapture.image;
    if (!mounted || generation != _captureGeneration) {
      currentImage?.dispose();
      targetImage?.dispose();
      return;
    }
    if (currentImage == null || targetImage == null) {
      _logPaperCurlTrace(
        'capture_failed',
        context: <String, Object?>{
          'generation': generation,
          'hasCurrentImage': currentImage != null,
          'hasTargetImage': targetImage != null,
          'currentFailureReason': currentCapture.failureReason?.name,
          'targetFailureReason': targetCapture.failureReason?.name,
          'currentFailureMessage': currentCapture.message,
          'targetFailureMessage': targetCapture.message,
        },
      );
      currentImage?.dispose();
      targetImage?.dispose();
      _emitTurnResult(
        ReaderPaperCurlResultType.snapshotFailed,
        direction: _queuedDirection ?? 1,
        fromPageIndex: _pendingFromPageIndex ?? widget.surface.safePageIndex,
        targetPageIndex: _pendingPageIndex,
        failureReason:
            currentCapture.failureReason ?? targetCapture.failureReason,
        message: currentCapture.message ?? targetCapture.message,
      );
      _resetOverlay();
      widget.onTurnRejected?.call(_queuedDirection ?? 1);
      return;
    }

    final direction = _queuedDirection ?? 1;
    _overlayDirection = direction;
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
    _logPaperCurlTrace(
      'overlay_ready',
      context: <String, Object?>{
        'generation': generation,
        'direction': direction,
        'overlayGeneration': _overlayGeneration,
      },
    );
    _emitTurnResult(
      ReaderPaperCurlResultType.started,
      direction: direction,
      fromPageIndex: _pendingFromPageIndex ?? widget.surface.safePageIndex,
      targetPageIndex: _pendingPageIndex,
    );
    widget.onTurnStarted?.call(direction);
    _startQueuedTurnAfterBuild(generation);
  }

  Future<_PaperCurlSnapshotCapture> _captureBoundary(
    GlobalKey key,
    String label,
  ) async {
    final context = key.currentContext;
    if (context == null) {
      return const _PaperCurlSnapshotCapture.failure(
        ReaderPaperCurlFailureReason.missingContext,
        'Snapshot context is missing.',
      );
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return const _PaperCurlSnapshotCapture.failure(
        ReaderPaperCurlFailureReason.missingRepaintBoundary,
        'Snapshot target is not a repaint boundary.',
      );
    }
    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) {
      return _PaperCurlSnapshotCapture.failure(
        ReaderPaperCurlFailureReason.emptyBoundarySize,
        'Snapshot boundary has empty size: ${size.width}x${size.height}.',
      );
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    // In release mode, debugNeedsPaint is always false, so we unconditionally
    // wait one more frame to ensure rendering is complete before capturing.
    _logPaperCurlTrace(
      'capture_wait_paint',
      context: <String, Object?>{'label': label},
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return const _PaperCurlSnapshotCapture.failure(
        ReaderPaperCurlFailureReason.missingContext,
        'Snapshot capture was cancelled after paint wait.',
      );
    }
    try {
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      return _PaperCurlSnapshotCapture.success(image);
    } catch (error) {
      return _PaperCurlSnapshotCapture.failure(
        ReaderPaperCurlFailureReason.captureException,
        error.toString(),
      );
    }
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
        _logPaperCurlTrace('animation_complete');
        _cancelAnimationTimeout();
        _commitPendingPage();
      });
      _controllerReady = true;
    } catch (_) {
      _logPaperCurlTrace('controller_attach_retry');
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
    _logPaperCurlTrace(
      turned ? 'controller_turn_started' : 'controller_turn_rejected',
      context: <String, Object?>{'direction': direction},
    );
    if (!turned) {
      _emitTurnResult(
        ReaderPaperCurlResultType.rejected,
        direction: direction,
        fromPageIndex: _pendingFromPageIndex ?? widget.surface.safePageIndex,
        targetPageIndex: _pendingPageIndex,
        failureReason: ReaderPaperCurlFailureReason.controllerRejected,
      );
      _resetOverlay();
      widget.onTurnRejected?.call(direction);
      return;
    }
    _startAnimationTimeout(
      generation: _captureGeneration,
      direction: direction,
    );
  }

  void _handleOverlayPageChanged(int leftPageIndex, int rightPageIndex) {
    // turnable_page fires this when the animation starts. The real reader page
    // is committed from animationComplete instead.
  }

  void _startAnimationTimeout({
    required int generation,
    required int direction,
  }) {
    _cancelAnimationTimeout();
    _animationTimeoutTimer = Timer(_kAnimationCompleteTimeout, () {
      if (!mounted ||
          generation != _captureGeneration ||
          !_isAnimating ||
          _pendingPageIndex == null) {
        return;
      }
      _logPaperCurlTrace(
        'animation_complete_timeout',
        context: <String, Object?>{
          'generation': generation,
          'direction': direction,
          'timeoutMs': _kAnimationCompleteTimeout.inMilliseconds,
        },
      );
      _emitTurnResult(
        ReaderPaperCurlResultType.timedOut,
        direction: direction,
        fromPageIndex: _pendingFromPageIndex ?? widget.surface.safePageIndex,
        targetPageIndex: _pendingPageIndex,
        failureReason: ReaderPaperCurlFailureReason.animationTimeout,
      );
      _commitPendingPage(emitCommittedResult: false);
    });
  }

  void _cancelAnimationTimeout() {
    _animationTimeoutTimer?.cancel();
    _animationTimeoutTimer = null;
  }

  void _commitPendingPage({bool emitCommittedResult = true}) {
    if (_waitingForCommittedPagePaint) {
      return;
    }
    final pendingIndex = _pendingPageIndex;
    final pageCount = widget.surface.pageCount;
    if (!mounted || pendingIndex == null || pageCount <= 0) {
      _resetOverlay();
      return;
    }
    final generation = _captureGeneration;
    _waitingForCommittedPagePaint = true;
    _logPaperCurlTrace(
      'commit_pending_page',
      context: <String, Object?>{
        'pendingIndex': pendingIndex,
        'pageCount': pageCount,
        'generation': generation,
      },
    );
    if (emitCommittedResult) {
      _emitTurnResult(
        ReaderPaperCurlResultType.committed,
        direction: _overlayDirection,
        fromPageIndex: _pendingFromPageIndex ?? widget.surface.safePageIndex,
        targetPageIndex: pendingIndex,
      );
    }
    widget.onPageCommitted(pendingIndex.clamp(0, pageCount - 1));
    _resetOverlayAfterCommittedPagePaint(generation);
  }

  Future<void> _resetOverlayAfterCommittedPagePaint(int generation) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _captureGeneration) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _captureGeneration) {
      return;
    }
    _resetOverlay();
  }

  void _resetOverlay({bool setStateIfNeeded = true}) {
    _cancelAnimationTimeout();
    _removeAnimationCompleteListener();
    _controller = null;
    _controllerReady = false;
    _overlayDirection = 1;
    _queuedDirection = null;
    _pendingFromPageIndex = null;
    _pendingPageIndex = null;
    _isAnimating = false;
    _waitingForCommittedPagePaint = false;
    _captureGeneration++;
    final snapshots = _detachSnapshots();
    final wasOverlayVisible = _overlayVisible;
    _logPaperCurlTrace(
      'reset_overlay',
      context: <String, Object?>{
        'setStateIfNeeded': setStateIfNeeded,
        'wasOverlayVisible': wasOverlayVisible,
        'generation': _captureGeneration,
      },
    );
    if (mounted && setStateIfNeeded && wasOverlayVisible) {
      setState(() {
        _overlayVisible = false;
      });
      _disposeSnapshotsAfterOverlayFrame(snapshots);
    } else {
      _overlayVisible = false;
      _disposeSnapshotList(snapshots);
    }
  }

  void _disposeSnapshots() {
    _disposeSnapshotList(_detachSnapshots());
  }

  List<ui.Image>? _detachSnapshots() {
    final snapshots = _snapshotPages;
    _snapshotPages = null;
    return snapshots;
  }

  Future<void> _disposeSnapshotsAfterOverlayFrame(
    List<ui.Image>? snapshots,
  ) async {
    if (snapshots == null) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    _disposeSnapshotList(snapshots);
  }

  void _disposeSnapshotList(List<ui.Image>? snapshots) {
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

  void _emitTurnResult(
    ReaderPaperCurlResultType type, {
    required int direction,
    required int fromPageIndex,
    required int? targetPageIndex,
    ReaderPaperCurlFailureReason? failureReason,
    String? message,
  }) {
    final result = ReaderPaperCurlResult(
      type: type,
      direction: direction,
      fromPageIndex: fromPageIndex,
      targetPageIndex: targetPageIndex,
      failureReason: failureReason,
      message: message,
    );
    _logPaperCurlTrace(
      'result_${type.name}',
      context: <String, Object?>{
        'direction': direction,
        'fromPageIndex': fromPageIndex,
        'targetPageIndex': targetPageIndex,
        'failureReason': failureReason?.name,
        'message': message,
      },
    );
    widget.onTurnResult?.call(result);
  }

  void _logPaperCurlTrace(
    String step, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final traceContext = <String, Object?>{
      'chain': 'reader_paper_curl',
      'step': step,
      'surfaceToken': widget.surface.surfaceToken.toString(),
      'currentPageIndex': widget.surface.currentPageIndex,
      'pageCount': widget.surface.pageCount,
      ...context,
    };
    developer.Timeline.instantSync(
      'reader.paper_curl',
      arguments: traceContext,
    );
    _logger.debug('Reader paper curl trace', context: traceContext);
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.surface;
    final pageCount = surface.pageCount;
    if (pageCount <= 0) {
      return const SizedBox.shrink();
    }
    final safePageIndex = surface.safePageIndex;
    final pendingPageIndex = _pendingPageIndex;
    final snapshots = _snapshotPages;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hiddenTargetOffset = Offset(
          (constraints.maxWidth.isFinite ? constraints.maxWidth : 0) + 64,
          0,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            if (pendingPageIndex != null && snapshots == null)
              ReaderFullScreenHitTestLayer(
                strategy: ReaderFullScreenHitTestStrategy.passThrough,
                child: Transform.translate(
                  offset: hiddenTargetOffset,
                  child: RepaintBoundary(
                    key: _targetPageKey,
                    child: surface.pageBuilder(context, pendingPageIndex),
                  ),
                ),
              ),
            RepaintBoundary(
              key: _currentPageKey,
              child: surface.pageBuilder(context, safePageIndex),
            ),
            if (_overlayVisible && _controller != null && snapshots != null)
              ReaderFullScreenHitTestLayer(
                strategy: ReaderFullScreenHitTestStrategy.passThrough,
                child: _PaperCurlSnapshotOverlay(
                  key: ValueKey<Object>(
                    Object.hash(surface.surfaceToken, _overlayGeneration),
                  ),
                  controller: _controller!,
                  snapshots: snapshots,
                  startPageIndex: _overlayDirection >= 0 ? 0 : 1,
                  onPageChanged: _handleOverlayPageChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaperCurlSnapshotCapture {
  const _PaperCurlSnapshotCapture.success(this.image)
    : failureReason = null,
      message = null;

  const _PaperCurlSnapshotCapture.failure(this.failureReason, this.message)
    : image = null;

  final ui.Image? image;
  final ReaderPaperCurlFailureReason? failureReason;
  final String? message;
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
            final safeIndex = pageIndex.clamp(0, snapshots.length - 1).toInt();
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
