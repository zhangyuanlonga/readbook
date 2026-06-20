import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/reader_layout_render_model.dart';
import '../application/reader_selection_runtime.dart';
import '../domain/entities/reader_layout_models.dart';

typedef ReaderLayoutImagePlaceholderBuilder =
    Widget Function(BuildContext context, ReaderLayoutRenderFragment fragment);

class ReaderLayoutTextAnnotationRange {
  const ReaderLayoutTextAnnotationRange({
    required this.startOffset,
    required this.endOffset,
    this.hasHighlight = true,
    this.color,
  }) : assert(endOffset >= startOffset);

  final int startOffset;
  final int endOffset;
  final bool hasHighlight;
  final Color? color;
}

class ReaderLayoutPagedView extends StatefulWidget {
  const ReaderLayoutPagedView({
    super.key,
    required this.pages,
    this.pageIndex = 0,
    this.pageController,
    this.onPageChanged,
    this.physics,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor,
    this.diagnosticsOverlay,
    this.selectionRuntime = const ReaderSelectionRuntime(),
    this.onSelectionChanged,
  });

  final List<ReaderLayoutPage> pages;
  final int pageIndex;
  final PageController? pageController;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color? highlightColor;
  final Widget? diagnosticsOverlay;
  final ReaderSelectionRuntime selectionRuntime;
  final ValueChanged<ReaderLayoutSelectionSnapshot>? onSelectionChanged;

  @override
  State<ReaderLayoutPagedView> createState() => _ReaderLayoutPagedViewState();
}

class _ReaderLayoutPagedViewState extends State<ReaderLayoutPagedView> {
  PageController? _ownedPageController;
  int? _pendingJumpPage;

  @override
  void initState() {
    super.initState();
    _syncOwnedController();
  }

  @override
  void didUpdateWidget(covariant ReaderLayoutPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOwnedController();
  }

  @override
  void dispose() {
    _ownedPageController?.dispose();
    super.dispose();
  }

  void _syncOwnedController() {
    if (widget.pageController != null || widget.pages.isEmpty) {
      _ownedPageController?.dispose();
      _ownedPageController = null;
      return;
    }

    final safePage = _safePageIndex(widget.pageIndex);
    final controller = _ownedPageController;
    if (controller == null) {
      _ownedPageController = PageController(initialPage: safePage);
      return;
    }
    if (!controller.hasClients) {
      return;
    }
    final currentPage = _readSingleAttachedPage(controller);
    if (currentPage != safePage) {
      _scheduleJumpToPage(safePage);
    }
  }

  int _safePageIndex(int pageIndex) {
    if (widget.pages.isEmpty) {
      return 0;
    }
    return pageIndex.clamp(0, widget.pages.length - 1);
  }

  void _scheduleJumpToPage(int pageIndex) {
    if (_pendingJumpPage == pageIndex) {
      return;
    }
    _pendingJumpPage = pageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = _pendingJumpPage;
      _pendingJumpPage = null;
      final controller = _ownedPageController;
      if (target == null || controller == null || !controller.hasClients) {
        return;
      }
      final safeTarget = _safePageIndex(target);
      if (_readSingleAttachedPage(controller) != safeTarget) {
        controller.jumpToPage(safeTarget);
      }
    });
  }

  int _readSingleAttachedPage(PageController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return controller.initialPage;
    }
    return controller.page?.round() ?? controller.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final controller = widget.pageController ?? _ownedPageController;
    final pageView = PageView.builder(
      controller: controller,
      physics: widget.physics,
      itemCount: pages.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        final renderPage =
            const ReaderLayoutRenderModelBuilder().buildPages(
              <ReaderLayoutPage>[pages[index]],
            ).single;
        Widget pageChild = Align(
          alignment: Alignment.topLeft,
          child: ReaderLayoutPageView(
            page: renderPage,
            textStyle: widget.textStyle,
            titleStyle: widget.titleStyle,
            imagePlaceholderBuilder: widget.imagePlaceholderBuilder,
            annotationRanges: widget.annotationRanges,
            highlightColor: widget.highlightColor,
          ),
        );
        if (widget.onSelectionChanged != null) {
          pageChild = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: (details) {
              final selection = widget.selectionRuntime.selectWordAt(
                layoutPages: pages,
                pageIndex: pages[index].pageIndex,
                dx: details.localPosition.dx,
                dy: details.localPosition.dy,
              );
              if (selection != null) {
                widget.onSelectionChanged?.call(selection);
              }
            },
            child: pageChild,
          );
        }
        return RepaintBoundary(
          key: ValueKey<String>('reader_layout_page_$index'),
          child: pageChild,
        );
      },
    );
    if (widget.diagnosticsOverlay == null) {
      return pageView;
    }
    return Stack(
      children: [
        pageView,
        Positioned(
          left: 8,
          top: 8,
          child: IgnorePointer(child: widget.diagnosticsOverlay),
        ),
      ],
    );
  }
}

class ReaderLayoutPageView extends StatelessWidget {
  const ReaderLayoutPageView({
    super.key,
    required this.page,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor,
  });

  final ReaderLayoutRenderPage page;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final resolvedTitleStyle =
        titleStyle ?? defaultTextStyle.copyWith(fontWeight: FontWeight.w600);
    return SizedBox(
      width: page.contentWidth,
      height: page.contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: page.fragments
            .map(
              (fragment) => Positioned(
                left: fragment.rect.left,
                top: fragment.rect.top,
                width: fragment.rect.width,
                height: fragment.rect.height,
                child: _ReaderLayoutFragmentView(
                  fragment: fragment,
                  textStyle:
                      fragment.styleKey == 'title'
                          ? resolvedTitleStyle
                          : defaultTextStyle,
                  imagePlaceholderBuilder: imagePlaceholderBuilder,
                  annotationRanges: annotationRanges,
                  highlightColor: highlightColor,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ReaderLayoutFragmentView extends StatelessWidget {
  const _ReaderLayoutFragmentView({
    required this.fragment,
    required this.textStyle,
    this.imagePlaceholderBuilder,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor,
  });

  final ReaderLayoutRenderFragment fragment;
  final TextStyle textStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return switch (fragment.kind) {
      ReaderLayoutRenderFragmentKind.text => ReaderLayoutTextPainter(
        text: fragment.text,
        textStyle: textStyle,
        annotationRanges: _localRangesFor(fragment),
        highlightColor:
            highlightColor ??
            textStyle.color ??
            Theme.of(context).colorScheme.primary,
      ),
      ReaderLayoutRenderFragmentKind.image =>
        imagePlaceholderBuilder?.call(context, fragment) ??
            const _ReaderLayoutDefaultImagePlaceholder(),
      ReaderLayoutRenderFragmentKind.placeholder => const SizedBox.expand(),
    };
  }

  List<ReaderLayoutTextAnnotationRange> _localRangesFor(
    ReaderLayoutRenderFragment fragment,
  ) {
    if (annotationRanges.isEmpty || fragment.text.isEmpty) {
      return const <ReaderLayoutTextAnnotationRange>[];
    }
    final ranges = <ReaderLayoutTextAnnotationRange>[];
    for (final range in annotationRanges) {
      if (!range.hasHighlight) {
        continue;
      }
      final overlapStart = math.max(range.startOffset, fragment.startOffset);
      final overlapEnd = math.min(range.endOffset, fragment.endOffset);
      if (overlapEnd <= overlapStart) {
        continue;
      }
      ranges.add(
        ReaderLayoutTextAnnotationRange(
          startOffset: overlapStart - fragment.startOffset,
          endOffset: overlapEnd - fragment.startOffset,
          color: range.color,
        ),
      );
    }
    return List<ReaderLayoutTextAnnotationRange>.unmodifiable(ranges);
  }
}

class ReaderLayoutTextPainter extends StatelessWidget {
  const ReaderLayoutTextPainter({
    super.key,
    required this.text,
    required this.textStyle,
    this.annotationRanges = const <ReaderLayoutTextAnnotationRange>[],
    this.highlightColor = const Color(0x663F7BFF),
  });

  final String text;
  final TextStyle textStyle;
  final List<ReaderLayoutTextAnnotationRange> annotationRanges;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _ReaderLayoutTextHighlightPainter(
          text: text,
          textStyle: textStyle,
          textDirection: Directionality.of(context),
          ranges: annotationRanges,
          fallbackColor: highlightColor,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: textStyle,
          ),
        ),
      ),
    );
  }
}

class _ReaderLayoutTextHighlightPainter extends CustomPainter {
  const _ReaderLayoutTextHighlightPainter({
    required this.text,
    required this.textStyle,
    required this.textDirection,
    required this.ranges,
    required this.fallbackColor,
  });

  final String text;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final List<ReaderLayoutTextAnnotationRange> ranges;
  final Color fallbackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || ranges.isEmpty || size.isEmpty) {
      return;
    }
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: size.width);
    for (final range in ranges) {
      final start = range.startOffset.clamp(0, text.length).toInt();
      final end = range.endOffset.clamp(start, text.length).toInt();
      if (end <= start) {
        continue;
      }
      final paint =
          Paint()
            ..color = (range.color ?? fallbackColor).withValues(alpha: 0.22);
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      for (final box in boxes) {
        final rect = box.toRect().inflate(1.5).intersect(Offset.zero & size);
        if (rect.isEmpty) {
          continue;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReaderLayoutTextHighlightPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.ranges != ranges ||
        oldDelegate.fallbackColor != fallbackColor;
  }
}

class _ReaderLayoutDefaultImagePlaceholder extends StatelessWidget {
  const _ReaderLayoutDefaultImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
