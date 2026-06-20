import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_logical_position.dart';
import 'reader_jump_facade.dart';

enum ReaderNavigationRequestType {
  resumeAutoRead,
  restoreCurrent,
  jumpChapter,
  jumpBookmark,
}

class ReaderNavigationRequest {
  const ReaderNavigationRequest._({
    required this.type,
    this.targetChapterIndex,
    this.initialScrollRatio,
    this.initialLogicalPosition,
    this.bookmark,
  });

  const ReaderNavigationRequest.resumeAutoRead()
    : this._(type: ReaderNavigationRequestType.resumeAutoRead);

  const ReaderNavigationRequest.restoreCurrent({
    double? scrollRatio,
    ReaderLogicalPosition? logicalPosition,
  }) : this._(
         type: ReaderNavigationRequestType.restoreCurrent,
         initialScrollRatio: scrollRatio,
         initialLogicalPosition: logicalPosition,
       );

  const ReaderNavigationRequest.jumpChapter({
    required int targetChapterIndex,
    double? initialScrollRatio,
    ReaderLogicalPosition? initialLogicalPosition,
  }) : this._(
         type: ReaderNavigationRequestType.jumpChapter,
         targetChapterIndex: targetChapterIndex,
         initialScrollRatio: initialScrollRatio,
         initialLogicalPosition: initialLogicalPosition,
       );

  const ReaderNavigationRequest.jumpBookmark({
    required Bookmark bookmark,
    required int targetChapterIndex,
  }) : this._(
         type: ReaderNavigationRequestType.jumpBookmark,
         targetChapterIndex: targetChapterIndex,
         bookmark: bookmark,
       );

  final ReaderNavigationRequestType type;
  final int? targetChapterIndex;
  final double? initialScrollRatio;
  final ReaderLogicalPosition? initialLogicalPosition;
  final Bookmark? bookmark;
}

class ReaderNavigationEntryResolver {
  const ReaderNavigationEntryResolver({
    ReaderJumpFacade jumpFacade = const ReaderJumpFacade(),
  }) : _jumpFacade = jumpFacade;

  final ReaderJumpFacade _jumpFacade;

  ReaderNavigationRequest resolveCatalogSelection({
    required int? selectedIndex,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    required double? selectedScrollRatio,
    required ReaderLogicalPosition? selectedLogicalPosition,
  }) {
    final decision = _jumpFacade.resolveCatalogSelection(
      selectedIndex: selectedIndex,
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
      selectedScrollRatio: selectedScrollRatio,
      selectedLogicalPosition: selectedLogicalPosition,
    );
    return switch (decision.type) {
      ReaderCatalogSelectionDecisionType.resumeAutoRead =>
        const ReaderNavigationRequest.resumeAutoRead(),
      ReaderCatalogSelectionDecisionType.restoreCurrent =>
        ReaderNavigationRequest.restoreCurrent(
          scrollRatio: decision.initialScrollRatio,
          logicalPosition: decision.initialLogicalPosition,
        ),
      ReaderCatalogSelectionDecisionType.jumpChapter =>
        ReaderNavigationRequest.jumpChapter(
          targetChapterIndex: decision.targetChapterIndex!,
          initialScrollRatio: decision.initialScrollRatio,
          initialLogicalPosition: decision.initialLogicalPosition,
        ),
    };
  }

  ReaderNavigationRequest resolveProgressSelection({
    required double scrollRatio,
  }) {
    return ReaderNavigationRequest.restoreCurrent(scrollRatio: scrollRatio);
  }

  ReaderNavigationRequest? resolveCatalogSearchEntry({
    required ReaderCatalogSearchEntryAdapter entry,
    required List<Chapter> chapters,
  }) {
    final candidateIndex =
        entry.isContent
            ? entry.chapterIndex
            : (entry.targetChapterIndex ??
                (entry.isVolume ? null : entry.chapterIndex));
    final targetIndex = _jumpFacade.resolveReadableChapterTargetIndex(
      chapters: chapters,
      chapterIndex: candidateIndex,
      preferForward: true,
    );
    if (targetIndex == null) {
      return null;
    }
    return ReaderNavigationRequest.jumpChapter(
      targetChapterIndex: targetIndex,
      initialScrollRatio: entry.isContent ? entry.scrollRatio : null,
      initialLogicalPosition: entry.isContent ? entry.logicalPosition : null,
    );
  }

  int? resolveBookmarkChapterIndex({
    required Bookmark bookmark,
    required List<Chapter> chapters,
  }) {
    return _jumpFacade.resolveBookmarkChapterIndex(
      bookmark: bookmark,
      chapters: chapters,
    );
  }

  ReaderNavigationRequest? resolveBookmarkSelection({
    required Bookmark bookmark,
    required List<Chapter> chapters,
  }) {
    final targetIndex = resolveBookmarkChapterIndex(
      bookmark: bookmark,
      chapters: chapters,
    );
    if (targetIndex == null) {
      return null;
    }
    return ReaderNavigationRequest.jumpBookmark(
      bookmark: bookmark,
      targetChapterIndex: targetIndex,
    );
  }
}

class ReaderCatalogSearchEntryAdapter {
  const ReaderCatalogSearchEntryAdapter({
    required this.chapterIndex,
    required this.targetChapterIndex,
    required this.isVolume,
    required this.isContent,
    this.scrollRatio,
    this.logicalPosition,
  });

  final int? chapterIndex;
  final int? targetChapterIndex;
  final bool isVolume;
  final bool isContent;
  final double? scrollRatio;
  final ReaderLogicalPosition? logicalPosition;
}
