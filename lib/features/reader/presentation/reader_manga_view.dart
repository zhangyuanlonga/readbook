import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_session_state.dart';
import '../application/reader_surface_metrics.dart';
import 'reader_shell.dart';

typedef ReaderMangaImageBuilder =
    Widget Function(BuildContext context, ReaderMangaImageItem item);

typedef ReaderMangaImageFrameBuilder =
    Widget Function(
      BuildContext context,
      ReaderMangaImageItem item,
      Widget child,
    );

typedef ReaderMangaContinuousViewportBuilder =
    Widget Function(
      BuildContext context,
      ReaderMangaContinuousViewport viewport,
      Widget child,
    );

typedef ReaderMangaPagedViewportBuilder =
    Widget Function(
      BuildContext context,
      ReaderMangaPagedViewport viewport,
      Widget child,
    );

class ReaderMangaViewModel {
  const ReaderMangaViewModel({
    required this.contentSession,
    required this.settings,
    required this.surfaceMetrics,
    required this.palette,
    required this.imageUrls,
    this.readMode,
    this.currentIndex = 0,
    this.emptyMessage,
    this.continuousPadding,
    this.pagedPagePadding,
    this.continuousCacheExtent,
    this.debugLabel,
  });

  final ReaderContentSession contentSession;
  final ReaderSettings settings;
  final ReaderSurfaceMetrics surfaceMetrics;
  final ReaderPresentationPalette palette;
  final List<String> imageUrls;
  final ReaderMangaReadMode? readMode;
  final int currentIndex;
  final String? emptyMessage;
  final EdgeInsets? continuousPadding;
  final EdgeInsets? pagedPagePadding;
  final double? continuousCacheExtent;
  final String? debugLabel;

  ReaderMangaReadMode get effectiveReadMode =>
      readMode ?? settings.mangaReadMode;

  bool get isPagedMode =>
      effectiveReadMode == ReaderMangaReadMode.paged ||
      effectiveReadMode == ReaderMangaReadMode.horizontal;

  Axis get pagedScrollDirection =>
      effectiveReadMode == ReaderMangaReadMode.horizontal
          ? Axis.horizontal
          : Axis.vertical;

  EdgeInsets get resolvedContinuousPadding {
    final source = surfaceMetrics.scrollBodyPadding;
    return continuousPadding ??
        EdgeInsets.fromLTRB(
          math.max(settings.mangaImagePadding, source.left),
          math.max(settings.mangaImagePadding, source.top),
          math.max(settings.mangaImagePadding, source.right),
          math.max(settings.mangaImagePadding, source.bottom),
        );
  }

  EdgeInsets get resolvedPagedPagePadding {
    final source = surfaceMetrics.effectivePagePadding;
    return pagedPagePadding ??
        EdgeInsets.fromLTRB(
          math.max(settings.mangaImagePadding, source.left),
          math.max(settings.mangaImagePadding, source.top),
          math.max(settings.mangaImagePadding, source.right),
          math.max(settings.mangaImagePadding, source.bottom),
        );
  }

  double get resolvedContinuousCacheExtent =>
      continuousCacheExtent ??
      switch (settings.mangaLoadStrategy) {
        ReaderMangaLoadStrategy.balanced => 1800,
        ReaderMangaLoadStrategy.smooth => 3200,
        ReaderMangaLoadStrategy.saveData => 900,
      };
}

class ReaderMangaImageItem {
  const ReaderMangaImageItem({
    required this.contentSession,
    required this.settings,
    required this.surfaceMetrics,
    required this.palette,
    required this.readMode,
    required this.imageUrl,
    required this.index,
    required this.imageCount,
    required this.padding,
    required this.isCurrentItem,
  });

  final ReaderContentSession contentSession;
  final ReaderSettings settings;
  final ReaderSurfaceMetrics surfaceMetrics;
  final ReaderPresentationPalette palette;
  final ReaderMangaReadMode readMode;
  final String imageUrl;
  final int index;
  final int imageCount;
  final EdgeInsets padding;
  final bool isCurrentItem;
}

class ReaderMangaContinuousViewport {
  const ReaderMangaContinuousViewport({
    required this.model,
    required this.controller,
    required this.padding,
    required this.cacheExtent,
    required this.physics,
    required this.itemCount,
    required this.listKey,
  });

  final ReaderMangaViewModel model;
  final ScrollController? controller;
  final EdgeInsets padding;
  final double cacheExtent;
  final ScrollPhysics? physics;
  final int itemCount;
  final Key listKey;
}

class ReaderMangaPagedViewport {
  const ReaderMangaPagedViewport({
    required this.model,
    required this.controller,
    required this.padding,
    required this.physics,
    required this.itemCount,
    required this.currentIndex,
    required this.scrollDirection,
    required this.pageViewKey,
  });

  final ReaderMangaViewModel model;
  final PageController controller;
  final EdgeInsets padding;
  final ScrollPhysics physics;
  final int itemCount;
  final int currentIndex;
  final Axis scrollDirection;
  final Key pageViewKey;
}

class ReaderMangaPageChangedDetails {
  const ReaderMangaPageChangedDetails({
    required this.index,
    required this.itemCount,
    required this.readMode,
  });

  final int index;
  final int itemCount;
  final ReaderMangaReadMode readMode;
}

class ReaderMangaView extends StatefulWidget {
  const ReaderMangaView({
    super.key,
    required this.model,
    this.scrollController,
    this.pageController,
    this.onVisiblePositionChanged,
    this.onPageChanged,
    this.onPageChangedDetails,
    this.imageBuilder,
    this.imageFrameBuilder,
    this.continuousViewportBuilder,
    this.pagedViewportBuilder,
    this.continuousPhysics,
    this.pagedPhysics,
    this.content,
  });

  final ReaderMangaViewModel model;
  final ScrollController? scrollController;
  final PageController? pageController;
  final ValueChanged<ReaderVisiblePosition>? onVisiblePositionChanged;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderMangaPageChangedDetails>? onPageChangedDetails;
  final ReaderMangaImageBuilder? imageBuilder;
  final ReaderMangaImageFrameBuilder? imageFrameBuilder;
  final ReaderMangaContinuousViewportBuilder? continuousViewportBuilder;
  final ReaderMangaPagedViewportBuilder? pagedViewportBuilder;
  final ScrollPhysics? continuousPhysics;
  final ScrollPhysics? pagedPhysics;
  final Widget? content;

  @override
  State<ReaderMangaView> createState() => _ReaderMangaViewState();
}

class _ReaderMangaViewState extends State<ReaderMangaView> {
  late PageController _ownedPageController;
  final Map<int, TransformationController> _transformControllers =
      <int, TransformationController>{};
  final Map<int, TapDownDetails> _doubleTapDetails = <int, TapDownDetails>{};
  final Set<int> _zoomedPageIndexes = <int>{};

  PageController get _pageController =>
      widget.pageController ?? _ownedPageController;

  @override
  void initState() {
    super.initState();
    _ownedPageController = PageController(
      initialPage: _safePageIndex(widget.model.currentIndex),
    );
    _scheduleInitialPositionCallback();
  }

  @override
  void didUpdateWidget(covariant ReaderMangaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReset = _shouldResetOwnedPageController(
      oldWidget.model,
      widget.model,
    );
    if (widget.pageController == null && shouldReset) {
      final previous = _ownedPageController;
      _ownedPageController = PageController(
        initialPage: _safePageIndex(widget.model.currentIndex),
      );
      previous.dispose();
    }
    if (shouldReset) {
      _resetZoomState();
    }
    _scheduleInitialPositionCallback();
  }

  @override
  void dispose() {
    _resetZoomState();
    _ownedPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content != null) {
      return widget.content!;
    }
    if (widget.model.imageUrls.isEmpty) {
      return Center(
        child: Text(
          widget.model.emptyMessage ?? '当前章节暂无漫画内容',
          style: TextStyle(color: widget.model.palette.secondaryTextColor),
        ),
      );
    }

    return switch (widget.model.effectiveReadMode) {
      ReaderMangaReadMode.continuous => _buildContinuousViewport(context),
      ReaderMangaReadMode.paged ||
      ReaderMangaReadMode.horizontal => _buildPagedViewport(context),
    };
  }

  Widget _buildContinuousViewport(BuildContext context) {
    final viewport = ReaderMangaContinuousViewport(
      model: widget.model,
      controller: widget.scrollController,
      padding: widget.model.resolvedContinuousPadding,
      cacheExtent: widget.model.resolvedContinuousCacheExtent,
      physics: widget.continuousPhysics,
      itemCount: widget.model.imageUrls.length,
      listKey: ValueKey(
        'manga_continuous_${widget.model.contentSession.chapterId}',
      ),
    );

    final child = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        widget.onVisiblePositionChanged?.call(
          ReaderVisiblePosition(
            scrollOffset: notification.metrics.pixels,
            maxScrollExtent: notification.metrics.maxScrollExtent,
          ),
        );
        return false;
      },
      child: ListView.separated(
        key: viewport.listKey,
        controller: viewport.controller,
        physics: viewport.physics,
        cacheExtent: viewport.cacheExtent,
        padding: viewport.padding,
        itemCount: viewport.itemCount,
        separatorBuilder:
            (_, __) =>
                SizedBox(height: widget.model.settings.mangaImageSpacing),
        itemBuilder:
            (context, index) => _buildImageFrame(
              context,
              index: index,
              padding: EdgeInsets.zero,
              isCurrentItem: false,
            ),
      ),
    );

    return widget.continuousViewportBuilder?.call(context, viewport, child) ??
        child;
  }

  Widget _buildPagedViewport(BuildContext context) {
    final physics =
        widget.pagedPhysics ??
        (_zoomedPageIndexes.contains(_safePageIndex(widget.model.currentIndex))
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics());
    final viewport = ReaderMangaPagedViewport(
      model: widget.model,
      controller: _pageController,
      padding: widget.model.resolvedPagedPagePadding,
      physics: physics,
      itemCount: widget.model.imageUrls.length,
      currentIndex: _safePageIndex(widget.model.currentIndex),
      scrollDirection: widget.model.pagedScrollDirection,
      pageViewKey: ValueKey(
        'manga_paged_${widget.model.contentSession.chapterId}_${widget.model.effectiveReadMode.name}',
      ),
    );

    final child = PageView.builder(
      key: viewport.pageViewKey,
      controller: viewport.controller,
      scrollDirection: viewport.scrollDirection,
      physics: viewport.physics,
      itemCount: viewport.itemCount,
      onPageChanged: _handlePageChanged,
      itemBuilder:
          (context, index) => _buildImageFrame(
            context,
            index: index,
            padding: viewport.padding,
            isCurrentItem: index == viewport.currentIndex,
          ),
    );

    return widget.pagedViewportBuilder?.call(context, viewport, child) ?? child;
  }

  Widget _buildImageFrame(
    BuildContext context, {
    required int index,
    required EdgeInsets padding,
    required bool isCurrentItem,
  }) {
    final item = ReaderMangaImageItem(
      contentSession: widget.model.contentSession,
      settings: widget.model.settings,
      surfaceMetrics: widget.model.surfaceMetrics,
      palette: widget.model.palette,
      readMode: widget.model.effectiveReadMode,
      imageUrl: widget.model.imageUrls[index],
      index: index,
      imageCount: widget.model.imageUrls.length,
      padding: padding,
      isCurrentItem: isCurrentItem,
    );
    final image =
        widget.imageBuilder?.call(context, item) ??
        _DefaultReaderMangaImage(item: item);
    final framed =
        widget.imageFrameBuilder?.call(context, item, image) ??
        _buildDefaultImageFrame(item: item, child: image);
    if (padding == EdgeInsets.zero) {
      return framed;
    }
    return Padding(padding: padding, child: framed);
  }

  Widget _buildDefaultImageFrame({
    required ReaderMangaImageItem item,
    required Widget child,
  }) {
    final transformController = _ensureTransformController(item.index);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: item.palette.chromeColor,
        child: GestureDetector(
          onDoubleTapDown: (details) {
            _doubleTapDetails[item.index] = details;
          },
          onDoubleTap: () => _toggleZoom(item.index),
          child: InteractiveViewer(
            transformationController: transformController,
            minScale: 1,
            maxScale: 4,
            panEnabled: true,
            onInteractionEnd: (_) => _syncZoomState(item.index),
            child: child,
          ),
        ),
      ),
    );
  }

  void _handlePageChanged(int index) {
    widget.onPageChanged?.call(index);
    widget.onPageChangedDetails?.call(
      ReaderMangaPageChangedDetails(
        index: index,
        itemCount: widget.model.imageUrls.length,
        readMode: widget.model.effectiveReadMode,
      ),
    );
    widget.onVisiblePositionChanged?.call(
      ReaderVisiblePosition(
        pageIndex: index,
        pageCount: widget.model.imageUrls.length,
      ),
    );
  }

  int _safePageIndex(int candidate) {
    final pageCount = widget.model.imageUrls.length;
    if (pageCount <= 0) {
      return 0;
    }
    return candidate.clamp(0, pageCount - 1);
  }

  bool _shouldResetOwnedPageController(
    ReaderMangaViewModel previous,
    ReaderMangaViewModel next,
  ) {
    return previous.contentSession.chapterId != next.contentSession.chapterId ||
        previous.effectiveReadMode != next.effectiveReadMode;
  }

  void _resetZoomState() {
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    _transformControllers.clear();
    _doubleTapDetails.clear();
    _zoomedPageIndexes.clear();
  }

  TransformationController _ensureTransformController(int index) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _syncZoomState(int index) {
    final controller = _transformControllers[index];
    if (controller == null) {
      return;
    }
    final zoomed = controller.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed == _zoomedPageIndexes.contains(index)) {
      return;
    }
    setState(() {
      if (zoomed) {
        _zoomedPageIndexes.add(index);
      } else {
        _zoomedPageIndexes.remove(index);
      }
    });
  }

  void _toggleZoom(int index) {
    final controller = _ensureTransformController(index);
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.02) {
      controller.value = Matrix4.identity();
      setState(() {
        _zoomedPageIndexes.remove(index);
      });
      return;
    }

    final tapDetails = _doubleTapDetails[index];
    final tapPoint = tapDetails?.localPosition ?? const Offset(80, 120);
    const zoomScale = 2.1;
    controller.value =
        Matrix4.identity()
          ..translateByDouble(
            -tapPoint.dx * (zoomScale - 1),
            -tapPoint.dy * (zoomScale - 1),
            0,
            1,
          )
          ..scaleByDouble(zoomScale, zoomScale, 1, 1);
    setState(() {
      _zoomedPageIndexes.add(index);
    });
  }

  void _scheduleInitialPositionCallback() {
    if (!widget.model.isPagedMode || widget.onVisiblePositionChanged == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onVisiblePositionChanged?.call(
        ReaderVisiblePosition(
          pageIndex: _safePageIndex(widget.model.currentIndex),
          pageCount: widget.model.imageUrls.length,
        ),
      );
    });
  }
}

class _DefaultReaderMangaImage extends StatelessWidget {
  const _DefaultReaderMangaImage({required this.item});

  final ReaderMangaImageItem item;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      item.imageUrl,
      fit: BoxFit.fitWidth,
      filterQuality: _resolveFilterQuality(item.settings.mangaLoadStrategy),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return AspectRatio(
          aspectRatio: 3 / 4,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: item.palette.secondaryTextColor,
            ),
          ),
        );
      },
      errorBuilder:
          (_, __, ___) => AspectRatio(
            aspectRatio: 3 / 4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '图片加载失败',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: item.palette.secondaryTextColor),
                ),
              ),
            ),
          ),
    );
  }

  FilterQuality _resolveFilterQuality(ReaderMangaLoadStrategy strategy) {
    return switch (strategy) {
      ReaderMangaLoadStrategy.balanced => FilterQuality.medium,
      ReaderMangaLoadStrategy.smooth => FilterQuality.high,
      ReaderMangaLoadStrategy.saveData => FilterQuality.low,
    };
  }
}
