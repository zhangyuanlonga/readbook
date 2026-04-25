import 'dart:async';

import 'package:flutter/painting.dart';

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
    this.shouldAbort,
    this.textDirection = TextDirection.ltr,
    this.textAlign = TextAlign.start,
  });

  final List<String> paragraphs;
  final ReaderPaginationSpec spec;
  final TextStyle paragraphStyle;
  final List<ReaderPaginationParagraph>? paragraphModels;
  final TextScaler textScaler;
  final bool Function()? shouldAbort;
  final TextDirection textDirection;
  final TextAlign textAlign;
}

class ReaderPaginationParagraph {
  const ReaderPaginationParagraph({
    required this.text,
    required this.paragraphStyle,
    this.firstLinePrefix = '',
    this.spacingAfter = 0,
  });

  final String text;
  final TextStyle paragraphStyle;
  final String firstLinePrefix;
  final double spacingAfter;
}

class ReaderPaginationResult {
  const ReaderPaginationResult({required this.paragraphs, required this.pages});

  final List<String> paragraphs;
  final List<List<ReaderPagedSlice>> pages;
}

class ReaderPaginationEngine {
  const ReaderPaginationEngine();

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
      if (availableHeight <= 0) {
        return 0;
      }

      final prefix = start == 0 ? paragraph.firstLinePrefix : '';
      final remaining = paragraph.text.substring(start);
      final displayText = '$prefix$remaining';

      painter.text = TextSpan(
        text: displayText,
        style: paragraph.paragraphStyle,
      );
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= availableHeight) {
        return remaining.length;
      }

      final lines = painter.computeLineMetrics();
      double? lastLineBottom;

      for (final line in lines) {
        final bottom = line.baseline + line.descent;
        if (bottom <= availableHeight) {
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
                  (lastLineBottom - 0.1).clamp(0.0, availableHeight),
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

        if (currentPage.isNotEmpty) {
          if (remainingHeight <= lastSpacingAfter) {
            pages.add(currentPage);
            currentPage = <ReaderPagedSlice>[];
            remainingHeight = maxHeight;
            lastSpacingAfter = 0.0;
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
            ),
          );
          lastSpacingAfter = paragraph.spacingAfter;
          offset = end;
          pages.add(currentPage);
          currentPage = <ReaderPagedSlice>[];
          remainingHeight = maxHeight;
          lastSpacingAfter = 0.0;
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
          ),
        );
        lastSpacingAfter = paragraph.spacingAfter;

        offset = end;

        if (offset < paragraph.text.length) {
          pages.add(currentPage);
          currentPage = <ReaderPagedSlice>[];
          remainingHeight = maxHeight;
          lastSpacingAfter = 0.0;
        }
      }

      if (paragraphIndex % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
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
}

const Object _readerPaginationUnset = Object();
