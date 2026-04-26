import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_logical_position.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_jump_facade.dart';
import '../application/reader_navigation_entry_resolver.dart';
import 'reader_catalog_sheet.dart';

typedef ReaderNavigationJumpToChapter =
    Future<void> Function(
      int chapterIndex, {
      double? initialScrollRatio,
      ReaderLogicalPosition? initialLogicalPosition,
    });

typedef ReaderNavigationRestoreCurrent =
    Future<void> Function({
      double? scrollRatio,
      ReaderLogicalPosition? logicalPosition,
    });

class ReaderNavigationPresentationPlan {
  const ReaderNavigationPresentationPlan._({
    this.request,
    this.message,
    this.resumeAutoReadOnRestore = false,
  });

  const ReaderNavigationPresentationPlan.execute(
    ReaderNavigationRequest request, {
    bool resumeAutoReadOnRestore = false,
  }) : this._(
         request: request,
         resumeAutoReadOnRestore: resumeAutoReadOnRestore,
       );

  const ReaderNavigationPresentationPlan.message(String message)
    : this._(message: message);

  final ReaderNavigationRequest? request;
  final String? message;
  final bool resumeAutoReadOnRestore;

  bool get hasRequest => request != null;
}

class ReaderMangaPositionPresentation {
  const ReaderMangaPositionPresentation({
    required this.initialRatio,
    required this.chapterLabel,
    required this.progressLabel,
    required this.totalImageCount,
    required this.isPagedMode,
  });

  final double initialRatio;
  final String chapterLabel;
  final String progressLabel;
  final int totalImageCount;
  final bool isPagedMode;
}

class ReaderNavigationExecutionSnapshot {
  const ReaderNavigationExecutionSnapshot({
    required this.chapterContent,
    required this.document,
    required this.currentChapterIndex,
    required this.isPagedTextReaderEnabled,
    required this.currentPageIndex,
  });

  final String chapterContent;
  final ReaderDocument document;
  final int? currentChapterIndex;
  final bool isPagedTextReaderEnabled;
  final int currentPageIndex;
}

class ReaderNavigationExecutionDelegate {
  const ReaderNavigationExecutionDelegate({
    required this.jumpToChapter,
    required this.restoreCurrent,
    required this.scheduleAutoReadResume,
    required this.scheduleProgressSave,
    required this.showMessage,
    this.shouldContinue = _defaultShouldContinue,
  });

  final ReaderNavigationJumpToChapter jumpToChapter;
  final ReaderNavigationRestoreCurrent restoreCurrent;
  final void Function() scheduleAutoReadResume;
  final void Function() scheduleProgressSave;
  final void Function(String message) showMessage;
  final bool Function() shouldContinue;

  static bool _defaultShouldContinue() => true;
}

class ReaderNavigationPresenter {
  const ReaderNavigationPresenter({
    ReaderNavigationEntryResolver navigationEntryResolver =
        const ReaderNavigationEntryResolver(),
    ReaderJumpFacade jumpFacade = const ReaderJumpFacade(),
  }) : _navigationEntryResolver = navigationEntryResolver,
       _jumpFacade = jumpFacade;

  final ReaderNavigationEntryResolver _navigationEntryResolver;
  final ReaderJumpFacade _jumpFacade;

  ReaderNavigationPresentationPlan resolveCatalogResult({
    required ReaderCatalogSheetResult? result,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    final bookmark = result?.bookmark;
    if (bookmark != null) {
      return resolveBookmarkSelection(bookmark: bookmark, chapters: chapters);
    }

    final selection = result?.selection;
    return ReaderNavigationPresentationPlan.execute(
      _navigationEntryResolver.resolveCatalogSelection(
        selectedIndex: selection?.chapterIndex,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        selectedScrollRatio: selection?.scrollRatio,
        selectedLogicalPosition: selection?.logicalPosition,
      ),
      resumeAutoReadOnRestore: true,
    );
  }

  ReaderNavigationPresentationPlan resolveBookmarkSelection({
    required Bookmark bookmark,
    required List<Chapter> chapters,
  }) {
    final request = _navigationEntryResolver.resolveBookmarkSelection(
      bookmark: bookmark,
      chapters: chapters,
    );
    if (request == null) {
      return const ReaderNavigationPresentationPlan.message('未找到灵感所在章节。');
    }
    return ReaderNavigationPresentationPlan.execute(request);
  }

  ReaderNavigationRequest resolveMangaProgressSelection({
    required double scrollRatio,
  }) {
    return _navigationEntryResolver.resolveProgressSelection(
      scrollRatio: scrollRatio,
    );
  }

  ReaderMangaPositionPresentation? resolveMangaPositionPresentation({
    required bool isMangaViewport,
    required int totalImageCount,
    required bool hasScrollClients,
    required bool isPagedMode,
    required double currentScrollRatio,
    required int currentPageIndex,
  }) {
    if (!isMangaViewport) {
      return null;
    }
    if (totalImageCount <= 1 && !hasScrollClients) {
      return null;
    }

    final progressPercent = (currentScrollRatio.clamp(0.0, 1.0) * 100).round();
    final safeTotal = totalImageCount <= 0 ? 1 : totalImageCount;
    final chapterLabel =
        isPagedMode
            ? '第 ${(currentPageIndex + 1).clamp(1, safeTotal)} / $safeTotal 张'
            : '长图进度定位';
    return ReaderMangaPositionPresentation(
      initialRatio: currentScrollRatio.clamp(0.0, 1.0),
      chapterLabel: chapterLabel,
      progressLabel: '$progressPercent%',
      totalImageCount: totalImageCount,
      isPagedMode: isPagedMode,
    );
  }

  int? resolveCatalogSearchEntryTargetIndex({
    required ReaderCatalogSearchEntry entry,
    required List<Chapter> chapters,
  }) {
    final request = _navigationEntryResolver.resolveCatalogSearchEntry(
      entry: ReaderCatalogSearchEntryAdapter(
        chapterIndex: entry.chapterIndex,
        targetChapterIndex: entry.targetChapterIndex,
        isVolume: entry.isVolume,
        isContent: entry.isContent,
      ),
      chapters: chapters,
    );
    return request?.targetChapterIndex;
  }

  Future<void> executeRequest({
    required ReaderNavigationRequest request,
    required ReaderNavigationExecutionSnapshot snapshot,
    required ReaderNavigationExecutionDelegate delegate,
    bool resumeAutoReadOnRestore = false,
  }) async {
    switch (request.type) {
      case ReaderNavigationRequestType.resumeAutoRead:
        if (resumeAutoReadOnRestore) {
          delegate.scheduleAutoReadResume();
        }
        return;
      case ReaderNavigationRequestType.restoreCurrent:
        await delegate.restoreCurrent(
          scrollRatio: request.initialScrollRatio,
          logicalPosition: request.initialLogicalPosition,
        );
        if (resumeAutoReadOnRestore) {
          delegate.scheduleAutoReadResume();
        } else {
          delegate.scheduleProgressSave();
        }
        return;
      case ReaderNavigationRequestType.jumpChapter:
        await delegate.jumpToChapter(
          request.targetChapterIndex!,
          initialScrollRatio: request.initialScrollRatio,
          initialLogicalPosition: request.initialLogicalPosition,
        );
        return;
      case ReaderNavigationRequestType.jumpBookmark:
        await delegate.jumpToChapter(
          request.targetChapterIndex!,
          initialScrollRatio: 0,
        );
        if (!delegate.shouldContinue()) {
          return;
        }
        if (snapshot.chapterContent.trim().isEmpty) {
          delegate.showMessage('章节内容为空，无法定位灵感。');
          return;
        }
        final restorePlan = _jumpFacade.resolveBookmarkRestorePlan(
          bookmark: request.bookmark!,
          document: snapshot.document,
          currentChapterIndex: snapshot.currentChapterIndex,
          isPagedTextReaderEnabled: snapshot.isPagedTextReaderEnabled,
          currentPageIndex: snapshot.currentPageIndex,
          chapterContent: snapshot.chapterContent,
        );
        if (restorePlan.logicalPosition != null) {
          await executeRequest(
            request: ReaderNavigationRequest.restoreCurrent(
              logicalPosition: restorePlan.logicalPosition,
            ),
            snapshot: snapshot,
            delegate: delegate,
          );
          return;
        }
        if (restorePlan.fallbackRatio != null) {
          await executeRequest(
            request: ReaderNavigationRequest.restoreCurrent(
              scrollRatio: restorePlan.fallbackRatio,
            ),
            snapshot: snapshot,
            delegate: delegate,
          );
          return;
        }
        delegate.showMessage('未找到灵感位置，已定位到章节开头。');
        return;
    }
  }
}
