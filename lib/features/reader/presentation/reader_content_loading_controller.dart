import 'dart:math' as math;

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_logical_position.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/chapter_content_service.dart';
import '../application/reader_chapter_navigation.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_pagination_engine.dart';
import '../application/reader_pagination_models.dart';

class ReaderResolvedContentCacheKey {
  const ReaderResolvedContentCacheKey({
    required this.content,
    required this.imageUrls,
    required this.document,
  });

  final String content;
  final List<String> imageUrls;
  final ReaderDocument? document;
}

class ReaderBootstrapProgressResolution {
  const ReaderBootstrapProgressResolution({
    required this.matchedProgress,
    required this.remainingProgress,
  });

  final ReadingProgress? matchedProgress;
  final ReadingProgress? remainingProgress;

  bool get hasMatch => matchedProgress != null;
}

class ReaderResolvedChapterContent {
  const ReaderResolvedChapterContent({
    required this.document,
    required this.content,
    required this.chapterImageUrls,
    required this.imageHeaders,
    required this.paragraphs,
    required this.renderItems,
    required this.renderTextItemsByParagraph,
    required this.pagedPages,
    required this.currentPageIndex,
    required this.paginationState,
  });

  final ReaderDocument document;
  final String content;
  final List<String> chapterImageUrls;
  final Map<String, String> imageHeaders;
  final List<String> paragraphs;
  final List<ReaderRenderBlockItem> renderItems;
  final Map<int, ReaderRenderTextItem> renderTextItemsByParagraph;
  final List<List<ReaderPagedSlice>> pagedPages;
  final int currentPageIndex;
  final ReaderPaginationSessionState paginationState;
}

class ReaderContinuousTextChapter {
  const ReaderContinuousTextChapter({
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.displayTitle,
    required this.chapterIndex,
    required this.content,
    required this.document,
    required this.paragraphs,
    required this.isCached,
  });

  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final String displayTitle;
  final int chapterIndex;
  final String content;
  final ReaderDocument document;
  final List<String> paragraphs;
  final bool isCached;
}

class ReaderContinuousTextChapterLayout {
  const ReaderContinuousTextChapterLayout({
    required this.startOffset,
    required this.endOffset,
  });

  final double startOffset;
  final double endOffset;
}

class ReaderContinuousTextViewportMetrics {
  const ReaderContinuousTextViewportMetrics({
    required this.pixels,
    required this.viewportDimension,
    required this.maxScrollExtent,
  });

  final double pixels;
  final double viewportDimension;
  final double maxScrollExtent;
}

class ReaderContinuousTextNeighborPlan {
  const ReaderContinuousTextNeighborPlan({
    this.forwardChapterIndex,
    this.backwardChapterIndex,
  });

  final int? forwardChapterIndex;
  final int? backwardChapterIndex;

  bool get shouldLoadForward => forwardChapterIndex != null;
  bool get shouldLoadBackward => backwardChapterIndex != null;
  bool get hasWork => shouldLoadForward || shouldLoadBackward;
}

class ReaderContinuousTextActivation {
  const ReaderContinuousTextActivation({
    required this.chapterIndex,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.isCached,
    required this.initialRatio,
    required this.contentState,
  });

  final int chapterIndex;
  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final bool isCached;
  final double initialRatio;
  final ReaderResolvedChapterContent contentState;
}

class ReaderContentLoadingController {
  const ReaderContentLoadingController({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;
  static final Map<int, ReaderResolvedChapterContent> _resolvedContentCache =
      <int, ReaderResolvedChapterContent>{};

  ReaderBootstrapProgressResolution resolveBootstrapProgressForCurrentChapter({
    required ReadingProgress? bootstrapProgress,
    required String currentChapterId,
    required String? currentChapterUrl,
    bool consume = false,
  }) {
    final progress = bootstrapProgress;
    if (progress == null) {
      return const ReaderBootstrapProgressResolution(
        matchedProgress: null,
        remainingProgress: null,
      );
    }

    final normalizedChapterId = currentChapterId.trim();
    final normalizedChapterUrl = (currentChapterUrl ?? '').trim();
    final matchesChapter =
        progress.chapterId == normalizedChapterId ||
        progress.chapterUrl == normalizedChapterUrl;
    if (!matchesChapter) {
      return ReaderBootstrapProgressResolution(
        matchedProgress: null,
        remainingProgress: progress,
      );
    }

    return ReaderBootstrapProgressResolution(
      matchedProgress: progress,
      remainingProgress: consume ? null : progress,
    );
  }

  double resolveDocumentRestoreRatio({
    ReaderDocument? document,
    required ReaderDocument fallbackDocument,
    ReaderLogicalPosition? logicalPosition,
    ReadingProgress? progress,
    double fallback = 0,
  }) {
    final effectiveDocument = document ?? fallbackDocument;
    final effectivePosition = logicalPosition ?? progress?.logicalPosition;
    if (effectivePosition != null && !effectiveDocument.isEmpty) {
      return effectivePosition.approximateRatio(effectiveDocument);
    }

    final ratio = progress?.chapterPositionRatio ?? fallback;
    return ratio.clamp(0.0, 1.0);
  }

  ReaderResolvedChapterContent buildResolvedContent({
    required String content,
    List<String> imageUrls = const <String>[],
    Map<String, String> imageHeaders = const <String, String>{},
    ReaderDocument? document,
    List<String>? precomputedParagraphs,
    List<List<ReaderPagedSlice>>? precomputedPagedPages,
    int? precomputedCurrentPageIndex,
    String? precomputedPaginationSignature,
  }) {
    final canReuseResolvedContent =
        precomputedParagraphs == null &&
        precomputedPagedPages == null &&
        precomputedCurrentPageIndex == null &&
        precomputedPaginationSignature == null;
    final cacheKey =
        canReuseResolvedContent
            ? Object.hash(content, Object.hashAll(imageUrls), document)
            : null;
    if (cacheKey != null) {
      final cached = _resolvedContentCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }
    final resolvedDocument =
        document ??
        ReaderDocument.fromContent(content: content, imageUrls: imageUrls);
    final resolvedContent =
        resolvedDocument.isPureImageDocument
            ? ''
            : resolvedDocument.compatibilityContent;
    final resolvedParagraphs = List<String>.unmodifiable(
      precomputedParagraphs ?? resolvedDocument.paragraphs,
    );
    final resolvedImageUrls = List<String>.unmodifiable(
      resolvedDocument.isPureImageDocument
          ? resolvedDocument.imageUrls
          : const <String>[],
    );
    final resolvedRenderItems = buildReaderRenderBlockItems(resolvedDocument);
    final resolvedRenderTextItemsByParagraph = buildReaderRenderTextItemIndex(
      resolvedRenderItems,
    );

    final normalizedPagedPages = precomputedPagedPages
        ?.map((page) => List<ReaderPagedSlice>.unmodifiable(page))
        .toList(growable: false);
    final hasPrecomputedPages =
        normalizedPagedPages != null && normalizedPagedPages.isNotEmpty;

    final resolved = ReaderResolvedChapterContent(
      document: resolvedDocument,
      content: resolvedContent,
      chapterImageUrls: resolvedImageUrls,
      imageHeaders: Map<String, String>.unmodifiable(imageHeaders),
      paragraphs: resolvedParagraphs,
      renderItems: resolvedRenderItems,
      renderTextItemsByParagraph: resolvedRenderTextItemsByParagraph,
      pagedPages:
          hasPrecomputedPages
              ? List<List<ReaderPagedSlice>>.unmodifiable(normalizedPagedPages)
              : const <List<ReaderPagedSlice>>[],
      currentPageIndex:
          hasPrecomputedPages ? (precomputedCurrentPageIndex ?? 0) : 0,
      paginationState:
          hasPrecomputedPages
              ? ReaderPaginationSessionState(
                signature: precomputedPaginationSignature,
              )
              : const ReaderPaginationSessionState(),
    );
    if (cacheKey != null) {
      _resolvedContentCache[cacheKey] = resolved;
    }
    return resolved;
  }

  bool shouldBuildContinuousTextFlowFor({
    required bool shouldUseContinuousTextFlow,
    required ChapterContentResult result,
  }) {
    return shouldUseContinuousTextFlow &&
        !result.isImageContent &&
        result.document.paragraphs.isNotEmpty;
  }

  ReaderContinuousTextChapter buildContinuousTextChapterFromResult({
    required Chapter chapter,
    required int chapterIndex,
    required ChapterContentResult result,
    required bool isCached,
  }) {
    final displayTitle =
        result.displayChapterTitle?.trim().isNotEmpty == true
            ? result.displayChapterTitle!.trim()
            : chapter.title.trim();
    final paragraphs = result.document.paragraphs;
    final effectiveParagraphs =
        paragraphs.isEmpty && result.content.trim().isNotEmpty
            ? <String>[result.content]
            : paragraphs;

    return ReaderContinuousTextChapter(
      chapterId: chapter.id,
      chapterUrl: chapter.chapterUrl.trim(),
      chapterTitle: chapter.title.trim(),
      displayTitle: displayTitle,
      chapterIndex: chapterIndex,
      content: result.content,
      document: result.document,
      paragraphs: List<String>.unmodifiable(effectiveParagraphs),
      isCached: isCached,
    );
  }

  ReaderContinuousTextChapter buildCurrentContinuousTextChapter({
    required Chapter chapter,
    required int chapterIndex,
    required String currentChapterId,
    required String? currentChapterUrl,
    required String? currentChapterTitle,
    required ReaderResolvedChapterContent contentState,
    required bool isCurrentChapterCached,
  }) {
    final effectiveParagraphs =
        contentState.paragraphs.isEmpty
            ? <String>[contentState.content]
            : contentState.paragraphs;

    return ReaderContinuousTextChapter(
      chapterId: currentChapterId,
      chapterUrl: (currentChapterUrl ?? '').trim(),
      chapterTitle: chapter.title.trim(),
      displayTitle: (currentChapterTitle ?? chapter.title).trim(),
      chapterIndex: chapterIndex,
      content: contentState.content,
      document: contentState.document,
      paragraphs: List<String>.unmodifiable(effectiveParagraphs),
      isCached: isCurrentChapterCached,
    );
  }

  List<ReaderContinuousTextChapter> seedContinuousTextFlow({
    required bool shouldUseContinuousTextFlow,
    required bool isMangaChapter,
    required String currentContent,
    required int? currentChapterIndex,
    required List<Chapter> chapters,
    required String currentChapterId,
    required String? currentChapterUrl,
    required String? currentChapterTitle,
    required ReaderResolvedChapterContent contentState,
    required bool isCurrentChapterCached,
  }) {
    if (!shouldUseContinuousTextFlow ||
        isMangaChapter ||
        currentContent.trim().isEmpty ||
        currentChapterIndex == null ||
        currentChapterIndex < 0 ||
        currentChapterIndex >= chapters.length) {
      return const <ReaderContinuousTextChapter>[];
    }

    return <ReaderContinuousTextChapter>[
      buildCurrentContinuousTextChapter(
        chapter: chapters[currentChapterIndex],
        chapterIndex: currentChapterIndex,
        currentChapterId: currentChapterId,
        currentChapterUrl: currentChapterUrl,
        currentChapterTitle: currentChapterTitle,
        contentState: contentState,
        isCurrentChapterCached: isCurrentChapterCached,
      ),
    ];
  }

  ReaderContinuousTextNeighborPlan resolveNeighborPrefetchPlan({
    required bool shouldUseContinuousTextFlow,
    required bool hasScrollClients,
    required List<ReaderContinuousTextChapter> loadedChapters,
    required bool isScrollEdgeAdvancingChapter,
    required bool isAutoReadAdvancingChapter,
    required ReaderContinuousTextViewportMetrics viewport,
    required List<Chapter> chapters,
  }) {
    if (!shouldUseContinuousTextFlow ||
        !hasScrollClients ||
        loadedChapters.isEmpty ||
        isScrollEdgeAdvancingChapter ||
        isAutoReadAdvancingChapter) {
      return const ReaderContinuousTextNeighborPlan();
    }

    final prefetchBottomDistance = math.max(
      240.0,
      viewport.viewportDimension * 0.7,
    );
    final prefetchTopDistance = math.max(
      120.0,
      viewport.viewportDimension * 0.3,
    );
    final remainingBottom = viewport.maxScrollExtent - viewport.pixels;

    return ReaderContinuousTextNeighborPlan(
      forwardChapterIndex:
          remainingBottom <= prefetchBottomDistance
              ? resolveAdjacentContinuousTextChapterIndex(
                chapters: chapters,
                loadedChapters: loadedChapters,
                forward: true,
              )
              : null,
      backwardChapterIndex:
          viewport.pixels <= prefetchTopDistance
              ? resolveAdjacentContinuousTextChapterIndex(
                chapters: chapters,
                loadedChapters: loadedChapters,
                forward: false,
              )
              : null,
    );
  }

  int? resolveAdjacentContinuousTextChapterIndex({
    required List<Chapter> chapters,
    required List<ReaderContinuousTextChapter> loadedChapters,
    required bool forward,
  }) {
    if (loadedChapters.isEmpty) {
      return null;
    }

    final startIndex =
        forward
            ? loadedChapters.last.chapterIndex + 1
            : loadedChapters.first.chapterIndex - 1;
    final targetIndex = _chapterNavigation.findReadableChapterIndex(
      chapters,
      startIndex,
      forward: forward,
    );
    if (targetIndex == null) {
      return null;
    }

    final alreadyLoaded = loadedChapters.any(
      (item) => item.chapterIndex == targetIndex,
    );
    return alreadyLoaded ? null : targetIndex;
  }

  bool isContinuousTextChapterActive({
    required ReaderContinuousTextChapter chapter,
    required int? currentChapterIndex,
    required String currentChapterId,
    required String? currentChapterUrl,
  }) {
    if (currentChapterIndex != null &&
        chapter.chapterIndex == currentChapterIndex) {
      return true;
    }
    final chapterUrl = (currentChapterUrl ?? '').trim();
    if (chapterUrl.isNotEmpty && chapter.chapterUrl == chapterUrl) {
      return true;
    }
    return chapter.chapterId.trim() == currentChapterId.trim();
  }

  double resolveContinuousTextChapterScrollRatio({
    required ReaderContinuousTextChapterLayout layout,
    required ReaderContinuousTextViewportMetrics viewport,
  }) {
    final viewportExtent = viewport.viewportDimension;
    final available = (layout.endOffset - layout.startOffset - viewportExtent)
        .clamp(0.0, double.infinity);
    if (available <= 0) {
      if (viewport.pixels <= layout.startOffset) {
        return 0;
      }
      return 1;
    }

    final local = (viewport.pixels - layout.startOffset).clamp(0.0, available);
    return (local / available).clamp(0.0, 1.0);
  }

  ReaderContinuousTextChapter? resolveActiveContinuousTextChapter({
    required List<ReaderContinuousTextChapter> chapters,
    required Map<int, ReaderContinuousTextChapterLayout> layoutsByChapterIndex,
    required ReaderContinuousTextViewportMetrics viewport,
  }) {
    if (chapters.isEmpty) {
      return null;
    }

    final probeOffset = viewport.pixels + viewport.viewportDimension * 0.35;
    ReaderContinuousTextChapter? fallback;
    var fallbackDistance = double.infinity;

    for (final chapter in chapters) {
      final layout = layoutsByChapterIndex[chapter.chapterIndex];
      if (layout == null) {
        continue;
      }
      if (probeOffset >= layout.startOffset && probeOffset < layout.endOffset) {
        return chapter;
      }

      final distance =
          probeOffset < layout.startOffset
              ? layout.startOffset - probeOffset
              : probeOffset - layout.endOffset;
      if (distance < fallbackDistance) {
        fallbackDistance = distance;
        fallback = chapter;
      }
    }

    return fallback;
  }

  ReaderContinuousTextActivation? buildContinuousTextActivation({
    required ReaderContinuousTextChapter chapter,
    required int? currentChapterIndex,
    required String currentChapterId,
    required String? currentChapterUrl,
  }) {
    if (isContinuousTextChapterActive(
      chapter: chapter,
      currentChapterIndex: currentChapterIndex,
      currentChapterId: currentChapterId,
      currentChapterUrl: currentChapterUrl,
    )) {
      return null;
    }

    return ReaderContinuousTextActivation(
      chapterIndex: chapter.chapterIndex,
      chapterId: chapter.chapterId,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.displayTitle,
      isCached: chapter.isCached,
      initialRatio: 0,
      contentState: buildResolvedContent(
        content: chapter.content,
        document: chapter.document,
        precomputedParagraphs: chapter.paragraphs,
      ),
    );
  }

  ReaderContinuousTextActivation? buildContinuousTextActivationFromViewport({
    required ReaderContinuousTextChapter chapter,
    required int? currentChapterIndex,
    required String currentChapterId,
    required String? currentChapterUrl,
    required ReaderContinuousTextChapterLayout layout,
    required ReaderContinuousTextViewportMetrics viewport,
  }) {
    final activation = buildContinuousTextActivation(
      chapter: chapter,
      currentChapterIndex: currentChapterIndex,
      currentChapterId: currentChapterId,
      currentChapterUrl: currentChapterUrl,
    );
    if (activation == null) {
      return null;
    }

    return ReaderContinuousTextActivation(
      chapterIndex: activation.chapterIndex,
      chapterId: activation.chapterId,
      chapterUrl: activation.chapterUrl,
      chapterTitle: activation.chapterTitle,
      isCached: activation.isCached,
      initialRatio: resolveContinuousTextChapterScrollRatio(
        layout: layout,
        viewport: viewport,
      ),
      contentState: activation.contentState,
    );
  }
}
