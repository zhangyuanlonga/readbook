import '../../../domain/entities/chapter.dart';

class ReaderChapterLoadRequest {
  const ReaderChapterLoadRequest({
    required this.sourceId,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
  });

  final String sourceId;
  final String chapterId;
  final String chapterUrl;
  final String? chapterTitle;
}

class ReaderChapterLoadPlanner {
  const ReaderChapterLoadPlanner();

  ReaderChapterLoadRequest? resolveLoadRequest({
    required String? sourceIdOverride,
    required String? chapterIdOverride,
    required String? chapterUrlOverride,
    required String? chapterTitleOverride,
    required String? currentSourceId,
    required String currentChapterId,
    required String? currentChapterUrl,
    required String? currentChapterTitle,
  }) {
    final sourceId = (sourceIdOverride ?? currentSourceId ?? '').trim();
    final chapterUrl = (chapterUrlOverride ?? currentChapterUrl ?? '').trim();
    if (sourceId.isEmpty || chapterUrl.isEmpty) {
      return null;
    }
    return ReaderChapterLoadRequest(
      sourceId: sourceId,
      chapterId: (chapterIdOverride ?? currentChapterId).trim(),
      chapterUrl: chapterUrl,
      chapterTitle: chapterTitleOverride ?? currentChapterTitle,
    );
  }

  int? resolveFetchChapterIndex({
    required int? chapterIndexOverride,
    required int? currentChapterIndex,
    required List<Chapter> chapters,
    required String chapterUrl,
  }) {
    final resolvedIndex =
        chapterIndexOverride ??
        currentChapterIndex ??
        chapters.indexWhere((chapter) => chapter.chapterUrl == chapterUrl);
    return resolvedIndex >= 0 ? resolvedIndex : null;
  }

  int resolveContinuousChapterIndex({
    required int? chapterIndex,
    required List<Chapter> chapters,
    required String chapterId,
    required String chapterUrl,
  }) {
    return chapterIndex ??
        chapters.indexWhere(
          (item) =>
              item.id == chapterId ||
              item.chapterUrl.trim() == chapterUrl.trim(),
        );
  }

  bool canPrepaginate({
    required bool isPagedTextReaderEnabled,
    required bool hasImages,
    required String content,
    required double? maxWidth,
    required double? maxHeight,
  }) {
    return isPagedTextReaderEnabled &&
        !hasImages &&
        content.trim().isNotEmpty &&
        maxWidth != null &&
        maxHeight != null &&
        maxWidth >= 20 &&
        maxHeight >= 40;
  }

  int resolvePageIndexByRatio({
    required double targetRatio,
    required int pageCount,
  }) {
    if (pageCount <= 1) {
      return 0;
    }
    return (targetRatio.clamp(0.0, 1.0) * pageCount).floor().clamp(
      0,
      pageCount - 1,
    );
  }

  String? resolveChapterTitleAfterLoad({
    required bool commitChapterIdentity,
    required String? loadedDisplayChapterTitle,
    required String? targetChapterTitle,
    required String? currentChapterTitle,
  }) {
    final displayTitle = loadedDisplayChapterTitle?.trim();
    final hasDisplayTitle = displayTitle?.isNotEmpty == true;
    if (commitChapterIdentity) {
      return hasDisplayTitle ? displayTitle : targetChapterTitle;
    }
    if (hasDisplayTitle) {
      return displayTitle;
    }
    return currentChapterTitle;
  }
}
