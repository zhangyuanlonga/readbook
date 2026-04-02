import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import 'reader_chapter_navigation.dart';
import 'reader_logical_position.dart';

enum ReaderCatalogSelectionDecisionType {
  resumeAutoRead,
  restoreCurrent,
  jumpChapter,
}

class ReaderCatalogSelectionDecision {
  const ReaderCatalogSelectionDecision._({
    required this.type,
    this.targetChapterIndex,
    this.initialScrollRatio,
    this.initialLogicalPosition,
  });

  const ReaderCatalogSelectionDecision.resumeAutoRead()
    : this._(type: ReaderCatalogSelectionDecisionType.resumeAutoRead);

  const ReaderCatalogSelectionDecision.restoreCurrent({
    double? scrollRatio,
    ReaderLogicalPosition? logicalPosition,
  }) : this._(
         type: ReaderCatalogSelectionDecisionType.restoreCurrent,
         initialScrollRatio: scrollRatio,
         initialLogicalPosition: logicalPosition,
       );

  const ReaderCatalogSelectionDecision.jumpChapter({
    required int targetChapterIndex,
    double? initialScrollRatio,
    ReaderLogicalPosition? initialLogicalPosition,
  }) : this._(
         type: ReaderCatalogSelectionDecisionType.jumpChapter,
         targetChapterIndex: targetChapterIndex,
         initialScrollRatio: initialScrollRatio,
         initialLogicalPosition: initialLogicalPosition,
       );

  final ReaderCatalogSelectionDecisionType type;
  final int? targetChapterIndex;
  final double? initialScrollRatio;
  final ReaderLogicalPosition? initialLogicalPosition;
}

class ReaderBookmarkRestorePlan {
  const ReaderBookmarkRestorePlan({this.logicalPosition, this.fallbackRatio});

  final ReaderLogicalPosition? logicalPosition;
  final double? fallbackRatio;
}

class ReaderJumpFacade {
  const ReaderJumpFacade({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;

  int? resolveReadableChapterTargetIndex({
    required List<Chapter> chapters,
    required int? chapterIndex,
    bool preferForward = true,
  }) {
    if (chapterIndex == null ||
        chapterIndex < 0 ||
        chapterIndex >= chapters.length) {
      return null;
    }
    if (_chapterNavigation.isReadableChapter(chapters[chapterIndex])) {
      return chapterIndex;
    }
    return _chapterNavigation.resolveNearestReadableChapterIndex(
      chapters,
      chapterIndex,
      preferForward: preferForward,
    );
  }

  int? resolveBookmarkChapterIndex({
    required Bookmark bookmark,
    required List<Chapter> chapters,
  }) {
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      for (var index = 0; index < chapters.length; index++) {
        if (chapters[index].id == chapterId) {
          return resolveReadableChapterTargetIndex(
            chapters: chapters,
            chapterIndex: index,
            preferForward: true,
          );
        }
      }
    }

    return resolveReadableChapterTargetIndex(
      chapters: chapters,
      chapterIndex: bookmark.chapterIndex,
      preferForward: true,
    );
  }

  double? resolveBookmarkRestoreRatio({
    required Bookmark bookmark,
    required String chapterContent,
  }) {
    return _resolveBookmarkScrollRatio(bookmark, chapterContent) ??
        _findSnippetScrollRatio(bookmark.snippet, chapterContent);
  }

  ReaderLogicalPosition? resolveBookmarkLogicalPosition({
    required Bookmark bookmark,
    required ReaderDocument document,
    required int? currentChapterIndex,
    required bool isPagedTextReaderEnabled,
    required int currentPageIndex,
    required String chapterContent,
  }) {
    if (currentChapterIndex == null || document.isEmpty) {
      return null;
    }

    final ratio = resolveBookmarkRestoreRatio(
      bookmark: bookmark,
      chapterContent: chapterContent,
    );
    if (ratio == null) {
      return null;
    }

    return ReaderLogicalPosition.fromDocument(
      document: document,
      chapterIndex: currentChapterIndex,
      chapterPositionRatio: ratio,
      pageIndex: isPagedTextReaderEnabled ? currentPageIndex : null,
    );
  }

  ReaderBookmarkRestorePlan resolveBookmarkRestorePlan({
    required Bookmark bookmark,
    required ReaderDocument document,
    required int? currentChapterIndex,
    required bool isPagedTextReaderEnabled,
    required int currentPageIndex,
    required String chapterContent,
  }) {
    final logicalPosition = resolveBookmarkLogicalPosition(
      bookmark: bookmark,
      document: document,
      currentChapterIndex: currentChapterIndex,
      isPagedTextReaderEnabled: isPagedTextReaderEnabled,
      currentPageIndex: currentPageIndex,
      chapterContent: chapterContent,
    );
    if (logicalPosition != null) {
      return ReaderBookmarkRestorePlan(logicalPosition: logicalPosition);
    }
    return ReaderBookmarkRestorePlan(
      fallbackRatio: resolveBookmarkRestoreRatio(
        bookmark: bookmark,
        chapterContent: chapterContent,
      ),
    );
  }

  ReaderCatalogSelectionDecision resolveCatalogSelection({
    required int? selectedIndex,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    required double? selectedScrollRatio,
    required ReaderLogicalPosition? selectedLogicalPosition,
  }) {
    final targetChapterIndex = resolveReadableChapterTargetIndex(
      chapters: chapters,
      chapterIndex: selectedIndex,
      preferForward: true,
    );
    if (targetChapterIndex == null) {
      return const ReaderCatalogSelectionDecision.resumeAutoRead();
    }

    if (targetChapterIndex == currentChapterIndex) {
      if (selectedLogicalPosition != null || selectedScrollRatio != null) {
        return ReaderCatalogSelectionDecision.restoreCurrent(
          scrollRatio: selectedScrollRatio,
          logicalPosition: selectedLogicalPosition,
        );
      }
      return const ReaderCatalogSelectionDecision.resumeAutoRead();
    }

    return ReaderCatalogSelectionDecision.jumpChapter(
      targetChapterIndex: targetChapterIndex,
      initialScrollRatio: selectedScrollRatio,
      initialLogicalPosition: selectedLogicalPosition,
    );
  }

  double? _resolveBookmarkScrollRatio(
    Bookmark bookmark,
    String chapterContent,
  ) {
    final length = chapterContent.length;
    if (length <= 0) {
      return null;
    }
    final offset = bookmark.startOffset;
    if (offset < 0 || offset > length) {
      return null;
    }
    return (offset / length).clamp(0.0, 1.0);
  }

  double? _findSnippetScrollRatio(String snippet, String chapterContent) {
    final normalized = snippet.trim();
    if (chapterContent.isEmpty || normalized.isEmpty) {
      return null;
    }
    final index = chapterContent.indexOf(normalized);
    if (index < 0) {
      return null;
    }
    return (index / chapterContent.length).clamp(0.0, 1.0);
  }
}
