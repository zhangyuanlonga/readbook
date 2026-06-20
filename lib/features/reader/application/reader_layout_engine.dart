import 'dart:async';
import 'dart:math' as math;

import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_request.dart';
import 'reader_zh_layout_policy.dart';

class ReaderLayoutResult {
  const ReaderLayoutResult({
    required this.request,
    required this.pages,
    required this.elapsedMicros,
    this.isCompleted = true,
  });

  final ReaderLayoutRequest request;
  final List<ReaderLayoutPage> pages;
  final int elapsedMicros;
  final bool isCompleted;

  String get layoutSignature => request.layoutSignature;
  int get pageCount => pages.length;
}

class ReaderLayoutEngine {
  const ReaderLayoutEngine({
    this.zhLayoutPolicy = const ReaderZhLayoutPolicy(),
  });

  final ReaderZhLayoutPolicy zhLayoutPolicy;

  Future<ReaderLayoutResult?> layout(
    ReaderLayoutRequest request, {
    ReaderLayoutCancellationToken? cancellationToken,
    void Function(ReaderLayoutPage page)? onPageReady,
  }) async {
    final stopwatch = Stopwatch()..start();
    final pages = <ReaderLayoutPage>[];
    final currentLines = <ReaderLayoutLine>[];
    var pageIndex = 0;
    var y = 0.0;
    var chapterOffset = 0;
    var operationsSinceYield = 0;

    bool isCancelled() => cancellationToken?.isCancelled ?? false;

    void flushPage() {
      if (currentLines.isEmpty) {
        return;
      }
      final page = ReaderLayoutPage(
        chapterId: request.chapterId,
        chapterIndex: request.chapterIndex,
        pageIndex: pageIndex,
        startOffset: currentLines.first.chapterOffset,
        endOffset: currentLines.last.endChapterOffset,
        contentWidth: request.spec.contentWidth,
        contentHeight: request.spec.contentHeight,
        layoutSignature: request.layoutSignature,
        lines: List<ReaderLayoutLine>.unmodifiable(currentLines),
      );
      pages.add(page);
      onPageReady?.call(page);
      currentLines.clear();
      pageIndex += 1;
      y = 0;
    }

    for (var blockIndex = 0; blockIndex < request.blocks.length; blockIndex++) {
      if (isCancelled()) {
        return null;
      }

      final block = request.blocks[blockIndex];
      if (block.isImage) {
        final height = _imageHeight(block, request.spec);
        if (y + height > request.spec.contentHeight &&
            currentLines.isNotEmpty) {
          flushPage();
        }
        final line = _buildImageLine(
          block: block,
          blockIndex: blockIndex,
          chapterOffset: chapterOffset,
          pageStartOffset:
              currentLines.isEmpty
                  ? chapterOffset
                  : currentLines.first.chapterOffset,
          lineIndex: currentLines.length,
          y: y,
          height: height,
          request: request,
        );
        currentLines.add(line);
        y += height + request.spec.paragraphSpacing;
        chapterOffset += block.contentLength + request.paragraphSeparatorLength;
        continue;
      }

      final text = block.text;
      if (text.isEmpty) {
        chapterOffset += request.paragraphSeparatorLength;
        continue;
      }

      var localOffset = 0;
      while (localOffset < text.length) {
        if (isCancelled()) {
          return null;
        }

        final isFirstLineInBlock = localOffset == 0;
        final lineHeight = _lineHeight(request.spec);
        if (y + lineHeight > request.spec.contentHeight &&
            currentLines.isNotEmpty) {
          flushPage();
        }

        final lineStartX = _lineStartX(request.spec, block, isFirstLineInBlock);
        final maxChars = _maxCharsForLine(request.spec, lineStartX);
        final proposedEndOffset = math.min(text.length, localOffset + maxChars);
        final endOffset =
            request.spec.useZhLayout
                ? zhLayoutPolicy.adjustBreakOffset(
                  text: text,
                  start: localOffset,
                  proposedEnd: proposedEndOffset,
                )
                : proposedEndOffset;
        final segment = text.substring(localOffset, endOffset);
        final absoluteStart = chapterOffset + localOffset;
        final absoluteEnd = chapterOffset + endOffset;
        final pageStartOffset =
            currentLines.isEmpty
                ? absoluteStart
                : currentLines.first.chapterOffset;
        final line = _buildTextLine(
          block: block,
          blockIndex: blockIndex,
          lineIndex: currentLines.length,
          text: segment,
          absoluteStart: absoluteStart,
          absoluteEnd: absoluteEnd,
          pageStartOffset: pageStartOffset,
          lineStartX: lineStartX,
          y: y,
          request: request,
          isParagraphEnd: endOffset >= text.length,
        );
        currentLines.add(line);
        y += lineHeight;
        localOffset = endOffset;
        if (endOffset >= text.length) {
          y += request.spec.paragraphSpacing;
        }

        operationsSinceYield += 1;
        if (operationsSinceYield >= 80) {
          operationsSinceYield = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }

      chapterOffset += text.length + request.paragraphSeparatorLength;
    }

    if (isCancelled()) {
      return null;
    }

    flushPage();
    stopwatch.stop();
    return ReaderLayoutResult(
      request: request,
      pages: List<ReaderLayoutPage>.unmodifiable(pages),
      elapsedMicros: stopwatch.elapsedMicroseconds,
    );
  }

  ReaderLayoutLine _buildTextLine({
    required ReaderLayoutBlock block,
    required int blockIndex,
    required int lineIndex,
    required String text,
    required int absoluteStart,
    required int absoluteEnd,
    required int pageStartOffset,
    required double lineStartX,
    required double y,
    required ReaderLayoutRequest request,
    required bool isParagraphEnd,
  }) {
    final lineHeight = _lineHeight(request.spec);
    final lineBottom = y + lineHeight;
    final textWidth = _charAdvance(request.spec) * text.length;
    final column = ReaderLayoutColumn(
      columnIndex: 0,
      kind:
          block.isLink
              ? ReaderLayoutColumnKind.link
              : ReaderLayoutColumnKind.text,
      startOffset: absoluteStart,
      endOffset: absoluteEnd,
      rect: ReaderLayoutRect(
        left: lineStartX,
        top: y,
        right: math.min(request.spec.contentWidth, lineStartX + textWidth),
        bottom: lineBottom,
      ),
      text: text,
      styleKey: _styleKeyForBlock(block),
      payload: block.columnPayload,
    );

    return ReaderLayoutLine(
      lineIndex: lineIndex,
      paragraphIndex: block.sourceIndex ?? blockIndex,
      text: text,
      chapterOffset: absoluteStart,
      pageOffset: absoluteStart - pageStartOffset,
      lineTop: y,
      lineBase: y + math.min(request.spec.fontSize, lineHeight),
      lineBottom: lineBottom,
      columns: <ReaderLayoutColumn>[column],
      isTitle: block.isTitle,
      isParagraphEnd: isParagraphEnd,
    );
  }

  ReaderLayoutLine _buildImageLine({
    required ReaderLayoutBlock block,
    required int blockIndex,
    required int chapterOffset,
    required int pageStartOffset,
    required int lineIndex,
    required double y,
    required double height,
    required ReaderLayoutRequest request,
  }) {
    final column = ReaderLayoutColumn(
      columnIndex: 0,
      kind: ReaderLayoutColumnKind.image,
      startOffset: chapterOffset,
      endOffset: chapterOffset + block.contentLength,
      rect: ReaderLayoutRect(
        left: 0,
        top: y,
        right: request.spec.contentWidth,
        bottom: y + height,
      ),
      payload: <String, Object?>{
        ...block.columnPayload,
        if (block.imageUrl != null) 'imageUrl': block.imageUrl,
      },
    );
    return ReaderLayoutLine(
      lineIndex: lineIndex,
      paragraphIndex: block.sourceIndex ?? blockIndex,
      text: '',
      chapterOffset: chapterOffset,
      pageOffset: chapterOffset - pageStartOffset,
      lineTop: y,
      lineBase: y + height,
      lineBottom: y + height,
      columns: <ReaderLayoutColumn>[column],
      isImage: true,
      isParagraphEnd: true,
    );
  }

  double _lineStartX(
    ReaderLayoutSpec spec,
    ReaderLayoutBlock block,
    bool isFirstLineInBlock,
  ) {
    if (!isFirstLineInBlock || block.isTitle) {
      return 0;
    }
    return math.min(spec.contentWidth, spec.fontSize * spec.paragraphIndent);
  }

  String _styleKeyForBlock(ReaderLayoutBlock block) {
    if (block.isTitle) {
      return 'title';
    }
    if (block.isCaption) {
      return 'caption';
    }
    if (block.isFootnote) {
      return 'footnote';
    }
    if (block.isLink) {
      return 'link';
    }
    return 'body';
  }

  int _maxCharsForLine(ReaderLayoutSpec spec, double lineStartX) {
    final availableWidth = math.max(1.0, spec.contentWidth - lineStartX);
    return math.max(1, (availableWidth / _charAdvance(spec)).floor());
  }

  double _charAdvance(ReaderLayoutSpec spec) {
    return math.max(1.0, spec.fontSize * 0.56 + spec.letterSpacing);
  }

  double _lineHeight(ReaderLayoutSpec spec) {
    return math.max(1.0, spec.fontSize * spec.lineHeight);
  }

  double _imageHeight(ReaderLayoutBlock block, ReaderLayoutSpec spec) {
    final fallback = spec.contentWidth / spec.imagePlaceholderAspectRatio;
    return block.estimatedHeight > 0
        ? block.estimatedHeight
        : fallback.clamp(1.0, spec.contentHeight);
  }
}
