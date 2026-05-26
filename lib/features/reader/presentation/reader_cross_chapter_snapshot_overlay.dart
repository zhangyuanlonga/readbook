import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../../domain/entities/reader_settings.dart';
import 'paged_animation/curl_paged_animation_renderer.dart';
import 'paged_animation/paged_animation_renderer_registry.dart';

class ReaderCrossChapterSnapshotOverlay extends StatelessWidget {
  const ReaderCrossChapterSnapshotOverlay({
    super.key,
    required this.fromImage,
    required this.toImage,
    required this.style,
    required this.direction,
    required this.animation,
    required this.generation,
    required this.curlColors,
    required this.onPaperCurlCompleted,
  });

  final ui.Image fromImage;
  final ui.Image? toImage;
  final ReaderPageAnimationStyle style;
  final int direction;
  final Animation<double> animation;
  final int generation;
  final CurlRendererColors curlColors;
  final VoidCallback onPaperCurlCompleted;

  @override
  Widget build(BuildContext context) {
    final targetImage = toImage;
    if (targetImage == null) {
      return _SnapshotImage(image: fromImage);
    }

    if (style == ReaderPageAnimationStyle.paperCurl) {
      return _PaperCurlCrossChapterSnapshotFlip(
        key: ValueKey<int>(generation),
        fromImage: fromImage,
        toImage: targetImage,
        direction: direction,
        onCompleted: onPaperCurlCompleted,
      );
    }

    final fromPage = _SnapshotImage(image: fromImage);
    final toPage = _SnapshotImage(image: targetImage);

    if (style == ReaderPageAnimationStyle.curl) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final progress = animation.value.clamp(0.0, 1.0).toDouble();
          return const CurlPagedAnimationRenderer().build(
            currentPage: fromPage,
            targetPage: toPage,
            progress: progress,
            direction: direction,
            colors: curlColors,
          );
        },
      );
    }

    final renderer = const PagedAnimationRendererRegistry().resolve(style);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value.clamp(0.0, 1.0).toDouble();
        return renderer.build(
          fromPage: fromPage,
          toPage: toPage,
          progress: progress,
          direction: direction.toDouble(),
        );
      },
    );
  }
}

class _SnapshotImage extends StatelessWidget {
  const _SnapshotImage({required this.image});

  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return RawImage(
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
    );
  }
}

class _PaperCurlCrossChapterSnapshotFlip extends StatefulWidget {
  const _PaperCurlCrossChapterSnapshotFlip({
    super.key,
    required this.fromImage,
    required this.toImage,
    required this.direction,
    required this.onCompleted,
  });

  final ui.Image fromImage;
  final ui.Image toImage;
  final int direction;
  final VoidCallback onCompleted;

  @override
  State<_PaperCurlCrossChapterSnapshotFlip> createState() =>
      _PaperCurlCrossChapterSnapshotFlipState();
}

class _PaperCurlCrossChapterSnapshotFlipState
    extends State<_PaperCurlCrossChapterSnapshotFlip> {
  late PageFlipController _controller;
  bool _listenerAttached = false;
  bool _turnStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = PageFlipController();
    _startAfterBuild();
  }

  @override
  void didUpdateWidget(covariant _PaperCurlCrossChapterSnapshotFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromImage != widget.fromImage ||
        oldWidget.toImage != widget.toImage ||
        oldWidget.direction != widget.direction) {
      _removeListener();
      _controller = PageFlipController();
      _listenerAttached = false;
      _turnStarted = false;
      _startAfterBuild();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _startAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _turnStarted) {
        return;
      }
      _attachListener();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _turnStarted || !_listenerAttached) {
          return;
        }
        _turnStarted = true;
        final turned =
            widget.direction >= 0
                ? _controller.nextPage(FlipCorner.bottom)
                : _controller.previousPage(FlipCorner.bottom);
        if (!turned) {
          widget.onCompleted();
        }
      });
    });
  }

  void _attachListener() {
    if (_listenerAttached) {
      return;
    }
    try {
      _controller.addEventListener('animationComplete', (_) {
        widget.onCompleted();
      });
      _listenerAttached = true;
    } catch (_) {
      _startAfterBuild();
    }
  }

  void _removeListener() {
    if (!_listenerAttached) {
      return;
    }
    try {
      _controller.removeEventListener('animationComplete');
    } catch (_) {
      // turnable_page may detach the controller during rebuild/dispose.
    }
    _listenerAttached = false;
  }

  @override
  Widget build(BuildContext context) {
    final forward = widget.direction >= 0;
    final snapshots =
        forward
            ? <ui.Image>[widget.fromImage, widget.toImage]
            : <ui.Image>[widget.toImage, widget.fromImage];

    return LayoutBuilder(
      builder: (context, constraints) {
        return TurnablePage(
          key: ValueKey<String>(
            'cross_chapter_paper_curl_${identityHashCode(widget.fromImage)}_${identityHashCode(widget.toImage)}_${widget.direction}',
          ),
          controller: _controller,
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
            startPageIndex: forward ? 0 : 1,
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
          onPageChanged: (_, _) {},
          builder: (context, pageIndex, _) {
            final safeIndex = pageIndex.clamp(0, snapshots.length - 1).toInt();
            return _SnapshotImage(image: snapshots[safeIndex]);
          },
        );
      },
    );
  }
}
