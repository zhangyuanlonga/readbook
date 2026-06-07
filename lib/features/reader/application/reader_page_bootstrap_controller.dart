class ReaderPageBootstrapSeed {
  const ReaderPageBootstrapSeed({
    required this.bookId,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterIndex,
    this.pendingBookmarkId,
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? pendingBookmarkId;
}

class ReaderPageBootstrapController {
  const ReaderPageBootstrapController();

  ReaderPageBootstrapSeed resolveSeed({
    required String bookId,
    required String chapterId,
    String? chapterUrl,
    String? chapterTitle,
    String? sourceId,
    String? detailUrl,
    int? chapterIndex,
    String? bookmarkId,
  }) {
    final normalizedBookmarkId = bookmarkId?.trim() ?? '';
    return ReaderPageBootstrapSeed(
      bookId: bookId.trim(),
      chapterId: chapterId.trim(),
      chapterUrl: chapterUrl?.trim(),
      chapterTitle: chapterTitle?.trim(),
      sourceId: sourceId?.trim(),
      detailUrl: detailUrl?.trim(),
      chapterIndex: chapterIndex,
      pendingBookmarkId:
          normalizedBookmarkId.isEmpty ? null : normalizedBookmarkId,
    );
  }
}
