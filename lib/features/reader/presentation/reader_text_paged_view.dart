import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_image_decode_budget.dart';
import '../application/reader_pagination_models.dart';
import '../application/reader_pagination_spec.dart';
import '../application/reader_session_state.dart';
import '../application/reader_surface_metrics.dart';
import 'reader_shell.dart';
import 'reader_text_block_presentation.dart';

typedef ReaderPagedPageBuilder =
    Widget Function(BuildContext context, int pageIndex);

typedef ReaderPagedPageFrameBuilder =
    Widget Function(
      BuildContext context,
      ReaderTextPagedViewModel model,
      int pageIndex,
      Widget pageChild,
    );

typedef ReaderResolvedPagedPageBuilder =
    Widget Function(
      BuildContext context,
      ReaderPagedResolvedPage page,
      Widget defaultPage,
    );

typedef ReaderResolvedPagedSliceBuilder =
    Widget Function(
      BuildContext context,
      ReaderPagedResolvedSlice slice,
      Widget defaultSlice,
    );

typedef ReaderPagedSliceTextSpanBuilder =
    TextSpan Function(BuildContext context, ReaderPagedResolvedSlice slice);

typedef ReaderPagedEmptyBuilder =
    Widget Function(BuildContext context, ReaderTextPagedViewModel model);

typedef ReaderPagedPagePaddingResolver =
    EdgeInsets Function(ReaderTextPagedViewModel model);

class ReaderTextPagedViewModel {
  const ReaderTextPagedViewModel({
    required this.contentSession,
    required this.settings,
    required this.surfaceMetrics,
    required this.paginationSpec,
    required this.palette,
    required this.pageCount,
    required this.currentPageIndex,
    this.document,
    this.paragraphs = const <String>[],
    this.pagedPages = const <List<ReaderPagedSlice>>[],
    this.pagedBlockPages = const <List<ReaderPagedBlock>>[],
    this.textItemsByParagraph = const <int, ReaderRenderTextItem>{},
    this.imageDecodeBudget,
    this.pagePadding,
    this.emptyMessage,
    this.allowSelection = false,
    this.textAlign,
    this.enableLightweightRenderCache = false,
  });

  final ReaderContentSession contentSession;
  final ReaderSettings settings;
  final ReaderSurfaceMetrics surfaceMetrics;
  final ReaderPaginationSpec paginationSpec;
  final ReaderPresentationPalette palette;
  final int pageCount;
  final int currentPageIndex;
  final ReaderDocument? document;
  final List<String> paragraphs;
  final List<List<ReaderPagedSlice>> pagedPages;
  final List<List<ReaderPagedBlock>> pagedBlockPages;
  final Map<int, ReaderRenderTextItem> textItemsByParagraph;
  final ReaderImageDecodeBudget? imageDecodeBudget;
  final EdgeInsets? pagePadding;
  final String? emptyMessage;
  final bool allowSelection;
  final TextAlign? textAlign;
  final bool enableLightweightRenderCache;
}

ReaderPagedResolvedPage resolveReaderPagedPage({
  required ReaderTextPagedViewModel model,
  required int pageIndex,
}) {
  final totalPages =
      model.pagedBlockPages.isNotEmpty
          ? model.pagedBlockPages.length
          : model.pagedPages.isNotEmpty
          ? model.pagedPages.length
          : model.pageCount;
  final safePageIndex = pageIndex.clamp(0, math.max(0, totalPages - 1)).toInt();
  final slices =
      model.pagedPages.isNotEmpty && safePageIndex < model.pagedPages.length
          ? model.pagedPages[safePageIndex]
          : const <ReaderPagedSlice>[];
  final resolvedSlices = List<ReaderPagedResolvedSlice>.generate(
    slices.length,
    (index) => _resolveReaderPagedSlice(
      model: model,
      pageIndex: safePageIndex,
      sliceIndex: index,
      totalSlices: slices.length,
      slice: slices[index],
    ),
    growable: false,
  );
  return ReaderPagedResolvedPage(
    pageIndex: safePageIndex,
    totalPages: totalPages,
    slices: resolvedSlices,
    pagePadding: model.pagePadding ?? model.surfaceMetrics.effectivePagePadding,
  );
}

class ReaderPagedResolvedPage {
  const ReaderPagedResolvedPage({
    required this.pageIndex,
    required this.totalPages,
    required this.slices,
    required this.pagePadding,
  });

  final int pageIndex;
  final int totalPages;
  final List<ReaderPagedResolvedSlice> slices;
  final EdgeInsets pagePadding;
}

class ReaderPagedResolvedSlice {
  const ReaderPagedResolvedSlice({
    required this.pageIndex,
    required this.sliceIndex,
    required this.isLastOnPage,
    required this.slice,
    required this.rawText,
    required this.displayText,
    required this.indentLength,
    required this.textStyle,
    required this.textAlign,
    required this.spacingAfter,
    required this.kind,
    required this.measuredHeight,
    this.paragraphIndex,
    this.renderItem,
  });

  final int pageIndex;
  final int sliceIndex;
  final bool isLastOnPage;
  final ReaderPagedSlice slice;
  final int? paragraphIndex;
  final ReaderRenderTextItem? renderItem;
  final ReaderRenderTextKind kind;
  final String rawText;
  final String displayText;
  final int indentLength;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final double spacingAfter;
  final double measuredHeight;
}

class ReaderTextPagedView extends StatefulWidget {
  const ReaderTextPagedView({
    super.key,
    required this.model,
    this.pageBuilder,
    this.pageController,
    this.onPageChanged,
    this.onVisiblePositionChanged,
    this.onScrollInteractionChanged,
    this.pageFrameBuilder,
    this.resolvedPageBuilder,
    this.resolvedSliceBuilder,
    this.sliceTextSpanBuilder,
    this.emptyBuilder,
    this.physics,
    this.content,
  });

  final ReaderTextPagedViewModel model;
  final ReaderPagedPageBuilder? pageBuilder;
  final PageController? pageController;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderVisiblePosition>? onVisiblePositionChanged;
  final ValueChanged<bool>? onScrollInteractionChanged;
  final ReaderPagedPageFrameBuilder? pageFrameBuilder;
  final ReaderResolvedPagedPageBuilder? resolvedPageBuilder;
  final ReaderResolvedPagedSliceBuilder? resolvedSliceBuilder;
  final ReaderPagedSliceTextSpanBuilder? sliceTextSpanBuilder;
  final ReaderPagedEmptyBuilder? emptyBuilder;
  final ScrollPhysics? physics;
  final Widget? content;

  @override
  State<ReaderTextPagedView> createState() => _ReaderTextPagedViewState();
}

class _ReaderTextPagedViewState extends State<ReaderTextPagedView> {
  PageController? _ownedPageController;
  int? _pendingJumpPage;

  ReaderTextPagedViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    _syncOwnedPageController();
  }

  @override
  void didUpdateWidget(covariant ReaderTextPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOwnedPageController();
  }

  @override
  void dispose() {
    _ownedPageController?.dispose();
    super.dispose();
  }

  int get _effectivePageCount =>
      model.pagedBlockPages.isNotEmpty
          ? model.pagedBlockPages.length
          : model.pagedPages.isNotEmpty
          ? model.pagedPages.length
          : model.pageCount;

  int _safeCurrentPageIndex(int effectivePageCount) {
    return model.currentPageIndex.clamp(0, effectivePageCount - 1);
  }

  void _syncOwnedPageController() {
    if (widget.content != null || widget.pageController != null) {
      _ownedPageController?.dispose();
      _ownedPageController = null;
      return;
    }

    final effectivePageCount = _effectivePageCount;
    if (effectivePageCount <= 0) {
      _ownedPageController?.dispose();
      _ownedPageController = null;
      return;
    }

    final safePage = _safeCurrentPageIndex(effectivePageCount);
    final controller = _ownedPageController;
    if (controller == null) {
      _ownedPageController = PageController(initialPage: safePage);
      return;
    }
    if (!controller.hasClients) {
      return;
    }

    final currentPage = controller.page?.round() ?? controller.initialPage;
    if (currentPage != safePage) {
      _scheduleJumpToPage(safePage);
    }
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
      final effectivePageCount = _effectivePageCount;
      if (effectivePageCount <= 0) {
        return;
      }
      final safeTarget = target.clamp(0, effectivePageCount - 1);
      final currentPage = controller.page?.round() ?? controller.initialPage;
      if (currentPage != safeTarget) {
        controller.jumpToPage(safeTarget);
      }
    });
  }

  void _notifyPageChanged(int pageIndex, int pageCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onPageChanged?.call(pageIndex);
      widget.onVisiblePositionChanged?.call(
        ReaderVisiblePosition(pageIndex: pageIndex, pageCount: pageCount),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content != null) {
      return widget.content!;
    }

    final effectivePageCount = _effectivePageCount;
    if (effectivePageCount <= 0) {
      return widget.emptyBuilder?.call(context, model) ??
          _buildDefaultEmptyState();
    }

    final controller = widget.pageController ?? _ownedPageController;

    final pageView = PageView.builder(
      controller: controller,
      physics: widget.physics,
      itemCount: effectivePageCount,
      onPageChanged: (pageIndex) {
        _notifyPageChanged(pageIndex, effectivePageCount);
      },
      itemBuilder: (context, index) {
        final pageChild = _buildPageChild(context, index);
        final framed =
            widget.pageFrameBuilder?.call(context, model, index, pageChild) ??
            pageChild;
        return RepaintBoundary(
          key: ValueKey<String>('reader_text_page_$index'),
          child: framed,
        );
      },
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          widget.onScrollInteractionChanged?.call(true);
        } else if (notification is ScrollEndNotification) {
          widget.onScrollInteractionChanged?.call(false);
        } else if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
          widget.onScrollInteractionChanged?.call(false);
        }
        return false;
      },
      child: pageView,
    );
  }

  Widget _buildPageChild(BuildContext context, int pageIndex) {
    if (widget.pageBuilder != null) {
      return widget.pageBuilder!(context, pageIndex);
    }
    return ReaderPagedPageContent(
      model: model,
      pageIndex: pageIndex,
      resolvedPageBuilder: widget.resolvedPageBuilder,
      resolvedSliceBuilder: widget.resolvedSliceBuilder,
      sliceTextSpanBuilder: widget.sliceTextSpanBuilder,
    ).maybeCachePage(
      enabled: model.enableLightweightRenderCache,
      pageIndex: pageIndex,
    );
  }

  Widget _buildDefaultEmptyState() {
    return Center(
      child: Text(
        model.emptyMessage ?? '当前章节暂无可分页内容',
        style: TextStyle(color: model.palette.secondaryTextColor),
      ),
    );
  }
}

extension _ReaderPagedPageCacheExtension on Widget {
  Widget maybeCachePage({required bool enabled, required int pageIndex}) {
    if (!enabled) {
      return this;
    }
    return _ReaderLightweightPagedPageCache(
      key: ValueKey('reader_paged_page_cache_$pageIndex'),
      child: this,
    );
  }
}

class _ReaderLightweightPagedPageCache extends StatefulWidget {
  const _ReaderLightweightPagedPageCache({super.key, required this.child});

  final Widget child;

  @override
  State<_ReaderLightweightPagedPageCache> createState() =>
      _ReaderLightweightPagedPageCacheState();
}

class _ReaderLightweightPagedPageCacheState
    extends State<_ReaderLightweightPagedPageCache>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class ReaderPagedPageContent extends StatelessWidget {
  const ReaderPagedPageContent({
    super.key,
    required this.model,
    required this.pageIndex,
    this.resolvedPageBuilder,
    this.resolvedSliceBuilder,
    this.sliceTextSpanBuilder,
    this.paddingResolver,
  });

  final ReaderTextPagedViewModel model;
  final int pageIndex;
  final ReaderResolvedPagedPageBuilder? resolvedPageBuilder;
  final ReaderResolvedPagedSliceBuilder? resolvedSliceBuilder;
  final ReaderPagedSliceTextSpanBuilder? sliceTextSpanBuilder;
  final ReaderPagedPagePaddingResolver? paddingResolver;

  @override
  Widget build(BuildContext context) {
    final resolvedPage = resolveReaderPagedPage(
      model: model,
      pageIndex: pageIndex,
    );
    final defaultPage = _buildDefaultPage(context, resolvedPage);
    final child =
        resolvedPageBuilder?.call(context, resolvedPage, defaultPage) ??
        defaultPage;
    final padding =
        paddingResolver?.call(model) ??
        model.pagePadding ??
        model.surfaceMetrics.effectivePagePadding;
    return Padding(padding: padding, child: child);
  }

  Widget _buildDefaultPage(BuildContext context, ReaderPagedResolvedPage page) {
    final blockPage =
        model.pagedBlockPages.isNotEmpty &&
                page.pageIndex < model.pagedBlockPages.length
            ? model.pagedBlockPages[page.pageIndex]
            : const <ReaderPagedBlock>[];
    if (blockPage.isNotEmpty) {
      return _buildDefaultBlockPage(context, blockPage);
    }
    if (page.slices.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final offsets = _computePageSliceOffsets(
          page: page,
          availableHeight: constraints.maxHeight,
          settings: model.settings,
        );
        final children = <Widget>[];
        for (var index = 0; index < page.slices.length; index += 1) {
          final slice = page.slices[index];
          final child =
              resolvedSliceBuilder?.call(
                context,
                slice,
                _buildDefaultSlice(context, slice),
              ) ??
              _buildDefaultSlice(context, slice);
          children.add(
            Positioned(top: offsets[index], left: 0, right: 0, child: child),
          );
        }
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(children: children),
          ),
        );
      },
    );
  }

  Widget _buildDefaultBlockPage(
    BuildContext context,
    List<ReaderPagedBlock> blocks,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        var dy = 0.0;
        for (final block in blocks) {
          final child = switch (block.kind) {
            ReaderPagedBlockKind.image => _buildDefaultBlockImage(
              context,
              block,
            ),
            ReaderPagedBlockKind.text => _buildDefaultBlockText(context, block),
          };
          children.add(Positioned(top: dy, left: 0, right: 0, child: child));
          dy += block.height + model.settings.paragraphSpacing;
        }
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(children: children),
          ),
        );
      },
    );
  }

  Widget _buildDefaultBlockText(BuildContext context, ReaderPagedBlock block) {
    final paragraphIndex = block.paragraphIndex ?? -1;
    final paragraph = _paragraphForIndex(model, paragraphIndex);
    final start = (block.start ?? 0).clamp(0, paragraph.length);
    final end = (block.end ?? start).clamp(start, paragraph.length);
    final renderItem = _textItemForParagraphIndex(model, paragraphIndex);
    final resolved = resolveReaderTextBlockPresentation(
      settings: model.settings,
      primaryTextColor: model.palette.primaryTextColor,
      secondaryTextColor: model.palette.secondaryTextColor,
      item: renderItem,
      isLast: false,
      paragraphTextAlign: model.textAlign,
    );
    final text = paragraph.substring(start, end);
    final displayText =
        start == 0 && resolved.displayText.isNotEmpty
            ? resolved.displayText
            : text;
    return RepaintBoundary(
      child: SizedBox(
        height: block.height > 0 ? block.height : null,
        child: Align(
          alignment: Alignment.topLeft,
          child:
              model.allowSelection
                  ? SelectableText(
                    displayText,
                    style: resolved.textStyle,
                    textAlign: resolved.textAlign,
                  )
                  : Text(
                    displayText,
                    style: resolved.textStyle,
                    textAlign: resolved.textAlign,
                  ),
        ),
      ),
    );
  }

  Widget _buildDefaultBlockImage(BuildContext context, ReaderPagedBlock block) {
    final imageUrl = block.imageUrl ?? '';
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: SizedBox(
        height: block.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImageForUrl(context, imageUrl),
        ),
      ),
    );
  }

  Widget _buildImageForUrl(BuildContext context, String imageUrl) {
    Widget errorBuilder(BuildContext context, Object error, StackTrace? stack) {
      return ColoredBox(
        color: Colors.black12,
        child: Center(
          child: Text('图片加载失败', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        fit: BoxFit.contain,
        cacheWidth: model.imageDecodeBudget?.cacheWidth,
        cacheHeight: model.imageDecodeBudget?.cacheHeight,
        errorBuilder: errorBuilder,
      );
    }
    if (imageUrl.startsWith('data:image/')) {
      final comma = imageUrl.indexOf(',');
      if (comma > 0) {
        try {
          final metadata = imageUrl.substring(0, comma).toLowerCase();
          final payload = imageUrl.substring(comma + 1);
          final bytes = Uint8List.fromList(
            metadata.contains(';base64')
                ? base64Decode(payload)
                : utf8.encode(Uri.decodeComponent(payload)),
          );
          final maxBytes = model.imageDecodeBudget?.maxDataUriBytes;
          if (maxBytes != null && bytes.length > maxBytes) {
            return errorBuilder(context, const FormatException(), null);
          }
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            cacheWidth: model.imageDecodeBudget?.cacheWidth,
            cacheHeight: model.imageDecodeBudget?.cacheHeight,
            errorBuilder: errorBuilder,
          );
        } catch (_) {
          return errorBuilder(context, const FormatException(), null);
        }
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      cacheWidth: model.imageDecodeBudget?.cacheWidth,
      cacheHeight: model.imageDecodeBudget?.cacheHeight,
      errorBuilder: errorBuilder,
    );
  }

  Widget _buildDefaultSlice(
    BuildContext context,
    ReaderPagedResolvedSlice slice,
  ) {
    final textSpan =
        sliceTextSpanBuilder?.call(context, slice) ??
        TextSpan(text: slice.displayText, style: slice.textStyle);
    final textWidget =
        model.allowSelection
            ? SelectableText.rich(textSpan, textAlign: slice.textAlign)
            : Text.rich(textSpan, textAlign: slice.textAlign);
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: slice.spacingAfter),
        child: SizedBox(
          height: slice.measuredHeight > 0 ? slice.measuredHeight : null,
          child: Align(alignment: Alignment.topLeft, child: textWidget),
        ),
      ),
    );
  }
}

List<double> _computePageSliceOffsets({
  required ReaderPagedResolvedPage page,
  required double availableHeight,
  required ReaderSettings settings,
}) {
  final offsets = <double>[];
  var dy = 0.0;
  for (final slice in page.slices) {
    offsets.add(dy);
    dy += slice.measuredHeight + slice.spacingAfter;
  }
  if (!settings.textBottomJustifyEnabled || page.slices.length <= 1) {
    return offsets;
  }
  final surplus = availableHeight - dy;
  if (surplus <= 0) {
    return offsets;
  }
  final lastSlice = page.slices.last;
  final lineHeight =
      (lastSlice.textStyle.fontSize ?? 18) *
      (lastSlice.textStyle.height ?? settings.lineHeight);
  if (surplus >= lineHeight) {
    return offsets;
  }
  final perGap = surplus / (page.slices.length - 1);
  if (perGap <= 0) {
    return offsets;
  }
  return List<double>.generate(
    page.slices.length,
    (index) => offsets[index] + (perGap * index),
    growable: false,
  );
}

ReaderPagedResolvedSlice _resolveReaderPagedSlice({
  required ReaderTextPagedViewModel model,
  required int pageIndex,
  required int sliceIndex,
  required int totalSlices,
  required ReaderPagedSlice slice,
}) {
  final paragraphIndex = slice.paragraphIndex;
  final paragraph = _paragraphForIndex(model, paragraphIndex);
  final normalizedStart = slice.start.clamp(0, paragraph.length);
  final normalizedEnd = slice.end.clamp(normalizedStart, paragraph.length);
  final rawText = paragraph.substring(normalizedStart, normalizedEnd);
  final renderItem = _textItemForParagraphIndex(model, paragraphIndex);
  final resolved = resolveReaderTextBlockPresentation(
    settings: model.settings,
    primaryTextColor: model.palette.primaryTextColor,
    secondaryTextColor: model.palette.secondaryTextColor,
    item: renderItem,
    isLast: sliceIndex == totalSlices - 1,
    paragraphTextAlign: model.textAlign,
  );
  return ReaderPagedResolvedSlice(
    pageIndex: pageIndex,
    sliceIndex: sliceIndex,
    isLastOnPage: sliceIndex == totalSlices - 1,
    slice: slice,
    paragraphIndex: paragraphIndex,
    renderItem: renderItem,
    kind: renderItem?.kind ?? ReaderRenderTextKind.paragraph,
    rawText: rawText,
    displayText:
        normalizedStart == 0 && resolved.displayText.isNotEmpty
            ? resolved.displayText
            : rawText,
    indentLength: normalizedStart == 0 ? resolved.indentLength : 0,
    textStyle: resolved.textStyle,
    textAlign: resolved.textAlign,
    spacingAfter: sliceIndex == totalSlices - 1 ? 0 : resolved.spacingAfter,
    measuredHeight: slice.height,
  );
}

String _paragraphForIndex(ReaderTextPagedViewModel model, int paragraphIndex) {
  if (paragraphIndex < 0 || paragraphIndex >= model.paragraphs.length) {
    return '';
  }
  return model.paragraphs[paragraphIndex];
}

ReaderRenderTextItem? _textItemForParagraphIndex(
  ReaderTextPagedViewModel model,
  int paragraphIndex,
) {
  final provided = model.textItemsByParagraph[paragraphIndex];
  if (provided != null) {
    return provided;
  }
  final document = model.document;
  if (document == null) {
    return null;
  }
  final index = buildReaderRenderTextItemIndex(
    buildReaderRenderBlockItems(document),
  );
  return index[paragraphIndex];
}
