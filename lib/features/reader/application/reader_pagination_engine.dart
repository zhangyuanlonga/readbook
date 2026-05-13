import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'reader_document_render_model.dart';
import 'reader_pagination_models.dart';
import 'reader_pagination_spec.dart';

enum ReaderPaginationEnsureDecision {
  skipInvalidViewport,
  reuseExistingPages,
  awaitInFlightTask,
  paginate,
}

class ReaderPaginationSessionState {
  const ReaderPaginationSessionState({
    this.isPaginating = false,
    this.signature,
    this.pendingRestoreRatio,
  });

  final bool isPaginating;
  final String? signature;
  final double? pendingRestoreRatio;

  ReaderPaginationSessionState copyWith({
    bool? isPaginating,
    Object? signature = _readerPaginationUnset,
    Object? pendingRestoreRatio = _readerPaginationUnset,
  }) {
    return ReaderPaginationSessionState(
      isPaginating: isPaginating ?? this.isPaginating,
      signature:
          identical(signature, _readerPaginationUnset)
              ? this.signature
              : signature as String?,
      pendingRestoreRatio:
          identical(pendingRestoreRatio, _readerPaginationUnset)
              ? this.pendingRestoreRatio
              : pendingRestoreRatio as double?,
    );
  }
}

class ReaderPaginationEnsureRequest {
  const ReaderPaginationEnsureRequest({
    required this.spec,
    required this.signature,
    required this.currentState,
    required this.hasExistingPages,
    required this.currentProgressRatio,
  });

  final ReaderPaginationSpec spec;
  final String signature;
  final ReaderPaginationSessionState currentState;
  final bool hasExistingPages;
  final double currentProgressRatio;
}

class ReaderPaginationEnsurePlan {
  const ReaderPaginationEnsurePlan({
    required this.decision,
    required this.signature,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required this.preservedRatio,
  });

  final ReaderPaginationEnsureDecision decision;
  final String signature;
  final double normalizedWidth;
  final double normalizedHeight;
  final double preservedRatio;

  bool get shouldPaginate =>
      decision == ReaderPaginationEnsureDecision.paginate;

  ReaderPaginationSessionState buildLoadingState() {
    return ReaderPaginationSessionState(
      isPaginating: shouldPaginate,
      signature: signature,
      pendingRestoreRatio: shouldPaginate ? preservedRatio : null,
    );
  }

  ReaderPaginationSessionState buildCompletedState() {
    return ReaderPaginationSessionState(signature: signature);
  }
}

class ReaderPaginationRequest {
  const ReaderPaginationRequest({
    required this.paragraphs,
    required this.spec,
    required this.paragraphStyle,
    this.paragraphModels,
    this.textScaler = TextScaler.noScaling,
    this.yieldInterval = const Duration(milliseconds: 8),
    this.shouldAbort,
    this.textDirection = TextDirection.ltr,
    this.textAlign = TextAlign.start,
  });

  final List<String> paragraphs;
  final ReaderPaginationSpec spec;
  final TextStyle paragraphStyle;
  final List<ReaderPaginationParagraph>? paragraphModels;
  final TextScaler textScaler;
  final Duration yieldInterval;
  final bool Function()? shouldAbort;
  final TextDirection textDirection;
  final TextAlign textAlign;
}

class ReaderPaginationParagraph {
  const ReaderPaginationParagraph({
    required this.text,
    required this.paragraphStyle,
    this.textAlign = TextAlign.start,
    this.firstLinePrefix = '',
    this.spacingAfter = 0,
  });

  final String text;
  final TextStyle paragraphStyle;
  final TextAlign textAlign;
  final String firstLinePrefix;
  final double spacingAfter;
}

class ReaderPaginationResult {
  const ReaderPaginationResult({required this.paragraphs, required this.pages});

  final List<String> paragraphs;
  final List<List<ReaderPagedSlice>> pages;
}

class ReaderBlockPaginationRequest {
  const ReaderBlockPaginationRequest({
    required this.renderItems,
    required this.paragraphs,
    required this.spec,
    required this.paragraphStyle,
    this.paragraphModels,
    this.textScaler = TextScaler.noScaling,
    this.yieldInterval = const Duration(milliseconds: 8),
    this.shouldAbort,
    this.textDirection = TextDirection.ltr,
    this.textAlign = TextAlign.start,
    this.imagePlaceholderAspectRatio = 3 / 4,
  });

  final List<ReaderRenderBlockItem> renderItems;
  final List<String> paragraphs;
  final ReaderPaginationSpec spec;
  final TextStyle paragraphStyle;
  final List<ReaderPaginationParagraph>? paragraphModels;
  final TextScaler textScaler;
  final Duration yieldInterval;
  final bool Function()? shouldAbort;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final double imagePlaceholderAspectRatio;
}

class ReaderPaginationEngine {
  const ReaderPaginationEngine();

  static const double _kPageTailSafetyBuffer = 4.0;

  ReaderPaginationEnsurePlan buildEnsurePlan(
    ReaderPaginationEnsureRequest request,
  ) {
    final normalizedWidth = request.spec.contentWidth.clamp(0.0, 2000.0);
    final normalizedHeight = request.spec.contentHeight.clamp(0.0, 4000.0);
    final preservedRatio = _normalizeRatio(
      request.currentState.pendingRestoreRatio ?? request.currentProgressRatio,
    );

    if (normalizedWidth < 20 || normalizedHeight < 40) {
      return ReaderPaginationEnsurePlan(
        decision: ReaderPaginationEnsureDecision.skipInvalidViewport,
        signature: request.signature,
        normalizedWidth: normalizedWidth,
        normalizedHeight: normalizedHeight,
        preservedRatio: preservedRatio,
      );
    }

    if (request.signature == request.currentState.signature &&
        request.hasExistingPages &&
        !request.currentState.isPaginating) {
      return ReaderPaginationEnsurePlan(
        decision: ReaderPaginationEnsureDecision.reuseExistingPages,
        signature: request.signature,
        normalizedWidth: normalizedWidth,
        normalizedHeight: normalizedHeight,
        preservedRatio: preservedRatio,
      );
    }

    if (request.signature == request.currentState.signature &&
        request.currentState.isPaginating) {
      return ReaderPaginationEnsurePlan(
        decision: ReaderPaginationEnsureDecision.awaitInFlightTask,
        signature: request.signature,
        normalizedWidth: normalizedWidth,
        normalizedHeight: normalizedHeight,
        preservedRatio: preservedRatio,
      );
    }

    return ReaderPaginationEnsurePlan(
      decision: ReaderPaginationEnsureDecision.paginate,
      signature: request.signature,
      normalizedWidth: normalizedWidth,
      normalizedHeight: normalizedHeight,
      preservedRatio: preservedRatio,
    );
  }

  Future<ReaderPaginationResult?> paginateParagraphs(
    ReaderPaginationRequest request,
  ) {
    final timelineTask =
        developer.TimelineTask()..start(
          'reader.pagination.paragraphs',
          arguments: <String, Object?>{
            'paragraphCount': request.paragraphs.length,
            'contentWidth': request.spec.contentWidth,
            'contentHeight': request.spec.contentHeight,
          },
        );
    return _paginateParagraphsInternal(request).then(
      (result) {
        timelineTask.finish(
          arguments: <String, Object?>{
            'status': result == null ? 'aborted' : 'ready',
            'pageCount': result?.pages.length ?? 0,
          },
        );
        return result;
      },
      onError: (Object error, StackTrace stackTrace) {
        timelineTask.finish(
          arguments: <String, Object?>{
            'status': 'failed',
            'error': error.toString(),
          },
        );
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<ReaderPaginationResult?> _paginateParagraphsInternal(
    ReaderPaginationRequest request,
  ) async {
    final paragraphModels = _resolveParagraphModels(request);
    if (paragraphModels.isEmpty || paragraphModels.first.text.trim().isEmpty) {
      return const ReaderPaginationResult(
        paragraphs: <String>[],
        pages: <List<ReaderPagedSlice>>[],
      );
    }

    final maxWidth = request.spec.contentWidth;
    final maxHeight = request.spec.contentHeight;

    final painter = TextPainter(
      textDirection: request.textDirection,
      textAlign: request.textAlign,
      textScaler: request.textScaler,
    );

    double measureHeight(
      ReaderPaginationParagraph paragraph,
      String text, {
      required bool includePrefix,
    }) {
      final displayText =
          includePrefix ? '${paragraph.firstLinePrefix}$text' : text;
      painter.textAlign = paragraph.textAlign;
      painter.text = TextSpan(
        text: displayText,
        style: paragraph.paragraphStyle,
      );
      painter.layout(maxWidth: maxWidth);
      return painter.height;
    }

    int resolveFitLength(
      ReaderPaginationParagraph paragraph,
      int start,
      double availableHeight,
    ) {
      final effectiveAvailableHeight = math.max(
        0.0,
        availableHeight - _kPageTailSafetyBuffer,
      );
      if (effectiveAvailableHeight <= 0) {
        return 0;
      }

      final prefix = start == 0 ? paragraph.firstLinePrefix : '';
      final remaining = paragraph.text.substring(start);
      final displayText = '$prefix$remaining';

      painter.textAlign = paragraph.textAlign;
      painter.text = TextSpan(
        text: displayText,
        style: paragraph.paragraphStyle,
      );
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= effectiveAvailableHeight) {
        return remaining.length;
      }

      final lines = painter.computeLineMetrics();
      double? lastLineBottom;

      for (final line in lines) {
        final bottom = line.baseline + line.descent;
        if (bottom <= effectiveAvailableHeight) {
          lastLineBottom = bottom;
          continue;
        }
        break;
      }

      if (lastLineBottom == null) {
        return 0;
      }

      final offset =
          painter
              .getPositionForOffset(
                Offset(
                  (maxWidth - 1).clamp(0.0, maxWidth),
                  (lastLineBottom - 0.1).clamp(0.0, effectiveAvailableHeight),
                ),
              )
              .offset;
      final fit = (offset - prefix.length).clamp(0, remaining.length);
      return fit;
    }

    final pages = <List<ReaderPagedSlice>>[];
    var currentPage = <ReaderPagedSlice>[];
    var remainingHeight = maxHeight;
    var lastSpacingAfter = 0.0;
    final yieldStopwatch = Stopwatch()..start();

    Future<bool> maybeYield() async {
      if (request.shouldAbort?.call() ?? false) {
        return true;
      }
      if (request.yieldInterval <= Duration.zero ||
          yieldStopwatch.elapsed < request.yieldInterval) {
        return false;
      }
      await Future<void>.delayed(Duration.zero);
      yieldStopwatch
        ..reset()
        ..start();
      return request.shouldAbort?.call() ?? false;
    }

    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphModels.length;
      paragraphIndex++
    ) {
      if (request.shouldAbort?.call() ?? false) {
        return null;
      }

      final paragraph = paragraphModels[paragraphIndex];
      if (paragraph.text.trim().isEmpty) {
        continue;
      }

      var offset = 0;
      while (offset < paragraph.text.length) {
        if (request.shouldAbort?.call() ?? false) {
          return null;
        }
        if (await maybeYield()) {
          return null;
        }

        if (currentPage.isNotEmpty) {
          if (remainingHeight <= lastSpacingAfter + _kPageTailSafetyBuffer) {
            pages.add(currentPage);
            currentPage = <ReaderPagedSlice>[];
            remainingHeight = maxHeight;
            lastSpacingAfter = 0.0;
            if (await maybeYield()) {
              return null;
            }
            continue;
          }
          remainingHeight -= lastSpacingAfter;
        }

        final fitLen = resolveFitLength(paragraph, offset, remainingHeight);
        if (fitLen <= 0) {
          if (currentPage.isNotEmpty) {
            pages.add(currentPage);
            currentPage = <ReaderPagedSlice>[];
            remainingHeight = maxHeight;
            lastSpacingAfter = 0.0;
            continue;
          }

          final forced = (paragraph.text.length - offset).clamp(1, 1);
          final end = offset + forced;
          final text = paragraph.text.substring(offset, end);
          remainingHeight -= measureHeight(
            paragraph,
            text,
            includePrefix: offset == 0,
          );
          currentPage.add(
            ReaderPagedSlice(
              paragraphIndex: paragraphIndex,
              start: offset,
              end: end,
              height: measureHeight(
                paragraph,
                text,
                includePrefix: offset == 0,
              ),
            ),
          );
          lastSpacingAfter = paragraph.spacingAfter;
          offset = end;
          pages.add(currentPage);
          currentPage = <ReaderPagedSlice>[];
          remainingHeight = maxHeight;
          lastSpacingAfter = 0.0;
          if (await maybeYield()) {
            return null;
          }
          continue;
        }

        final end = (offset + fitLen).clamp(0, paragraph.text.length);
        final segment = paragraph.text.substring(offset, end);
        remainingHeight -= measureHeight(
          paragraph,
          segment,
          includePrefix: offset == 0,
        );
        currentPage.add(
          ReaderPagedSlice(
            paragraphIndex: paragraphIndex,
            start: offset,
            end: end,
            height: measureHeight(
              paragraph,
              segment,
              includePrefix: offset == 0,
            ),
          ),
        );
        lastSpacingAfter = paragraph.spacingAfter;

        offset = end;

        if (offset < paragraph.text.length) {
          pages.add(currentPage);
          currentPage = <ReaderPagedSlice>[];
          remainingHeight = maxHeight;
          lastSpacingAfter = 0.0;
          if (await maybeYield()) {
            return null;
          }
        }
      }

      if (await maybeYield()) {
        return null;
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return ReaderPaginationResult(
      paragraphs: List<String>.unmodifiable(request.paragraphs),
      pages: pages
          .map((page) => List<ReaderPagedSlice>.unmodifiable(page))
          .toList(growable: false),
    );
  }

  Future<ReaderBlockPaginationResult?> paginateBlocks(
    ReaderBlockPaginationRequest request,
  ) {
    final timelineTask =
        developer.TimelineTask()..start(
          'reader.pagination.blocks',
          arguments: <String, Object?>{
            'blockCount': request.renderItems.length,
            'paragraphCount': request.paragraphs.length,
            'contentWidth': request.spec.contentWidth,
            'contentHeight': request.spec.contentHeight,
          },
        );
    return _paginateBlocksInternal(request).then(
      (result) {
        timelineTask.finish(
          arguments: <String, Object?>{
            'status': result == null ? 'aborted' : 'ready',
            'pageCount': result?.pages.length ?? 0,
          },
        );
        return result;
      },
      onError: (Object error, StackTrace stackTrace) {
        timelineTask.finish(
          arguments: <String, Object?>{
            'status': 'failed',
            'error': error.toString(),
          },
        );
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<ReaderBlockPaginationResult?> _paginateBlocksInternal(
    ReaderBlockPaginationRequest request,
  ) async {
    if (request.renderItems.isEmpty) {
      return const ReaderBlockPaginationResult(
        pages: <List<ReaderPagedBlock>>[],
      );
    }

    final paragraphModels = _resolveParagraphModels(
      ReaderPaginationRequest(
        paragraphs: request.paragraphs,
        spec: request.spec,
        paragraphStyle: request.paragraphStyle,
        paragraphModels: request.paragraphModels,
        textScaler: request.textScaler,
        yieldInterval: request.yieldInterval,
        shouldAbort: request.shouldAbort,
        textDirection: request.textDirection,
        textAlign: request.textAlign,
      ),
    );
    final pages = <List<ReaderPagedBlock>>[];
    var currentPage = <ReaderPagedBlock>[];
    var remainingHeight = request.spec.contentHeight;
    final yieldStopwatch = Stopwatch()..start();

    Future<bool> maybeYield() async {
      if (request.shouldAbort?.call() ?? false) {
        return true;
      }
      if (request.yieldInterval <= Duration.zero ||
          yieldStopwatch.elapsed < request.yieldInterval) {
        return false;
      }
      await Future<void>.delayed(Duration.zero);
      yieldStopwatch
        ..reset()
        ..start();
      return request.shouldAbort?.call() ?? false;
    }

    void flushPage() {
      if (currentPage.isEmpty) {
        return;
      }
      pages.add(List<ReaderPagedBlock>.unmodifiable(currentPage));
      currentPage = <ReaderPagedBlock>[];
      remainingHeight = request.spec.contentHeight;
    }

    for (final item in request.renderItems) {
      if (await maybeYield()) {
        return null;
      }
      if (item is ReaderRenderImageItem) {
        final imageHeight = _resolveImagePlaceholderHeight(request);
        if (currentPage.isNotEmpty &&
            remainingHeight < imageHeight + _kPageTailSafetyBuffer) {
          flushPage();
        }
        currentPage.add(
          ReaderPagedBlock.image(imageUrl: item.imageUrl, height: imageHeight),
        );
        remainingHeight -= imageHeight;
        if (remainingHeight <= _kPageTailSafetyBuffer) {
          flushPage();
        }
        continue;
      }
      if (item is! ReaderRenderTextItem) {
        continue;
      }
      final paragraphIndex = item.paragraphIndex;
      if (paragraphIndex == null ||
          paragraphIndex < 0 ||
          paragraphIndex >= paragraphModels.length) {
        continue;
      }
      final paragraph = paragraphModels[paragraphIndex];
      final paragraphResult = await _paginateParagraphsInternal(
        ReaderPaginationRequest(
          paragraphs: <String>[paragraph.text],
          spec: request.spec,
          paragraphStyle: paragraph.paragraphStyle,
          paragraphModels: <ReaderPaginationParagraph>[
            ReaderPaginationParagraph(
              text: paragraph.text,
              paragraphStyle: paragraph.paragraphStyle,
              textAlign: paragraph.textAlign,
              firstLinePrefix: paragraph.firstLinePrefix,
              spacingAfter: paragraph.spacingAfter,
            ),
          ],
          textScaler: request.textScaler,
          yieldInterval: request.yieldInterval,
          shouldAbort: request.shouldAbort,
          textDirection: request.textDirection,
          textAlign: request.textAlign,
        ),
      );
      if (paragraphResult == null) {
        return null;
      }
      for (final page in paragraphResult.pages) {
        for (final slice in page) {
          if (currentPage.isNotEmpty &&
              remainingHeight < slice.height + _kPageTailSafetyBuffer) {
            flushPage();
          }
          currentPage.add(
            ReaderPagedBlock.text(
              paragraphIndex: paragraphIndex,
              start: slice.start,
              end: slice.end,
              height: slice.height,
            ),
          );
          remainingHeight -= slice.height + paragraph.spacingAfter;
          if (remainingHeight <= _kPageTailSafetyBuffer) {
            flushPage();
          }
        }
      }
    }

    flushPage();
    return ReaderBlockPaginationResult(
      pages: List<List<ReaderPagedBlock>>.unmodifiable(pages),
    );
  }

  static double _normalizeRatio(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  List<ReaderPaginationParagraph> _resolveParagraphModels(
    ReaderPaginationRequest request,
  ) {
    final provided = request.paragraphModels;
    if (provided != null && provided.isNotEmpty) {
      return List<ReaderPaginationParagraph>.unmodifiable(provided);
    }
    final indentPrefix = _indentPrefix(request.spec.paragraphIndent);
    return List<ReaderPaginationParagraph>.unmodifiable(
      request.paragraphs.map(
        (paragraph) => ReaderPaginationParagraph(
          text: paragraph,
          paragraphStyle: request.paragraphStyle,
          textAlign: request.textAlign,
          firstLinePrefix: indentPrefix,
          spacingAfter: request.spec.paragraphSpacing,
        ),
      ),
    );
  }

  static String _indentPrefix(double paragraphIndent) {
    final indentCount = paragraphIndent.round();
    if (indentCount <= 0) {
      return '';
    }
    return '　' * indentCount;
  }

  static double _resolveImagePlaceholderHeight(
    ReaderBlockPaginationRequest request,
  ) {
    final aspectRatio =
        request.imagePlaceholderAspectRatio <= 0
            ? 3 / 4
            : request.imagePlaceholderAspectRatio;
    final width = request.spec.contentWidth;
    final height = width / aspectRatio;
    return height.clamp(80.0, request.spec.contentHeight).toDouble();
  }
}

const Object _readerPaginationUnset = Object();
