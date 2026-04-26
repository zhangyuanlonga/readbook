import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_document_render_model.dart';
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
    this.textItemsByParagraph = const <int, ReaderRenderTextItem>{},
    this.pagePadding,
    this.emptyMessage,
    this.allowSelection = false,
    this.textAlign,
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
  final Map<int, ReaderRenderTextItem> textItemsByParagraph;
  final EdgeInsets? pagePadding;
  final String? emptyMessage;
  final bool allowSelection;
  final TextAlign? textAlign;
}

ReaderPagedResolvedPage resolveReaderPagedPage({
  required ReaderTextPagedViewModel model,
  required int pageIndex,
}) {
  final totalPages =
      model.pagedPages.isNotEmpty ? model.pagedPages.length : model.pageCount;
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

class ReaderTextPagedView extends StatelessWidget {
  const ReaderTextPagedView({
    super.key,
    required this.model,
    this.pageBuilder,
    this.pageController,
    this.onPageChanged,
    this.onVisiblePositionChanged,
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
  final ReaderPagedPageFrameBuilder? pageFrameBuilder;
  final ReaderResolvedPagedPageBuilder? resolvedPageBuilder;
  final ReaderResolvedPagedSliceBuilder? resolvedSliceBuilder;
  final ReaderPagedSliceTextSpanBuilder? sliceTextSpanBuilder;
  final ReaderPagedEmptyBuilder? emptyBuilder;
  final ScrollPhysics? physics;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    if (content != null) {
      return content!;
    }

    final effectivePageCount =
        model.pagedPages.isNotEmpty ? model.pagedPages.length : model.pageCount;
    if (effectivePageCount <= 0) {
      return emptyBuilder?.call(context, model) ?? _buildDefaultEmptyState();
    }

    final safeInitialPage = model.currentPageIndex.clamp(
      0,
      effectivePageCount - 1,
    );
    final controller =
        pageController ?? PageController(initialPage: safeInitialPage);

    return PageView.builder(
      controller: controller,
      physics: physics,
      itemCount: effectivePageCount,
      onPageChanged: (pageIndex) {
        onPageChanged?.call(pageIndex);
        onVisiblePositionChanged?.call(
          ReaderVisiblePosition(
            pageIndex: pageIndex,
            pageCount: effectivePageCount,
          ),
        );
      },
      itemBuilder: (context, index) {
        final pageChild = _buildPageChild(context, index);
        return pageFrameBuilder?.call(context, model, index, pageChild) ??
            pageChild;
      },
    );
  }

  Widget _buildPageChild(BuildContext context, int pageIndex) {
    if (pageBuilder != null) {
      return Padding(
        padding: model.pagePadding ?? model.surfaceMetrics.effectivePagePadding,
        child: pageBuilder!(context, pageIndex),
      );
    }
    return ReaderPagedPageContent(
      model: model,
      pageIndex: pageIndex,
      resolvedPageBuilder: resolvedPageBuilder,
      resolvedSliceBuilder: resolvedSliceBuilder,
      sliceTextSpanBuilder: sliceTextSpanBuilder,
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
    if (page.slices.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        var dy = 0.0;
        final children = <Widget>[];
        for (final slice in page.slices) {
          final child =
              resolvedSliceBuilder?.call(
                context,
                slice,
                _buildDefaultSlice(context, slice),
              ) ??
              _buildDefaultSlice(context, slice);
          children.add(Positioned(top: dy, left: 0, right: 0, child: child));
          dy += slice.measuredHeight + slice.spacingAfter;
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
    displayText: normalizedStart == 0 ? resolved.displayText : rawText,
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
